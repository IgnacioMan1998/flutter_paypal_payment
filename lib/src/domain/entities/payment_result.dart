/// The result of a PayPal payment attempt.
sealed class PaymentResult {
  const PaymentResult();
}

/// Payment completed successfully.
class PaymentSuccess extends PaymentResult {
  const PaymentSuccess({
    required this.orderId,
    this.payerId,
  });

  final String orderId;
  final String? payerId;
}

/// Payment failed or was cancelled.
class PaymentFailure extends PaymentResult {
  const PaymentFailure({
    required this.message,
    this.code,
  });

  final String message;
  final String? code;
}
