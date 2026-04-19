package com.flutter_paypal_payment

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.flutter_paypal_payment.generated.CardMessage
import com.flutter_paypal_payment.generated.CardPaymentRequestMessage
import com.flutter_paypal_payment.generated.CardPaymentResultMessage
import com.flutter_paypal_payment.generated.CardVaultRequestMessage
import com.flutter_paypal_payment.generated.FundingSourceMessage
import com.flutter_paypal_payment.generated.PaymentRequestMessage
import com.flutter_paypal_payment.generated.PaymentResultMessage
import com.flutter_paypal_payment.generated.PaypalConfigMessage
import com.flutter_paypal_payment.generated.PaypalEnvironment
import com.flutter_paypal_payment.generated.PaypalHostApi
import com.flutter_paypal_payment.generated.VaultRequestMessage
import com.flutter_paypal_payment.generated.VaultResultMessage
import com.paypal.android.cardpayments.Card
import com.paypal.android.cardpayments.CardApproveOrderCallback
import com.paypal.android.cardpayments.CardApproveOrderResult
import com.paypal.android.cardpayments.CardAuthChallenge
import com.paypal.android.cardpayments.CardClient
import com.paypal.android.cardpayments.CardFinishApproveOrderResult
import com.paypal.android.cardpayments.CardRequest
import com.paypal.android.cardpayments.CardVaultCallback
import com.paypal.android.cardpayments.CardVaultRequest
import com.paypal.android.cardpayments.CardVaultResult
import com.paypal.android.cardpayments.CardFinishVaultResult
import com.paypal.android.cardpayments.threedsecure.SCA
import com.paypal.android.corepayments.CoreConfig
import com.paypal.android.corepayments.Environment
import com.paypal.android.paypalwebpayments.PayPalPresentAuthChallengeResult
import com.paypal.android.paypalwebpayments.PayPalWebCheckoutClient
import com.paypal.android.paypalwebpayments.PayPalWebCheckoutFinishStartResult
import com.paypal.android.paypalwebpayments.PayPalWebCheckoutFinishVaultResult
import com.paypal.android.paypalwebpayments.PayPalWebCheckoutFundingSource
import com.paypal.android.paypalwebpayments.PayPalWebCheckoutRequest
import com.paypal.android.paypalwebpayments.PayPalWebVaultRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

class FlutterPaypalPaymentPlugin : FlutterPlugin, ActivityAware, PaypalHostApi,
    PluginRegistry.NewIntentListener {

    private var context: Context? = null
    private var activity: Activity? = null
    private var coreConfig: CoreConfig? = null
    private var returnUrl: String? = null
    private var paypalClient: PayPalWebCheckoutClient? = null
    private var cardClient: CardClient? = null

    // Pending callbacks for async flows
    private var pendingPaymentCallback: ((Result<PaymentResultMessage>) -> Unit)? = null
    private var pendingCardCallback: ((Result<CardPaymentResultMessage>) -> Unit)? = null
    private var pendingCardAuthChallenge: CardAuthChallenge? = null
    private var pendingVaultCallback: ((Result<VaultResultMessage>) -> Unit)? = null

    // Track which flow is active for onNewIntent
    private enum class ActiveFlow { NONE, PAYPAL_CHECKOUT, CARD_PAYMENT, CARD_VAULT, PAYPAL_VAULT }
    private var activeFlow = ActiveFlow.NONE

    // --- FlutterPlugin ---

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        PaypalHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = null
        PaypalHostApi.setUp(binding.binaryMessenger, null)
    }

    // --- ActivityAware ---

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addOnNewIntentListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // --- NewIntentListener (handles deep link returns) ---

    override fun onNewIntent(intent: Intent): Boolean {
        return when (activeFlow) {
            ActiveFlow.PAYPAL_CHECKOUT -> handlePayPalCheckoutReturn(intent)
            ActiveFlow.CARD_PAYMENT -> handleCardPaymentReturn(intent)
            ActiveFlow.CARD_VAULT -> handleCardVaultReturn(intent)
            ActiveFlow.PAYPAL_VAULT -> handlePayPalVaultReturn(intent)
            ActiveFlow.NONE -> false
        }
    }

    private fun handlePayPalCheckoutReturn(intent: Intent): Boolean {
        val client = paypalClient ?: return false
        val callback = pendingPaymentCallback ?: return false

        val finishResult = client.finishStart(intent) ?: return false

        when (finishResult) {
            is PayPalWebCheckoutFinishStartResult.Success -> {
                callback(Result.success(PaymentResultMessage(
                    success = true,
                    orderId = finishResult.orderId,
                    payerId = finishResult.payerId,
                )))
            }
            is PayPalWebCheckoutFinishStartResult.Failure -> {
                callback(Result.success(PaymentResultMessage(
                    success = false,
                    errorMessage = finishResult.error.errorDescription,
                    errorCode = finishResult.error.code.toString(),
                )))
            }
            is PayPalWebCheckoutFinishStartResult.Canceled -> {
                callback(Result.success(PaymentResultMessage(
                    success = false,
                    errorMessage = "Payment cancelled by user.",
                    errorCode = "CANCELLED",
                )))
            }
            is PayPalWebCheckoutFinishStartResult.NoResult -> return false
        }
        pendingPaymentCallback = null
        activeFlow = ActiveFlow.NONE
        return true
    }

    private fun handleCardPaymentReturn(intent: Intent): Boolean {
        val client = cardClient ?: return false
        val callback = pendingCardCallback ?: return false

        val finishResult = client.finishApproveOrder(intent) ?: return false

        when (finishResult) {
            is CardFinishApproveOrderResult.Success -> {
                callback(Result.success(CardPaymentResultMessage(
                    success = true,
                    orderId = finishResult.orderId,
                    status = finishResult.status,
                    didAttemptThreeDSecureAuthentication = finishResult.didAttemptThreeDSecureAuthentication,
                )))
            }
            is CardFinishApproveOrderResult.Failure -> {
                callback(Result.success(CardPaymentResultMessage(
                    success = false,
                    errorMessage = finishResult.error.errorDescription,
                    errorCode = finishResult.error.code.toString(),
                )))
            }
            is CardFinishApproveOrderResult.Canceled -> {
                callback(Result.success(CardPaymentResultMessage(
                    success = false,
                    errorMessage = "3DS authentication cancelled by user.",
                    errorCode = "CANCELLED",
                )))
            }
            is CardFinishApproveOrderResult.NoResult -> return false
        }
        pendingCardCallback = null
        pendingCardAuthChallenge = null
        activeFlow = ActiveFlow.NONE
        return true
    }

    private fun handleCardVaultReturn(intent: Intent): Boolean {
        val client = cardClient ?: return false
        val callback = pendingVaultCallback ?: return false

        val finishResult = client.finishVault(intent) ?: return false

        when (finishResult) {
            is CardFinishVaultResult.Success -> {
                callback(Result.success(VaultResultMessage(
                    success = true,
                    setupTokenId = finishResult.setupTokenId,
                    status = finishResult.status,
                )))
            }
            is CardFinishVaultResult.Failure -> {
                callback(Result.success(VaultResultMessage(
                    success = false,
                    errorMessage = finishResult.error.errorDescription,
                    errorCode = finishResult.error.code.toString(),
                )))
            }
            is CardFinishVaultResult.Canceled -> {
                callback(Result.success(VaultResultMessage(
                    success = false,
                    errorMessage = "Vault cancelled by user.",
                    errorCode = "CANCELLED",
                )))
            }
            is CardFinishVaultResult.NoResult -> return false
        }
        pendingVaultCallback = null
        activeFlow = ActiveFlow.NONE
        return true
    }

    private fun handlePayPalVaultReturn(intent: Intent): Boolean {
        val client = paypalClient ?: return false
        val callback = pendingVaultCallback ?: return false

        val finishResult = client.finishVault(intent) ?: return false

        when (finishResult) {
            is PayPalWebCheckoutFinishVaultResult.Success -> {
                callback(Result.success(VaultResultMessage(
                    success = true,
                    setupTokenId = finishResult.approvalSessionId,
                )))
            }
            is PayPalWebCheckoutFinishVaultResult.Failure -> {
                callback(Result.success(VaultResultMessage(
                    success = false,
                    errorMessage = finishResult.error.errorDescription,
                    errorCode = finishResult.error.code.toString(),
                )))
            }
            is PayPalWebCheckoutFinishVaultResult.Canceled -> {
                callback(Result.success(VaultResultMessage(
                    success = false,
                    errorMessage = "Vault cancelled by user.",
                    errorCode = "CANCELLED",
                )))
            }
            is PayPalWebCheckoutFinishVaultResult.NoResult -> return false
        }
        pendingVaultCallback = null
        activeFlow = ActiveFlow.NONE
        return true
    }

    // --- PaypalHostApi: initialize ---

    override fun initialize(
        config: PaypalConfigMessage,
        callback: (Result<Unit>) -> Unit
    ) {
        try {
            val environment = when (config.environment) {
                PaypalEnvironment.SANDBOX -> Environment.SANDBOX
                PaypalEnvironment.LIVE -> Environment.LIVE
            }

            coreConfig = CoreConfig(
                clientId = config.clientId,
                environment = environment,
            )
            returnUrl = config.returnUrl

            val ctx = context
            if (ctx != null && returnUrl != null) {
                paypalClient = PayPalWebCheckoutClient(ctx, coreConfig!!, returnUrl!!)
                cardClient = CardClient(ctx, coreConfig!!)
            }

            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    // --- PaypalHostApi: PayPal checkout ---

    override fun startPayment(
        request: PaymentRequestMessage,
        callback: (Result<PaymentResultMessage>) -> Unit
    ) {
        val currentActivity = activity
        val client = paypalClient

        if (currentActivity == null) {
            callback(Result.success(PaymentResultMessage(
                success = false,
                errorMessage = "No activity available.",
                errorCode = "NO_ACTIVITY",
            )))
            return
        }

        if (client == null) {
            callback(Result.success(PaymentResultMessage(
                success = false,
                errorMessage = "PayPal SDK not initialized. Call initialize() first.",
                errorCode = "NOT_INITIALIZED",
            )))
            return
        }

        try {
            val fundingSource = when (request.fundingSource) {
                FundingSourceMessage.PAY_LATER -> PayPalWebCheckoutFundingSource.PAY_LATER
                else -> PayPalWebCheckoutFundingSource.PAYPAL
            }

            val checkoutRequest = PayPalWebCheckoutRequest(
                orderId = request.orderId,
                fundingSource = fundingSource,
            )

            pendingPaymentCallback = callback
            activeFlow = ActiveFlow.PAYPAL_CHECKOUT

            client.start(currentActivity, checkoutRequest) { startResult ->
                when (startResult) {
                    is PayPalPresentAuthChallengeResult.Success -> {
                        // Browser launched, waiting for deep link return
                    }
                    is PayPalPresentAuthChallengeResult.Failure -> {
                        pendingPaymentCallback = null
                        activeFlow = ActiveFlow.NONE
                        callback(Result.success(PaymentResultMessage(
                            success = false,
                            errorMessage = startResult.error.errorDescription,
                            errorCode = startResult.error.code.toString(),
                        )))
                    }
                }
            }
        } catch (e: Exception) {
            pendingPaymentCallback = null
            activeFlow = ActiveFlow.NONE
            callback(Result.success(PaymentResultMessage(
                success = false,
                errorMessage = e.message ?: "Unknown native error",
                errorCode = "NATIVE_ERROR",
            )))
        }
    }

    // --- PaypalHostApi: Card payment ---

    override fun startCardPayment(
        request: CardPaymentRequestMessage,
        callback: (Result<CardPaymentResultMessage>) -> Unit
    ) {
        val currentActivity = activity
        val client = cardClient

        if (currentActivity == null) {
            callback(Result.success(CardPaymentResultMessage(
                success = false,
                errorMessage = "No activity available.",
                errorCode = "NO_ACTIVITY",
            )))
            return
        }

        if (client == null) {
            callback(Result.success(CardPaymentResultMessage(
                success = false,
                errorMessage = "PayPal SDK not initialized. Call initialize() first.",
                errorCode = "NOT_INITIALIZED",
            )))
            return
        }

        try {
            val card = request.card.toNativeCard()
            val sca = when (request.sca) {
                "SCA_ALWAYS" -> SCA.SCA_ALWAYS
                else -> SCA.SCA_WHEN_REQUIRED
            }

            val cardRequest = CardRequest(
                orderId = request.orderId,
                card = card,
                returnUrl = returnUrl ?: "",
                sca = sca,
            )

            pendingCardCallback = callback
            activeFlow = ActiveFlow.CARD_PAYMENT

            client.approveOrder(cardRequest, object : CardApproveOrderCallback {
                override fun onCardApproveOrderResult(result: CardApproveOrderResult) {
                    when (result) {
                        is CardApproveOrderResult.Success -> {
                            pendingCardCallback = null
                            activeFlow = ActiveFlow.NONE
                            callback(Result.success(CardPaymentResultMessage(
                                success = true,
                                orderId = result.orderId,
                                status = result.status,
                            )))
                        }
                        is CardApproveOrderResult.AuthorizationRequired -> {
                            // 3DS challenge required — present it
                            pendingCardAuthChallenge = result.authChallenge
                            client.presentAuthChallenge(currentActivity, result.authChallenge)
                            // Result comes via onNewIntent -> finishApproveOrder
                        }
                        is CardApproveOrderResult.Failure -> {
                            pendingCardCallback = null
                            activeFlow = ActiveFlow.NONE
                            callback(Result.success(CardPaymentResultMessage(
                                success = false,
                                errorMessage = result.error.errorDescription,
                                errorCode = result.error.code.toString(),
                            )))
                        }
                    }
                }
            })
        } catch (e: Exception) {
            pendingCardCallback = null
            activeFlow = ActiveFlow.NONE
            callback(Result.success(CardPaymentResultMessage(
                success = false,
                errorMessage = e.message ?: "Unknown native error",
                errorCode = "NATIVE_ERROR",
            )))
        }
    }

    // --- PaypalHostApi: Vault PayPal ---

    override fun startVault(
        request: VaultRequestMessage,
        callback: (Result<VaultResultMessage>) -> Unit
    ) {
        val currentActivity = activity
        val client = paypalClient

        if (currentActivity == null) {
            callback(Result.success(VaultResultMessage(
                success = false,
                errorMessage = "No activity available.",
                errorCode = "NO_ACTIVITY",
            )))
            return
        }

        if (client == null) {
            callback(Result.success(VaultResultMessage(
                success = false,
                errorMessage = "PayPal SDK not initialized. Call initialize() first.",
                errorCode = "NOT_INITIALIZED",
            )))
            return
        }

        try {
            val vaultRequest = PayPalWebVaultRequest(
                setupTokenId = request.setupTokenId,
            )

            pendingVaultCallback = callback
            activeFlow = ActiveFlow.PAYPAL_VAULT

            val result = client.vault(currentActivity, vaultRequest)

            when (result) {
                is PayPalPresentAuthChallengeResult.Success -> {
                    // Browser launched, waiting for deep link return
                }
                is PayPalPresentAuthChallengeResult.Failure -> {
                    pendingVaultCallback = null
                    activeFlow = ActiveFlow.NONE
                    callback(Result.success(VaultResultMessage(
                        success = false,
                        errorMessage = result.error.errorDescription,
                        errorCode = result.error.code.toString(),
                    )))
                }
            }
        } catch (e: Exception) {
            pendingVaultCallback = null
            activeFlow = ActiveFlow.NONE
            callback(Result.success(VaultResultMessage(
                success = false,
                errorMessage = e.message ?: "Unknown native error",
                errorCode = "NATIVE_ERROR",
            )))
        }
    }

    // --- PaypalHostApi: Vault Card ---

    override fun startCardVault(
        request: CardVaultRequestMessage,
        callback: (Result<VaultResultMessage>) -> Unit
    ) {
        val currentActivity = activity
        val client = cardClient

        if (currentActivity == null) {
            callback(Result.success(VaultResultMessage(
                success = false,
                errorMessage = "No activity available.",
                errorCode = "NO_ACTIVITY",
            )))
            return
        }

        if (client == null) {
            callback(Result.success(VaultResultMessage(
                success = false,
                errorMessage = "PayPal SDK not initialized. Call initialize() first.",
                errorCode = "NOT_INITIALIZED",
            )))
            return
        }

        try {
            val card = request.card.toNativeCard()
            val cardVaultRequest = CardVaultRequest(
                setupTokenId = request.setupTokenId,
                card = card,
                returnUrl = returnUrl ?: "",
            )

            pendingVaultCallback = callback
            activeFlow = ActiveFlow.CARD_VAULT

            client.vault(cardVaultRequest, object : CardVaultCallback {
                override fun onCardVaultResult(result: CardVaultResult) {
                    when (result) {
                        is CardVaultResult.Success -> {
                            pendingVaultCallback = null
                            activeFlow = ActiveFlow.NONE
                            callback(Result.success(VaultResultMessage(
                                success = true,
                                setupTokenId = result.setupTokenId,
                                status = result.status,
                            )))
                        }
                        is CardVaultResult.AuthorizationRequired -> {
                            // 3DS challenge for vault
                            client.presentAuthChallenge(currentActivity, result.authChallenge)
                            // Result comes via onNewIntent -> finishVault
                        }
                        is CardVaultResult.Failure -> {
                            pendingVaultCallback = null
                            activeFlow = ActiveFlow.NONE
                            callback(Result.success(VaultResultMessage(
                                success = false,
                                errorMessage = result.error.errorDescription,
                                errorCode = result.error.code.toString(),
                            )))
                        }
                    }
                }
            })
        } catch (e: Exception) {
            pendingVaultCallback = null
            activeFlow = ActiveFlow.NONE
            callback(Result.success(VaultResultMessage(
                success = false,
                errorMessage = e.message ?: "Unknown native error",
                errorCode = "NATIVE_ERROR",
            )))
        }
    }

    // --- Helpers ---

    private fun CardMessage.toNativeCard(): Card = Card(
        number = number,
        expirationMonth = expirationMonth,
        expirationYear = expirationYear,
        securityCode = securityCode,
        cardholderName = cardholderName,
    )
}
