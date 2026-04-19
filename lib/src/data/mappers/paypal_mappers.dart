import '../../core/enums/paypal_enums.dart';
import '../../domain/entities/card_payment.dart';
import '../../domain/entities/payment_card.dart';
import '../../domain/entities/payment_request.dart';
import '../../domain/entities/paypal_config.dart';
import '../../domain/entities/vault.dart';
import '../../generated/paypal_api.g.dart' as pigeon;

extension PaypalConfigMapper on PaypalConfig {
  pigeon.PaypalConfigMessage toMessage() => pigeon.PaypalConfigMessage(
        clientId: clientId,
        environment: environment == PaypalEnvironment.sandbox
            ? pigeon.PaypalEnvironment.sandbox
            : pigeon.PaypalEnvironment.live,
        returnUrl: returnUrl,
      );
}

extension PaymentRequestMapper on PaymentRequest {
  pigeon.PaymentRequestMessage toMessage() => pigeon.PaymentRequestMessage(
        orderId: orderId,
        fundingSource: fundingSource == PaypalFundingSource.payLater
            ? pigeon.FundingSourceMessage.payLater
            : pigeon.FundingSourceMessage.paypal,
      );
}

extension PaymentCardMapper on PaymentCard {
  pigeon.CardMessage toMessage() => pigeon.CardMessage(
        number: number,
        expirationMonth: expirationMonth,
        expirationYear: expirationYear,
        securityCode: securityCode,
        cardholderName: cardholderName,
      );
}

extension CardPaymentRequestMapper on CardPaymentRequest {
  pigeon.CardPaymentRequestMessage toMessage() => pigeon.CardPaymentRequestMessage(
        orderId: orderId,
        card: card.toMessage(),
        sca: sca,
      );
}

extension VaultPaypalRequestMapper on VaultPaypalRequest {
  pigeon.VaultRequestMessage toMessage() => pigeon.VaultRequestMessage(
        setupTokenId: setupTokenId,
      );
}

extension VaultCardRequestMapper on VaultCardRequest {
  pigeon.CardVaultRequestMessage toMessage() => pigeon.CardVaultRequestMessage(
        setupTokenId: setupTokenId,
        card: card.toMessage(),
      );
}
