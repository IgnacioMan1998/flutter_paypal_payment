/// A card for direct payment or vaulting.
class PaymentCard {
  const PaymentCard({
    required this.number,
    required this.expirationMonth,
    required this.expirationYear,
    required this.securityCode,
    this.cardholderName,
  });

  /// Card number (PAN), e.g. "4111111111111111".
  final String number;

  /// Two-digit expiration month, e.g. "01".
  final String expirationMonth;

  /// Four-digit expiration year, e.g. "2028".
  final String expirationYear;

  /// CVV/CVC security code.
  final String securityCode;

  /// Optional cardholder name.
  final String? cardholderName;
}
