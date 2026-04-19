import 'package:dartz/dartz.dart';
import '../entities/card_payment.dart';
import '../entities/payment_request.dart';
import '../entities/payment_result.dart';
import '../entities/paypal_config.dart';
import '../entities/vault.dart';

/// Abstract contract for PayPal operations.
abstract class PaypalRepository {
  /// Initialize the SDK. Returns [Unit] on success or [PaymentFailure] on error.
  Future<Either<PaymentFailure, Unit>> initialize(PaypalConfig config);

  /// Start a PayPal checkout flow.
  Future<Either<PaymentFailure, PaymentSuccess>> processPayment(
      PaymentRequest request);

  /// Pay directly with a card (no PayPal login).
  Future<Either<CardPaymentFailure, CardPaymentSuccess>> processCardPayment(
      CardPaymentRequest request);

  /// Vault a PayPal account for future payments.
  Future<Either<VaultFailure, VaultSuccess>> vaultPaypal(
      VaultPaypalRequest request);

  /// Vault a card for future payments.
  Future<Either<VaultFailure, VaultSuccess>> vaultCard(
      VaultCardRequest request);
}
