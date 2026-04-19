/// PayPal SDK environment.
enum PaypalEnvironment { sandbox, live }

/// Configuration needed to initialize the PayPal SDK.
class PaypalConfig {
  const PaypalConfig({
    required this.clientId,
    required this.environment,
    this.returnUrl,
  });

  final String clientId;
  final PaypalEnvironment environment;

  /// Deep link return URL. Required on Android.
  /// Example: "com.example.app://paypalpay"
  final String? returnUrl;
}
