import 'package:dartz/dartz.dart';

import 'core/constants/paypal_api_constants.dart';
import 'core/constants/paypal_error_codes.dart';
import 'core/constants/paypal_error_messages.dart';
import 'data/repositories/paypal_repository_impl.dart';
import 'data/services/paypal_order_service.dart';
import 'data/services/paypal_subscription_service.dart';
import 'domain/entities/card_payment.dart';
import 'domain/entities/payment_card.dart';
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
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
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
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
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
          code: PaypalErrorCodes.createOrderError,
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
          code: PaypalErrorCodes.captureError,
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

  /// Vault a PayPal account without a backend.
  /// Creates the setup token, opens vault flow, and creates payment token — all in one call.
  Future<Either<VaultFailure, VaultSuccess>> vaultPaypalDirect({
    required String clientSecret,
    Map<String, dynamic>? customer,
    String usageType = PaypalApiConstants.defaultUsageType,
    String customerType = PaypalApiConstants.defaultCustomerType,
    String usagePattern = PaypalApiConstants.defaultUsagePattern,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(VaultFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final orderService = PaypalOrderService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      final setupResult = await orderService.createSetupToken(
        paymentSource: {
          'paypal': {
            'usage_type': usageType,
            'customer_type': customerType,
            'usage_pattern': usagePattern,
            'experience_context': {
              'return_url': config.returnUrl,
              'cancel_url': config.returnUrl,
              'vault_instruction': PaypalApiConstants.vaultInstructionOnCreate,
            },
          },
        },
        customer: customer,
      );

      if (setupResult.isLeft()) {
        return Left(VaultFailure(
          message:
              (setupResult as Left<PaymentFailure, Map<String, dynamic>>)
                  .value
                  .message,
          code: PaypalErrorCodes.setupTokenError,
        ));
      }

      final setupData =
          (setupResult as Right<PaymentFailure, Map<String, dynamic>>).value;
      final setupTokenId = setupData['id'] as String;

      final vaultResult =
          await _repository.vaultPaypal(VaultPaypalRequest(setupTokenId: setupTokenId));

      if (vaultResult.isLeft()) return vaultResult;

      final vaultSuccess =
          (vaultResult as Right<VaultFailure, VaultSuccess>).value;

      // Create permanent payment token from the approved setup token
      final paymentTokenResult =
          await orderService.createPaymentToken(vaultSuccess.setupTokenId);

      if (paymentTokenResult.isLeft()) {
        return Left(VaultFailure(
          message:
              (paymentTokenResult as Left<PaymentFailure, Map<String, dynamic>>)
                  .value
                  .message,
          code: PaypalErrorCodes.paymentTokenError,
        ));
      }

      return Right(vaultSuccess);
    } finally {
      orderService.dispose();
    }
  }

  /// Vault a card without a backend.
  /// Creates the setup token, vaults the card, and creates payment token — all in one call.
  Future<Either<VaultFailure, VaultSuccess>> vaultCardDirect({
    required String clientSecret,
    required PaymentCard card,
    Map<String, dynamic>? customer,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(VaultFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final orderService = PaypalOrderService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      final setupResult = await orderService.createSetupToken(
        paymentSource: {
          'card': {
            'experience_context': {
              'return_url': config.returnUrl,
              'cancel_url': config.returnUrl,
              'vault_instruction': PaypalApiConstants.vaultInstructionOnCreate,
            },
          },
        },
        customer: customer,
      );

      if (setupResult.isLeft()) {
        return Left(VaultFailure(
          message:
              (setupResult as Left<PaymentFailure, Map<String, dynamic>>)
                  .value
                  .message,
          code: PaypalErrorCodes.setupTokenError,
        ));
      }

      final setupData =
          (setupResult as Right<PaymentFailure, Map<String, dynamic>>).value;
      final setupTokenId = setupData['id'] as String;

      final vaultResult = await _repository.vaultCard(
        VaultCardRequest(setupTokenId: setupTokenId, card: card),
      );

      if (vaultResult.isLeft()) return vaultResult;

      final vaultSuccess =
          (vaultResult as Right<VaultFailure, VaultSuccess>).value;

      final paymentTokenResult =
          await orderService.createPaymentToken(vaultSuccess.setupTokenId);

      if (paymentTokenResult.isLeft()) {
        return Left(VaultFailure(
          message:
              (paymentTokenResult as Left<PaymentFailure, Map<String, dynamic>>)
                  .value
                  .message,
          code: PaypalErrorCodes.paymentTokenError,
        ));
      }

      return Right(vaultSuccess);
    } finally {
      orderService.dispose();
    }
  }

  // ─── Order Management ───

  /// Get the details of an existing order (requires clientSecret for direct API calls).
  Future<Either<PaymentFailure, Map<String, dynamic>>> getOrderDetails({
    required String clientSecret,
    required String orderId,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final orderService = PaypalOrderService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await orderService.getOrderDetails(orderId);
    } finally {
      orderService.dispose();
    }
  }

  /// Refund a captured payment (requires clientSecret for direct API calls).
  ///
  /// For a full refund, omit [amount] and [currencyCode].
  /// For a partial refund, provide both [amount] and [currencyCode].
  Future<Either<PaymentFailure, Map<String, dynamic>>> refund({
    required String clientSecret,
    required String captureId,
    String? amount,
    String? currencyCode,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final orderService = PaypalOrderService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await orderService.refundCapture(
        captureId,
        amount: amount,
        currencyCode: currencyCode,
      );
    } finally {
      orderService.dispose();
    }
  }

  // ─── Authorization (AUTHORIZE intent) ───

  /// Authorize a previously approved order (requires clientSecret).
  ///
  /// Use this when the order was created with `intent: "AUTHORIZE"`.
  /// Returns the authorization details including the authorization ID.
  Future<Either<PaymentFailure, Map<String, dynamic>>> authorizeOrder({
    required String clientSecret,
    required String orderId,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final orderService = PaypalOrderService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await orderService.authorizeOrder(orderId);
    } finally {
      orderService.dispose();
    }
  }

  /// Capture a previously authorized payment (requires clientSecret).
  ///
  /// Use the authorization ID from [authorizeOrder] result.
  Future<Either<PaymentFailure, Map<String, dynamic>>> captureAuthorization({
    required String clientSecret,
    required String authorizationId,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final orderService = PaypalOrderService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await orderService.captureAuthorization(authorizationId);
    } finally {
      orderService.dispose();
    }
  }

  /// Void a previously authorized payment (requires clientSecret).
  ///
  /// Cancels an authorization so the funds are released back to the buyer.
  Future<Either<PaymentFailure, Map<String, dynamic>>> voidAuthorization({
    required String clientSecret,
    required String authorizationId,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final orderService = PaypalOrderService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await orderService.voidAuthorization(authorizationId);
    } finally {
      orderService.dispose();
    }
  }

  // ─── Shipping / Order Update ───

  /// Update an order with PATCH operations (e.g., shipping info).
  ///
  /// Example to update shipping address:
  /// ```dart
  /// await plugin.updateOrder(
  ///   clientSecret: 'secret',
  ///   orderId: 'ORDER-123',
  ///   patchOperations: [
  ///     {
  ///       'op': 'add',
  ///       'path': "/purchase_units/@reference_id=='default'/shipping/address",
  ///       'value': {
  ///         'address_line_1': '123 Main St',
  ///         'admin_area_2': 'San Jose',
  ///         'admin_area_1': 'CA',
  ///         'postal_code': '95131',
  ///         'country_code': 'US',
  ///       },
  ///     },
  ///   ],
  /// );
  /// ```
  Future<Either<PaymentFailure, void>> updateOrder({
    required String clientSecret,
    required String orderId,
    required List<Map<String, dynamic>> patchOperations,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final orderService = PaypalOrderService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await orderService.updateOrder(
        orderId,
        patchOperations: patchOperations,
      );
    } finally {
      orderService.dispose();
    }
  }

  // ─── Subscriptions ───

  /// Create a catalog product for subscriptions (requires clientSecret).
  Future<Either<PaymentFailure, Map<String, dynamic>>> createProduct({
    required String clientSecret,
    required Map<String, dynamic> product,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final service = PaypalSubscriptionService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await service.createProduct(product);
    } finally {
      service.dispose();
    }
  }

  /// Create a billing plan for a product (requires clientSecret).
  Future<Either<PaymentFailure, Map<String, dynamic>>> createPlan({
    required String clientSecret,
    required Map<String, dynamic> plan,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final service = PaypalSubscriptionService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await service.createPlan(plan);
    } finally {
      service.dispose();
    }
  }

  /// Get details of a billing plan.
  Future<Either<PaymentFailure, Map<String, dynamic>>> getPlanDetails({
    required String clientSecret,
    required String planId,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final service = PaypalSubscriptionService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await service.getPlanDetails(planId);
    } finally {
      service.dispose();
    }
  }

  /// Create a subscription for a billing plan (requires clientSecret).
  Future<Either<PaymentFailure, Map<String, dynamic>>> createSubscription({
    required String clientSecret,
    required Map<String, dynamic> subscription,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final service = PaypalSubscriptionService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await service.createSubscription(subscription);
    } finally {
      service.dispose();
    }
  }

  /// Get details of a subscription.
  Future<Either<PaymentFailure, Map<String, dynamic>>>
      getSubscriptionDetails({
    required String clientSecret,
    required String subscriptionId,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final service = PaypalSubscriptionService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await service.getSubscriptionDetails(subscriptionId);
    } finally {
      service.dispose();
    }
  }

  /// Activate a subscription.
  Future<Either<PaymentFailure, void>> activateSubscription({
    required String clientSecret,
    required String subscriptionId,
    String? reason,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final service = PaypalSubscriptionService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await service.activateSubscription(subscriptionId,
          reason: reason);
    } finally {
      service.dispose();
    }
  }

  /// Suspend a subscription.
  Future<Either<PaymentFailure, void>> suspendSubscription({
    required String clientSecret,
    required String subscriptionId,
    required String reason,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final service = PaypalSubscriptionService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await service.suspendSubscription(subscriptionId,
          reason: reason);
    } finally {
      service.dispose();
    }
  }

  /// Cancel a subscription.
  Future<Either<PaymentFailure, void>> cancelSubscription({
    required String clientSecret,
    required String subscriptionId,
    required String reason,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final service = PaypalSubscriptionService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await service.cancelSubscription(subscriptionId,
          reason: reason);
    } finally {
      service.dispose();
    }
  }

  /// Revise a subscription (upgrade/downgrade plan, change quantity).
  Future<Either<PaymentFailure, Map<String, dynamic>>> reviseSubscription({
    required String clientSecret,
    required String subscriptionId,
    required Map<String, dynamic> revisionDetails,
  }) async {
    final config = _config;
    if (config == null) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.notInitialized,
        code: PaypalErrorCodes.notInitialized,
      ));
    }

    final service = PaypalSubscriptionService(
      config: config,
      clientSecret: clientSecret,
    );

    try {
      return await service.reviseSubscription(
        subscriptionId,
        revisionDetails: revisionDetails,
      );
    } finally {
      service.dispose();
    }
  }
}
