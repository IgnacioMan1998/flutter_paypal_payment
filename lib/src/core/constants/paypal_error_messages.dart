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
  static const String invalidOrderId = 'Invalid order ID format';
  static const String invalidCaptureId = 'Invalid capture ID format';
  static const String unknownError = 'Unknown error';
}
