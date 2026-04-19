import '../../core/constants/paypal_api_constants.dart';
import '../../core/validators/paypal_validation_rules.dart';

/// Parameters to create an order and process payment without a backend.
class PaymentParams {
  PaymentParams({
    required this.amount,
    required this.currencyCode,
    this.intent = PaypalApiConstants.intentCapture,
    this.description,
    this.customId,
    this.invoiceId,
    this.softDescriptor,
  }) {
    if (!PaypalValidationRules.amountPattern.hasMatch(amount)) {
      throw ArgumentError('amount must be a valid decimal (e.g. "25.00")');
    }
    if (!PaypalValidationRules.currencyCodePattern.hasMatch(currencyCode)) {
      throw ArgumentError(
          'currencyCode must be a 3-letter ISO 4217 code (e.g. "USD")');
    }
    if (softDescriptor != null &&
        softDescriptor!.length > PaypalValidationRules.softDescriptorMaxLength) {
      throw ArgumentError(
          'softDescriptor must be at most ${PaypalValidationRules.softDescriptorMaxLength} characters');
    }
    if (intent != PaypalApiConstants.intentCapture &&
        intent != PaypalApiConstants.intentAuthorize) {
      throw ArgumentError('intent must be "CAPTURE" or "AUTHORIZE"');
    }
  }

  /// Amount to charge (e.g., "25.00").
  final String amount;

  /// ISO 4217 currency code (e.g., "USD", "EUR", "MXN").
  final String currencyCode;

  /// Order intent: "CAPTURE" (default) or "AUTHORIZE".
  final String intent;

  /// Description shown to the buyer.
  final String? description;

  /// Your internal reference ID.
  final String? customId;

  /// Your invoice number.
  final String? invoiceId;

  /// Text that appears on the buyer's bank statement (max 22 chars).
  final String? softDescriptor;
}
