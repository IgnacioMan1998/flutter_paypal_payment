import Flutter
import UIKit
import PayPal

public class PaypalCheckoutFlutterPlugin: NSObject, FlutterPlugin, PaypalHostApi {

    private var coreConfig: CoreConfig?
    private var paypalClient: PayPalWebCheckoutClient?
    private var cardClient: CardClient?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let plugin = PaypalCheckoutFlutterPlugin()
        PaypalHostApiSetup.setUp(binaryMessenger: messenger, api: plugin)
    }

    // MARK: - PaypalHostApi: initialize

    func initialize(config: PaypalConfigMessage, completion: @escaping (Result<Void, Error>) -> Void) {
        let environment: CorePayments.Environment
        switch config.environment {
        case .sandbox:
            environment = .sandbox
        case .live:
            environment = .live
        }

        let coreConfig = CoreConfig(clientID: config.clientId, environment: environment)
        self.coreConfig = coreConfig

        self.paypalClient = PayPalWebCheckoutClient(config: coreConfig)
        self.cardClient = CardClient(config: coreConfig)

        completion(.success(()))
    }

    // MARK: - PaypalHostApi: PayPal checkout

    func startPayment(request: PaymentRequestMessage, completion: @escaping (Result<PaymentResultMessage, Error>) -> Void) {
        guard let client = paypalClient else {
            completion(.success(PaymentResultMessage(
                success: false,
                errorMessage: "PayPal SDK not initialized. Call initialize() first.",
                errorCode: "NOT_INITIALIZED"
            )))
            return
        }

        let fundingSource: PayPalWebCheckoutFundingSource
        switch request.fundingSource {
        case .payLater:
            fundingSource = .payLater
        default:
            fundingSource = .paypal
        }

        let checkoutRequest = PayPalWebCheckoutRequest(orderID: request.orderId, fundingSource: fundingSource)

        client.start(request: checkoutRequest) { result, error in
            if let error = error {
                completion(.success(PaymentResultMessage(
                    success: false,
                    errorMessage: error.localizedDescription,
                    errorCode: "NATIVE_ERROR"
                )))
                return
            }

            if let result = result {
                completion(.success(PaymentResultMessage(
                    success: true,
                    orderId: result.orderID,
                    payerId: result.payerID
                )))
            } else {
                completion(.success(PaymentResultMessage(
                    success: false,
                    errorMessage: "Payment cancelled by user.",
                    errorCode: "CANCELLED"
                )))
            }
        }
    }

    // MARK: - PaypalHostApi: Card payment

    func startCardPayment(request: CardPaymentRequestMessage, completion: @escaping (Result<CardPaymentResultMessage, Error>) -> Void) {
        guard let client = cardClient else {
            completion(.success(CardPaymentResultMessage(
                success: false,
                errorMessage: "PayPal SDK not initialized. Call initialize() first.",
                errorCode: "NOT_INITIALIZED"
            )))
            return
        }

        let card = Card(
            number: request.card.number,
            expirationMonth: request.card.expirationMonth,
            expirationYear: request.card.expirationYear,
            securityCode: request.card.securityCode,
            cardholderName: request.card.cardholderName
        )

        let sca: SCA
        switch request.sca {
        case "SCA_ALWAYS":
            sca = .scaAlways
        default:
            sca = .scaWhenRequired
        }

        let cardRequest = CardRequest(orderID: request.orderId, card: card, sca: sca)

        client.approveOrder(request: cardRequest) { result, error in
            if let error = error {
                completion(.success(CardPaymentResultMessage(
                    success: false,
                    errorMessage: error.localizedDescription,
                    errorCode: "NATIVE_ERROR"
                )))
                return
            }

            if let result = result {
                completion(.success(CardPaymentResultMessage(
                    success: true,
                    orderId: result.orderID,
                    status: result.status,
                    didAttemptThreeDSecureAuthentication: result.didAttemptThreeDSecureAuthentication
                )))
            } else {
                completion(.success(CardPaymentResultMessage(
                    success: false,
                    errorMessage: "Card payment cancelled by user.",
                    errorCode: "CANCELLED"
                )))
            }
        }
    }

    // MARK: - PaypalHostApi: Vault PayPal

    func startVault(request: VaultRequestMessage, completion: @escaping (Result<VaultResultMessage, Error>) -> Void) {
        guard let client = paypalClient else {
            completion(.success(VaultResultMessage(
                success: false,
                errorMessage: "PayPal SDK not initialized. Call initialize() first.",
                errorCode: "NOT_INITIALIZED"
            )))
            return
        }

        let vaultRequest = PayPalVaultRequest(setupTokenID: request.setupTokenId)

        client.vault(vaultRequest) { result, error in
            if let error = error {
                completion(.success(VaultResultMessage(
                    success: false,
                    errorMessage: error.localizedDescription,
                    errorCode: "NATIVE_ERROR"
                )))
                return
            }

            if let result = result {
                completion(.success(VaultResultMessage(
                    success: true,
                    setupTokenId: result.tokenID,
                    status: result.approvalSessionID
                )))
            } else {
                completion(.success(VaultResultMessage(
                    success: false,
                    errorMessage: "Vault cancelled by user.",
                    errorCode: "CANCELLED"
                )))
            }
        }
    }

    // MARK: - PaypalHostApi: Vault Card

    func startCardVault(request: CardVaultRequestMessage, completion: @escaping (Result<VaultResultMessage, Error>) -> Void) {
        guard let client = cardClient else {
            completion(.success(VaultResultMessage(
                success: false,
                errorMessage: "PayPal SDK not initialized. Call initialize() first.",
                errorCode: "NOT_INITIALIZED"
            )))
            return
        }

        let card = Card(
            number: request.card.number,
            expirationMonth: request.card.expirationMonth,
            expirationYear: request.card.expirationYear,
            securityCode: request.card.securityCode,
            cardholderName: request.card.cardholderName
        )

        let cardVaultRequest = CardVaultRequest(card: card, setupTokenID: request.setupTokenId)

        client.vault(cardVaultRequest) { result, error in
            if let error = error {
                completion(.success(VaultResultMessage(
                    success: false,
                    errorMessage: error.localizedDescription,
                    errorCode: "NATIVE_ERROR"
                )))
                return
            }

            if let result = result {
                completion(.success(VaultResultMessage(
                    success: true,
                    setupTokenId: result.setupTokenID,
                    status: result.status
                )))
            } else {
                completion(.success(VaultResultMessage(
                    success: false,
                    errorMessage: "Card vault cancelled by user.",
                    errorCode: "CANCELLED"
                )))
            }
        }
    }
}
