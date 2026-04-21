/// Validation regex patterns and limits used across entities.
///
/// Single Responsibility: Only validation rules. No business logic.
abstract final class PaypalValidationRules {
  // ── Regex patterns ─────────────────────────────────────
  /// Decimal amount: "25", "25.0", "25.00" (max 2 decimal places).
  static final RegExp amountPattern = RegExp(r'^\d+(\.\d{1,2})?$');

  /// ISO 4217 currency code: 3 uppercase letters.
  static final RegExp currencyCodePattern = RegExp(r'^[A-Z]{3}$');

  /// Card number (PAN): 13-19 digits.
  static final RegExp cardNumberPattern = RegExp(r'^\d{13,19}$');

  /// CVV/CVC: 3 or 4 digits.
  static final RegExp securityCodePattern = RegExp(r'^\d{3,4}$');

  /// Deep link return URL: scheme://host.
  static final RegExp returnUrlPattern =
      RegExp(r'^[a-zA-Z][a-zA-Z0-9._+-]*://[a-zA-Z0-9._-]+$');

  /// Safe PayPal ID (order, capture, setup token): alphanumeric + dash/underscore.
  static final RegExp safeIdPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  // ── Limits ─────────────────────────────────────────────
  /// Maximum length for bank statement descriptor.
  static const int softDescriptorMaxLength = 22;
}
