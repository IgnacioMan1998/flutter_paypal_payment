import '../../domain/entities/card_payment.dart';
import '../../domain/entities/payment_card.dart';
import '../../domain/entities/payment_request.dart';
import '../../domain/entities/paypal_config.dart' as domain;
import '../../domain/entities/vault.dart';
import '../../generated/paypal_api.g.dart';

extension PaypalConfigMapper on domain.PaypalConfig {
  PaypalConfigMessage toMessage() => PaypalConfigMessage(
        clientId: clientId,
        environment: environment == domain.PaypalEnvironment.sandbox
            ? PaypalEnvironment.sandbox
            : PaypalEnvironment.live,
        returnUrl: returnUrl,
      );
}

extension PaymentRequestMapper on PaymentRequest {
  PaymentRequestMessage toMessage() => PaymentRequestMessage(
        orderId: orderId,
      );
}

extension PaymentCardMapper on PaymentCard {
  CardMessage toMessage() => CardMessage(
        number: number,
        expirationMonth: expirationMonth,
        expirationYear: expirationYear,
        securityCode: securityCode,
        cardholderName: cardholderName,
      );
}

extension CardPaymentRequestMapper on CardPaymentRequest {
  CardPaymentRequestMessage toMessage() => CardPaymentRequestMessage(
        orderId: orderId,
        card: card.toMessage(),
        sca: sca,
      );
}

extension VaultPaypalRequestMapper on VaultPaypalRequest {
  VaultRequestMessage toMessage() => VaultRequestMessage(
        setupTokenId: setupTokenId,
      );
}

extension VaultCardRequestMapper on VaultCardRequest {
  CardVaultRequestMessage toMessage() => CardVaultRequestMessage(
        setupTokenId: setupTokenId,
        card: card.toMessage(),
      );
}
