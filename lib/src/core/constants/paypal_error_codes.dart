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
  static const String authorizeError = 'AUTHORIZE_ERROR';
  static const String captureAuthorizationError = 'CAPTURE_AUTHORIZATION_ERROR';
  static const String voidAuthorizationError = 'VOID_AUTHORIZATION_ERROR';
  static const String updateOrderError = 'UPDATE_ORDER_ERROR';
  static const String createProductError = 'CREATE_PRODUCT_ERROR';
  static const String createPlanError = 'CREATE_PLAN_ERROR';
  static const String getPlanError = 'GET_PLAN_ERROR';
  static const String updatePlanError = 'UPDATE_PLAN_ERROR';
  static const String createSubscriptionError = 'CREATE_SUBSCRIPTION_ERROR';
  static const String getSubscriptionError = 'GET_SUBSCRIPTION_ERROR';
  static const String subscriptionActionError = 'SUBSCRIPTION_ACTION_ERROR';
  static const String listProductsError = 'LIST_PRODUCTS_ERROR';
  static const String getProductError = 'GET_PRODUCT_ERROR';
  static const String updateProductError = 'UPDATE_PRODUCT_ERROR';
  static const String listPlansError = 'LIST_PLANS_ERROR';
  static const String updatePricingError = 'UPDATE_PRICING_ERROR';
  static const String listSubscriptionsError = 'LIST_SUBSCRIPTIONS_ERROR';
  static const String updateSubscriptionError = 'UPDATE_SUBSCRIPTION_ERROR';
  static const String captureSubscriptionError = 'CAPTURE_SUBSCRIPTION_ERROR';
  static const String listTransactionsError = 'LIST_TRANSACTIONS_ERROR';
  static const String validationError = 'VALIDATION_ERROR';
  static const String unknownError = 'UNKNOWN_ERROR';
}
