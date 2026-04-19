import 'package:dartz/dartz.dart';

import 'data/repositories/paypal_repository_impl.dart';
import 'data/services/paypal_order_service.dart';
import 'domain/entities/card_payment.dart';
import 'domain/entities/payment_params.dart';
import 'domain/entities/payment_request.dart';
import 'domain/entities/payment_result.dart';
import 'domain/entities/paypal_config.dart';
import 'domain/entities/vault.dart';
import 'domain/repositories/paypal_repository.dart';

/// Main entry point for the PayPal Payment plugin.
class FlutterPaypalPayment {
  FlutterPaypalPayment({PaypalRepository? repository})
      : _repository = repository ?? PaypalRepositoryImpl();

  final PaypalRepository _repository;
  PaypalConfig? _config;

  /// Initialize the PayPal SDK. Must be called once before any payment method.
  Future<Either<PaymentFailure, Unit>> init(PaypalConfig config) {
    _config = config;
    return _repository.initialize(config);
  }

  // ─── PayPal Checkout ───

  /// Pay with PayPal checkout (order created on your backend).
  Future<Either<PaymentFailure, PaymentSuccess>> pay(
          PaymentRequest request) =>
      _repository.processPayment(request);

  /// Pay with PayPal checkout without a backend.
  /// Creates the order, opens checkout, and captures — all in one call.
  Future<Either<PaymentFailure, PaymentSuccess>> payDirect({
    required String clientSecret,
    required PaymentParams params,
    bool autoCapture = true,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: 'PayPal SDK not initialized. Call init() first.',
        code: 'NOT_INITIALIZED',
      ));
    }

    final orderService = PaypalOrderService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      final orderResult = await orderService.createOrder(params);
      if (orderResult.isLeft()) {
        return Left((orderResult as Left<PaymentFailure, String>).value);
      }
      final orderId = (orderResult as Right<PaymentFailure, String>).value;

      final payResult = await _repository.processPayment(
        PaymentRequest(orderId: orderId),
      );
      if (payResult.isLeft()) {
        return Left(
            (payResult as Left<PaymentFailure, PaymentSuccess>).value);
      }
      final success =
          (payResult as Right<PaymentFailure, PaymentSuccess>).value;

      if (!autoCapture) return Right(success);

      final captureResult = await orderService.captureOrder(success.orderId);
      if (captureResult.isLeft()) {
        return Left(
            (captureResult as Left<PaymentFailure, Map<String, dynamic>>)
                .value);
      }

      return Right(success);
    } finally {
      orderService.dispose();
    }
  }

  // ─── Card Payments ───

  /// Pay directly with a card (no PayPal login required).
  /// The order must be created beforehand (backend or [PaypalOrderService]).
  Future<Either<CardPaymentFailure, CardPaymentSuccess>> payWithCard(
          CardPaymentRequest request) =>
      _repository.processCardPayment(request);

  /// Pay directly with a card without a backend.
  /// Creates the order, processes the card, and captures — all in one call.
  Future<Either<CardPaymentFailure, CardPaymentSuccess>> payWithCardDirect({
    required String clientSecret,
    required PaymentParams params,
    required CardPaymentRequest Function(String orderId) buildRequest,
    bool autoCapture = true,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(CardPaymentFailure(
        message: 'PayPal SDK not initialized. Call init() first.',
        code: 'NOT_INITIALIZED',
      ));
    }

    final orderService = PaypalOrderService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      final orderResult = await orderService.createOrder(params);
      if (orderResult.isLeft()) {
        return Left(CardPaymentFailure(
          message: (orderResult as Left<PaymentFailure, String>).value.message,
          code: 'CREATE_ORDER_ERROR',
        ));
      }
      final orderId = (orderResult as Right<PaymentFailure, String>).value;

      final cardResult =
          await _repository.processCardPayment(buildRequest(orderId));
      if (cardResult.isLeft()) {
        return Left(
            (cardResult as Left<CardPaymentFailure, CardPaymentSuccess>).value);
      }
      final success =
          (cardResult as Right<CardPaymentFailure, CardPaymentSuccess>).value;

      if (!autoCapture) return Right(success);

      final captureResult = await orderService.captureOrder(success.orderId);
      if (captureResult.isLeft()) {
        return Left(CardPaymentFailure(
          message: (captureResult as Left<PaymentFailure, Map<String, dynamic>>)
              .value
              .message,
          code: 'CAPTURE_ERROR',
        ));
      }

      return Right(success);
    } finally {
      orderService.dispose();
    }
  }

  // ─── Vault ───

  /// Vault a PayPal account for future payments.
  /// Requires a setup token created via PayPal Setup Tokens API.
  Future<Either<VaultFailure, VaultSuccess>> vaultPaypal(
          VaultPaypalRequest request) =>
      _repository.vaultPaypal(request);

  /// Vault a card for future payments.
  /// Requires a setup token created via PayPal Setup Tokens API.
  Future<Either<VaultFailure, VaultSuccess>> vaultCard(
          VaultCardRequest request) =>
      _repository.vaultCard(request);
}
