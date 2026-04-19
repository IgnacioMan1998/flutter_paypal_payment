/// Error messages used across the package.
///
/// Separates user-facing text from business logic (Open/Closed: extend
/// messages without modifying logic classes).
abstract final class PaypalErrorMessages {
  static const String notInitialized =
      'PayPal SDK not initialized. Call init() first.';
  static const String authFailed = 'Authentication failed';
  static const String createOrderFailed = 'Failed to create order';
  static const String captureOrderFailed = 'Failed to capture order';
  static const String getOrderDetailsFailed = 'Failed to get order details';
  static const String refundCaptureFailed = 'Failed to refund capture';
  static const String createSetupTokenFailed = 'Failed to create setup token';
  static const String createPaymentTokenFailed =
      'Failed to create payment token';
  static const String authorizeOrderFailed = 'Failed to authorize order';
  static const String captureAuthorizationFailed =
      'Failed to capture authorization';
  static const String voidAuthorizationFailed = 'Failed to void authorization';
  static const String updateOrderFailed = 'Failed to update order';
  static const String createProductFailed = 'Failed to create product';
  static const String createPlanFailed = 'Failed to create plan';
  static const String getPlanFailed = 'Failed to get plan details';
  static const String updatePlanFailed = 'Failed to update plan';
  static const String createSubscriptionFailed = 'Failed to create subscription';
  static const String getSubscriptionFailed =
      'Failed to get subscription details';
  static const String subscriptionActionFailed =
      'Failed to perform subscription action';
  static const String listProductsFailed = 'Failed to list products';
  static const String getProductFailed = 'Failed to get product details';
  static const String updateProductFailed = 'Failed to update product';
  static const String listPlansFailed = 'Failed to list plans';
  static const String updatePricingFailed =
      'Failed to update plan pricing schemes';
  static const String listSubscriptionsFailed = 'Failed to list subscriptions';
  static const String updateSubscriptionFailed = 'Failed to update subscription';
  static const String captureSubscriptionFailed =
      'Failed to capture subscription payment';
  static const String listTransactionsFailed =
      'Failed to list subscription transactions';
  static const String invalidOrderId = 'Invalid order ID format';
  static const String invalidCaptureId = 'Invalid capture ID format';
  static const String invalidAuthorizationId =
      'Invalid authorization ID format';
  static const String unknownError = 'Unknown error';
}
