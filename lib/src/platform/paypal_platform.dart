import 'package:dartz/dartz.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../paypal_checkout_flutter.dart';

/// Abstract platform interface for PayPal checkout operations.
///
/// Concrete implementations live in:
/// - `paypal_checkout_flutter_android` — Android native SDK (Pigeon)
/// - `paypal_checkout_flutter_ios` — iOS native SDK (Pigeon)
/// - `paypal_checkout_flutter_web` — PayPal JS SDK via browser
///
/// The default implementation (method channel / Pigeon) is used on
/// Android and iOS via [FlutterPaypalPayment].
///
/// ## Federated plugin contract
/// Each platform package registers itself via:
/// ```dart
/// PaypalPlatform.instance = MyPlatformImpl();
/// ```
abstract class PaypalPlatform extends PlatformInterface {
  /// Constructs a platform interface.
  PaypalPlatform() : super(token: _token);

  static final Object _token = Object();

  static PaypalPlatform? _instance;

  /// The current platform instance. Returns `null` until explicitly set by
  /// a platform implementation package.
  static PaypalPlatform? get instance => _instance;

  /// Set the active platform implementation.
  ///
  /// Platform implementation packages call this during their `registerWith`
  /// method:
  /// ```dart
  /// PaypalPlatform.instance = MyPlatformImpl();
  /// ```
  static set instance(PaypalPlatform? newInstance) {
    if (newInstance != null) {
      PlatformInterface.verifyToken(newInstance, _token);
    }
    _instance = newInstance;
  }

  // ── Lifecycle ─────────────────────────────────────────────

  /// Initialize the platform SDK.
  Future<Either<PaymentFailure, Unit>> initialize(PaypalConfig config);

  // ── Checkout ──────────────────────────────────────────────

  /// Launch native / browser PayPal checkout.
  Future<Either<PaymentFailure, PaymentSuccess>> processPayment(
      PaymentRequest request);

  /// Card payment via native SDK / REST.
  Future<Either<PaymentFailure, CardPaymentSuccess>> processCardPayment(
      CardPaymentRequest request);

  // ── Vault ─────────────────────────────────────────────────

  /// Save a PayPal account via setup token.
  Future<Either<PaymentFailure, VaultSuccess>> vaultPaypalAccount(
      VaultPaypalRequest request);

  /// Save a card via setup token.
  Future<Either<PaymentFailure, VaultSuccess>> vaultCard(
      VaultCardRequest request);

  // ── Capabilities ──────────────────────────────────────────

  /// Whether this platform supports native card payments.
  bool get supportsNativeCardPayments;

  /// Whether this platform supports vaulting payment methods.
  bool get supportsVaulting;

  /// The platform name, e.g. `'android'`, `'ios'`, `'web'`.
  String get platformName;
}

/// Thrown when the [PaypalPlatform] has not been set and the default
/// Pigeon-based implementation cannot be used on the current platform.
class PaypalPlatformNotRegisteredError extends Error {
  @override
  String toString() =>
      'PaypalPlatform.instance has not been set. '
      'Ensure the platform implementation package is imported.';
}
