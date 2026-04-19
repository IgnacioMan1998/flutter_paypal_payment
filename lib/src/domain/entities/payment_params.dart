/// Parameters to create an order and process payment without a backend.
class PaymentParams {
  const PaymentParams({
    required this.amount,
    required this.currencyCode,
    this.description,
    this.customId,
    this.invoiceId,
    this.softDescriptor,
  });

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
