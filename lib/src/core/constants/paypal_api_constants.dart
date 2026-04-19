/// PayPal REST API constants.
///
/// Single source of truth for URLs, paths, headers and API values.
abstract final class PaypalApiConstants {
  // ── Base URLs ──────────────────────────────────────────
  static const String sandboxBaseUrl = 'https://api-m.sandbox.paypal.com';
  static const String liveBaseUrl = 'https://api-m.paypal.com';

  // ── API Paths ──────────────────────────────────────────
  static const String oauthTokenPath = '/v1/oauth2/token';
  static const String ordersPath = '/v2/checkout/orders';
  static const String captureSubpath = '/capture';
  static const String refundSubpath = '/refund';
  static const String capturesPath = '/v2/payments/captures';
  static const String setupTokensPath = '/v3/vault/setup-tokens';
  static const String paymentTokensPath = '/v3/vault/payment-tokens';

  // ── Headers ────────────────────────────────────────────
  static const String contentTypeJson = 'application/json';
  static const String contentTypeForm = 'application/x-www-form-urlencoded';
  static const String grantTypeCredentials = 'grant_type=client_credentials';

  // ── Order Intent ───────────────────────────────────────
  static const String intentCapture = 'CAPTURE';
  static const String intentAuthorize = 'AUTHORIZE';

  // ── Authorization Paths ────────────────────────────────
  static const String authorizeSubpath = '/authorize';
  static const String authorizationsPath = '/v2/payments/authorizations';
  static const String voidSubpath = '/void';

  // ── Subscription & Catalog Paths ───────────────────────
  static const String productsPath = '/v1/catalogs/products';
  static const String plansPath = '/v1/billing/plans';
  static const String subscriptionsPath = '/v1/billing/subscriptions';
  static const String activateSubpath = '/activate';
  static const String suspendSubpath = '/suspend';
  static const String cancelSubpath = '/cancel';
  static const String reviseSubpath = '/revise';
  static const String updatePricingSubpath = '/update-pricing-schemes';
  static const String deactivateSubpath = '/deactivate';
  static const String transactionsSubpath = '/transactions';

  // ── Vault ──────────────────────────────────────────────
  static const String tokenTypeSetup = 'SETUP_TOKEN';
  static const String vaultInstructionOnCreate = 'ON_CREATE_PAYMENT_TOKENS';
  static const String defaultUsageType = 'MERCHANT';
  static const String defaultCustomerType = 'CONSUMER';
  static const String defaultUsagePattern = 'IMMEDIATE';

  // ── Token Cache ────────────────────────────────────────
  static const int tokenExpiryMarginSeconds = 60;
  static const int defaultTokenExpirySeconds = 3600;
}
