import Flutter
import PayPal
import UIKit

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

    func initialize(
        config: PaypalConfigMessage, completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let environment: Environment
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

    func startPayment(
        request: PaymentRequestMessage,
        completion: @escaping (Result<PaymentResultMessage, Error>) -> Void
    ) {
        guard let client = paypalClient else {
            completion(
                .success(
                    PaymentResultMessage(
                        success: false,
                        errorMessage: "PayPal SDK not initialized. Call initialize() first.",
                        errorCode: "NOT_INITIALIZED"
                    )))
            return
        }

        let fundingSource: PayPalWebCheckoutFundingSource
        switch request.fundingSource {
        case .payLater:
            fundingSource = .paylater
        default:
            fundingSource = .paypal
        }

        let checkoutRequest = PayPalWebCheckoutRequest(
            orderID: request.orderId, fundingSource: fundingSource)

        client.start(request: checkoutRequest) { result in
            switch result {
            case .success(let checkoutResult):
                completion(
                    .success(
                        PaymentResultMessage(
                            success: true,
                            orderId: checkoutResult.orderID,
                            payerId: checkoutResult.payerID
                        )))
            case .failure(let error):
                completion(
                    .success(
                        PaymentResultMessage(
                            success: false,
                            errorMessage: error.errorDescription ?? error.localizedDescription,
                            errorCode: error.code.map { String($0) } ?? "UNKNOWN"
                        )))
            }
        }
    }

    // MARK: - PaypalHostApi: Card payment

    func startCardPayment(
        request: CardPaymentRequestMessage,
        completion: @escaping (Result<CardPaymentResultMessage, Error>) -> Void
    ) {
        guard let client = cardClient else {
            completion(
                .success(
                    CardPaymentResultMessage(
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

        client.approveOrder(request: cardRequest) { result in
            switch result {
            case .success(let cardResult):
                completion(
                    .success(
                        CardPaymentResultMessage(
                            success: true,
                            orderId: cardResult.orderID,
                            status: cardResult.status,
                            didAttemptThreeDSecureAuthentication: cardResult
                                .didAttemptThreeDSecureAuthentication
                        )))
            case .failure(let error):
                completion(
                    .success(
                        CardPaymentResultMessage(
                            success: false,
                            errorMessage: error.errorDescription ?? error.localizedDescription,
                            errorCode: error.code.map { String($0) } ?? "UNKNOWN"
                        )))
            }
        }
    }

    // MARK: - PaypalHostApi: Vault PayPal

    func startVault(
        request: VaultRequestMessage,
        completion: @escaping (Result<VaultResultMessage, Error>) -> Void
    ) {
        guard let client = paypalClient else {
            completion(
                .success(
                    VaultResultMessage(
                        success: false,
                        errorMessage: "PayPal SDK not initialized. Call initialize() first.",
                        errorCode: "NOT_INITIALIZED"
                    )))
            return
        }

        let vaultRequest = PayPalVaultRequest(setupTokenID: request.setupTokenId)

        client.vault(vaultRequest) { result in
            switch result {
            case .success(let vaultResult):
                completion(
                    .success(
                        VaultResultMessage(
                            success: true,
                            setupTokenId: vaultResult.tokenID,
                            status: vaultResult.approvalSessionID
                        )))
            case .failure(let error):
                completion(
                    .success(
                        VaultResultMessage(
                            success: false,
                            errorMessage: error.errorDescription ?? error.localizedDescription,
                            errorCode: error.code.map { String($0) } ?? "UNKNOWN"
                        )))
            }
        }
    }

    // MARK: - PaypalHostApi: Vault Card

    func startCardVault(
        request: CardVaultRequestMessage,
        completion: @escaping (Result<VaultResultMessage, Error>) -> Void
    ) {
        guard let client = cardClient else {
            completion(
                .success(
                    VaultResultMessage(
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

        client.vault(cardVaultRequest) { result in
            switch result {
            case .success(let cardVaultResult):
                completion(
                    .success(
                        VaultResultMessage(
                            success: true,
                            setupTokenId: cardVaultResult.setupTokenID,
                            status: cardVaultResult.status
                        )))
            case .failure(let error):
                completion(
                    .success(
                        VaultResultMessage(
                            success: false,
                            errorMessage: error.errorDescription ?? error.localizedDescription,
                            errorCode: error.code.map { String($0) } ?? "UNKNOWN"
                        )))
            }
        }
    }
}
