import '../../core/utils/paypal_utils.dart';
import '../../core/validators/paypal_validation_rules.dart';

/// A card for direct payment or vaulting.
class PaymentCard {
  PaymentCard({
    required this.number,
    required this.expirationMonth,
    required this.expirationYear,
    required this.securityCode,
    this.cardholderName,
  }) {
    if (!PaypalValidationRules.cardNumberPattern.hasMatch(number)) {
      throw ArgumentError('Card number must be 13-19 digits');
    }
    if (!PaypalUtils.luhnCheck(number)) {
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
    if (!PaypalValidationRules.securityCodePattern.hasMatch(securityCode)) {
      throw ArgumentError('securityCode must be 3 or 4 digits');
    }
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
