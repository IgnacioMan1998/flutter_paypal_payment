import 'package:dartz/dartz.dart';
import '../../core/constants/paypal_error_messages.dart';
import '../../domain/entities/card_payment.dart';
import '../../domain/entities/payment_request.dart';
import '../../domain/entities/payment_result.dart';
import '../../domain/entities/paypal_config.dart';
import '../../domain/entities/vault.dart';
import '../../domain/repositories/paypal_repository.dart';
import '../../generated/paypal_api.g.dart';
import '../mappers/paypal_mappers.dart';

/// Concrete implementation that delegates to Pigeon-generated host API.
class PaypalRepositoryImpl implements PaypalRepository {
  PaypalRepositoryImpl({PaypalHostApi? hostApi})
      : _hostApi = hostApi ?? PaypalHostApi();

  final PaypalHostApi _hostApi;

  @override
  Future<Either<PaymentFailure, Unit>> initialize(PaypalConfig config) async {
    try {
      await _hostApi.initialize(config.toMessage());
      return const Right(unit);
    } catch (e) {
      return Left(PaymentFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<PaymentFailure, PaymentSuccess>> processPayment(
      PaymentRequest request) async {
    try {
      final result = await _hostApi.startPayment(request.toMessage());
      if (result.success && result.orderId != null) {
        return Right(PaymentSuccess(
          orderId: result.orderId!,
          payerId: result.payerId,
        ));
      }
      return Left(PaymentFailure(
        message: result.errorMessage ?? PaypalErrorMessages.unknownError,
        code: result.errorCode,
      ));
    } catch (e) {
      return Left(PaymentFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<CardPaymentFailure, CardPaymentSuccess>> processCardPayment(
      CardPaymentRequest request) async {
    try {
      final result = await _hostApi.startCardPayment(request.toMessage());
      if (result.success && result.orderId != null) {
        return Right(CardPaymentSuccess(
          orderId: result.orderId!,
          status: result.status,
          didAttemptThreeDSecureAuthentication:
              result.didAttemptThreeDSecureAuthentication,
        ));
      }
      return Left(CardPaymentFailure(
        message: result.errorMessage ?? PaypalErrorMessages.unknownError,
        code: result.errorCode,
      ));
    } catch (e) {
      return Left(CardPaymentFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<VaultFailure, VaultSuccess>> vaultPaypal(
      VaultPaypalRequest request) async {
    try {
      final result = await _hostApi.startVault(request.toMessage());
      if (result.success && result.setupTokenId != null) {
        return Right(VaultSuccess(
          setupTokenId: result.setupTokenId!,
          status: result.status,
        ));
      }
      return Left(VaultFailure(
        message: result.errorMessage ?? PaypalErrorMessages.unknownError,
        code: result.errorCode,
      ));
    } catch (e) {
      return Left(VaultFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<VaultFailure, VaultSuccess>> vaultCard(
      VaultCardRequest request) async {
    try {
      final result = await _hostApi.startCardVault(request.toMessage());
      if (result.success && result.setupTokenId != null) {
        return Right(VaultSuccess(
          setupTokenId: result.setupTokenId!,
          status: result.status,
        ));
      }
      return Left(VaultFailure(
        message: result.errorMessage ?? PaypalErrorMessages.unknownError,
        code: result.errorCode,
      ));
    } catch (e) {
      return Left(VaultFailure(message: e.toString()));
    }
  }
}
