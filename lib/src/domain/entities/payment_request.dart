import '../../core/enums/paypal_enums.dart';

/// A request to process a PayPal payment.
class PaymentRequest {
  const PaymentRequest({
    required this.orderId,
    this.fundingSource = PaypalFundingSource.paypal,
  });

  /// The order ID created server-side via PayPal Orders API v2.
  final String orderId;

  /// The funding source for the checkout. Defaults to [PaypalFundingSource.paypal].
  final PaypalFundingSource fundingSource;
}
