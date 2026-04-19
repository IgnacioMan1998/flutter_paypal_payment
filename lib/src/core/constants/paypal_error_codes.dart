/// Error codes used across the package.
///
/// Single Responsibility: Only defines error code identifiers.
abstract final class PaypalErrorCodes {
  static const String notInitialized = 'NOT_INITIALIZED';
  static const String authError = 'AUTH_ERROR';
  static const String createOrderError = 'CREATE_ORDER_ERROR';
  static const String captureError = 'CAPTURE_ERROR';
  static const String getOrderError = 'GET_ORDER_ERROR';
  static const String refundError = 'REFUND_ERROR';
  static const String setupTokenError = 'SETUP_TOKEN_ERROR';
  static const String paymentTokenError = 'PAYMENT_TOKEN_ERROR';
  static const String validationError = 'VALIDATION_ERROR';
  static const String unknownError = 'UNKNOWN_ERROR';
}
