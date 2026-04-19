import '../../core/validators/paypal_validation_rules.dart';

/// PayPal SDK environment.
enum PaypalEnvironment { sandbox, live }

/// Configuration needed to initialize the PayPal SDK.
class PaypalConfig {
  PaypalConfig({
    required this.clientId,
    required this.environment,
    this.returnUrl,
  }) {
    if (clientId.isEmpty) {
      throw ArgumentError('clientId must not be empty');
    }
    if (returnUrl != null &&
        !PaypalValidationRules.returnUrlPattern.hasMatch(returnUrl!)) {
      throw ArgumentError(
          'returnUrl must be a valid deep link (e.g. "com.example.app://paypalpay")');
    }
  }

  final String clientId;
  final PaypalEnvironment environment;

  /// Deep link return URL. Required on Android.
  /// Example: "com.example.app://paypalpay"
  final String? returnUrl;
}
