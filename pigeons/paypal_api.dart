import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/generated/paypal_api.g.dart',
  kotlinOut:
      'android/src/main/kotlin/com/flutter_paypal_payment/generated/PaypalApi.g.kt',
  kotlinOptions: KotlinOptions(
    package: 'com.flutter_paypal_payment.generated',
  ),
  swiftOut: 'ios/Classes/generated/PaypalApi.g.swift',
))

/// Environment for the PayPal SDK.
enum PaypalEnvironment {
  sandbox,
  live,
}

/// Configuration to initialize the PayPal SDK.
class PaypalConfigMessage {
  PaypalConfigMessage({
    required this.clientId,
    required this.environment,
    this.returnUrl,
  });

  final String clientId;
  final PaypalEnvironment environment;

  /// Deep link return URL (e.g., "com.example.app://paypalpay").
  final String? returnUrl;
}

/// Funding source for PayPal web checkout.
enum FundingSourceMessage {
  paypal,
  payLater,
}

/// Request to start a PayPal checkout payment.
class PaymentRequestMessage {
  PaymentRequestMessage({
    required this.orderId,
    required this.fundingSource,
  });

  /// The order ID created on your backend via PayPal Orders API.
  final String orderId;

  /// The funding source: PayPal or Pay Later.
  final FundingSourceMessage fundingSource;
}

/// Result returned after a payment attempt.
class PaymentResultMessage {
  PaymentResultMessage({
    required this.success,
    this.orderId,
    this.payerId,
    this.errorMessage,
    this.errorCode,
  });

  final bool success;
  final String? orderId;
  final String? payerId;
  final String? errorMessage;
  final String? errorCode;
}

// ─── Card Payments ───

/// A card to use for payment.
class CardMessage {
  CardMessage({
    required this.number,
    required this.expirationMonth,
    required this.expirationYear,
    required this.securityCode,
    this.cardholderName,
  });

  final String number;
  final String expirationMonth;
  final String expirationYear;
  final String securityCode;
  final String? cardholderName;
}

/// Request to approve an order with a card.
class CardPaymentRequestMessage {
  CardPaymentRequestMessage({
    required this.orderId,
    required this.card,
    this.sca,
  });

  final String orderId;
  final CardMessage card;

  /// Strong Customer Authentication preference: "SCA_WHEN_REQUIRED" or "SCA_ALWAYS".
  final String? sca;
}

/// Result after a card payment attempt.
class CardPaymentResultMessage {
  CardPaymentResultMessage({
    required this.success,
    this.orderId,
    this.status,
    this.didAttemptThreeDSecureAuthentication,
    this.errorMessage,
    this.errorCode,
  });

  final bool success;
  final String? orderId;
  final String? status;
  final bool? didAttemptThreeDSecureAuthentication;
  final String? errorMessage;
  final String? errorCode;
}

// ─── Vault ───

/// Request to vault a PayPal account.
class VaultRequestMessage {
  VaultRequestMessage({
    required this.setupTokenId,
  });

  /// The setup token ID created via PayPal Setup Tokens API.
  final String setupTokenId;
}

/// Result after a vault attempt.
class VaultResultMessage {
  VaultResultMessage({
    required this.success,
    this.setupTokenId,
    this.status,
    this.errorMessage,
    this.errorCode,
  });

  final bool success;
  final String? setupTokenId;
  final String? status;
  final String? errorMessage;
  final String? errorCode;
}

/// Request to vault a card.
class CardVaultRequestMessage {
  CardVaultRequestMessage({
    required this.setupTokenId,
    required this.card,
  });

  final String setupTokenId;
  final CardMessage card;
}

/// Host API: Dart calls into native (Kotlin/Swift).
@HostApi()
abstract class PaypalHostApi {
  /// Initialize the PayPal SDK with the given configuration.
  @async
  void initialize(PaypalConfigMessage config);

  /// Start the PayPal checkout flow for the given order.
  @async
  PaymentResultMessage startPayment(PaymentRequestMessage request);

  /// Approve an order with a card (direct card payment).
  @async
  CardPaymentResultMessage startCardPayment(CardPaymentRequestMessage request);

  /// Vault a PayPal account using a setup token.
  @async
  VaultResultMessage startVault(VaultRequestMessage request);

  /// Vault a card using a setup token.
  @async
  VaultResultMessage startCardVault(CardVaultRequestMessage request);
}
