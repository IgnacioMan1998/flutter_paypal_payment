/// Parameters to create an order and process payment without a backend.
class PaymentParams {
  PaymentParams({
    required this.amount,
    required this.currencyCode,
    this.description,
    this.customId,
    this.invoiceId,
    this.softDescriptor,
  }) {
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(amount)) {
      throw ArgumentError('amount must be a valid decimal (e.g. "25.00")');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode)) {
      throw ArgumentError(
          'currencyCode must be a 3-letter ISO 4217 code (e.g. "USD")');
    }
    if (softDescriptor != null && softDescriptor!.length > 22) {
      throw ArgumentError('softDescriptor must be at most 22 characters');
    }
  }

  /// Amount to charge (e.g., "25.00").
  final String amount;

  /// ISO 4217 currency code (e.g., "USD", "EUR", "MXN").
  final String currencyCode;

  /// Description shown to the buyer.
  final String? description;

  /// Your internal reference ID.
  final String? customId;

  /// Your invoice number.
  final String? invoiceId;

  /// Text that appears on the buyer's bank statement (max 22 chars).
  final String? softDescriptor;
}
