/// A card for direct payment or vaulting.
class PaymentCard {
  PaymentCard({
    required this.number,
    required this.expirationMonth,
    required this.expirationYear,
    required this.securityCode,
    this.cardholderName,
  }) {
    if (!RegExp(r'^\d{13,19}$').hasMatch(number)) {
      throw ArgumentError('Card number must be 13-19 digits');
    }
    if (!_luhnCheck(number)) {
      throw ArgumentError('Invalid card number (Luhn check failed)');
    }
    final month = int.tryParse(expirationMonth);
    if (month == null || month < 1 || month > 12) {
      throw ArgumentError('expirationMonth must be 01-12');
    }
    final year = int.tryParse(expirationYear);
    if (year == null || expirationYear.length != 4) {
      throw ArgumentError('expirationYear must be a 4-digit year');
    }
    if (!RegExp(r'^\d{3,4}$').hasMatch(securityCode)) {
      throw ArgumentError('securityCode must be 3 or 4 digits');
    }
  }

  static bool _luhnCheck(String number) {
    int sum = 0;
    bool alternate = false;
    for (int i = number.length - 1; i >= 0; i--) {
      int digit = int.parse(number[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

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
