/// A request to process a PayPal payment.
class PaymentRequest {
  const PaymentRequest({
    required this.orderId,
  });

  /// The order ID created server-side via PayPal Orders API v2.
  final String orderId;
}
