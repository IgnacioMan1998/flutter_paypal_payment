import '../../core/enums/paypal_enums.dart';
import '../../core/validators/paypal_validation_rules.dart';

/// Configuration needed to initialize the PayPal SDK.
class PaypalConfig {
  PaypalConfig({
    required this.clientId,
    required this.environment,
    this.returnUrl,
    this.httpTimeout = const Duration(seconds: 30),
    this.debugMode = false,
  }) {
    if (clientId.isEmpty) {
      throw ArgumentError('clientId must not be empty');
    }
    if (returnUrl != null &&
        !PaypalValidationRules.returnUrlPattern.hasMatch(returnUrl!)) {
      throw ArgumentError(
          'returnUrl must be a valid deep link (e.g. "com.example.app://paypalpay")');
    }
    if (httpTimeout.inSeconds < 1) {
      throw ArgumentError('httpTimeout must be at least 1 second');
    }
  }

  final String clientId;
  final PaypalEnvironment environment;

  /// Deep link return URL. Required on Android.
  /// Example: "com.example.app://paypalpay"
  final String? returnUrl;

  /// Timeout for all HTTP requests to the PayPal REST API.
  /// Defaults to 30 seconds.
  final Duration httpTimeout;

  /// Enable verbose debug logging of all PayPal API requests and responses.
  /// **Disable in production** — responses may contain sensitive token data.
  final bool debugMode;
}
