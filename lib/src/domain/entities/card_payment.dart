import 'payment_card.dart';

/// Request to pay directly with a card.
class CardPaymentRequest {
  const CardPaymentRequest({
    required this.orderId,
    required this.card,
    this.sca,
  });

  /// The order ID created via PayPal Orders API v2.
  final String orderId;

  /// The card to charge.
  final PaymentCard card;

  /// Strong Customer Authentication: "SCA_WHEN_REQUIRED" (default) or "SCA_ALWAYS".
  final String? sca;
}

/// Result of a card payment.
sealed class CardPaymentResult {
  const CardPaymentResult();
}

class CardPaymentSuccess extends CardPaymentResult {
  const CardPaymentSuccess({
    required this.orderId,
    this.status,
    this.didAttemptThreeDSecureAuthentication,
  });

  final String orderId;
  final String? status;
  final bool? didAttemptThreeDSecureAuthentication;
}

class CardPaymentFailure extends CardPaymentResult {
  const CardPaymentFailure({
    required this.message,
    this.code,
  });

  final String message;
  final String? code;
}
