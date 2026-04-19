import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/paypal_api_constants.dart';
import '../../core/constants/paypal_error_codes.dart';
import '../../core/constants/paypal_error_messages.dart';
import '../../core/utils/paypal_utils.dart';
import '../../core/validators/paypal_validation_rules.dart';
import '../../domain/entities/payment_result.dart';
import '../../domain/entities/paypal_config.dart';

/// Service for PayPal Subscriptions REST API.
///
/// Supports Catalog Products, Billing Plans, and Subscriptions.
///
/// ⚠️ **SECURITY WARNING**: This embeds your clientSecret in the app binary.
/// For production apps, use a backend server to proxy PayPal API calls.
class PaypalSubscriptionService {
  PaypalSubscriptionService({
    required PaypalConfig config,
    required String clientSecret,
    http.Client? httpClient,
  })  : _config = config,
        _clientSecret = clientSecret,
        _client = httpClient ?? http.Client();

  final PaypalConfig _config;
  final String _clientSecret;
  final http.Client _client;

  // Token cache
  String? _cachedToken;
  DateTime? _tokenExpiry;

  String get _baseUrl => _config.environment == PaypalEnvironment.sandbox
      ? PaypalApiConstants.sandboxBaseUrl
      : PaypalApiConstants.liveBaseUrl;

  /// Get an OAuth2 access token using client credentials.
  Future<Either<PaymentFailure, String>> _getAccessToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(
            seconds: PaypalApiConstants.tokenExpiryMarginSeconds)))) {
      return Right(_cachedToken!);
    }

    try {
      final credentials =
          base64Encode(utf8.encode('${_config.clientId}:$_clientSecret'));

      final response = await _client.post(
        Uri.parse('$_baseUrl${PaypalApiConstants.oauthTokenPath}'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': PaypalApiConstants.contentTypeForm,
        },
        body: PaypalApiConstants.grantTypeCredentials,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String;
        final expiresIn = data['expires_in'] as int? ??
            PaypalApiConstants.defaultTokenExpirySeconds;

        _cachedToken = token;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        return Right(token);
      }

      return Left(PaymentFailure(
        message: PaypalUtils.safeErrorMessage(response),
        code: PaypalErrorCodes.authError,
      ));
    } catch (e) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.authFailed,
        code: PaypalErrorCodes.authError,
      ));
    }
  }

  // ─── Catalog Products ───

  /// Create a catalog product.
  ///
  /// [product] should contain at minimum `name` and `type` (PHYSICAL, DIGITAL, SERVICE).
  /// Optional fields: `description`, `category`, `image_url`, `home_url`.
  Future<Either<PaymentFailure, Map<String, dynamic>>> createProduct(
      Map<String, dynamic> product) async {
    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final response = await _client.post(
            Uri.parse('$_baseUrl${PaypalApiConstants.productsPath}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body: jsonEncode(product),
          );

          if (response.statusCode == 201) {
            return Right(
                jsonDecode(response.body) as Map<String, dynamic>);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.createProductError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.createProductFailed,
            code: PaypalErrorCodes.createProductError,
          ));
        }
      },
    );
  }

  // ─── Billing Plans ───

  /// Create a billing plan for a product.
  ///
  /// [plan] must contain: `product_id`, `name`, `billing_cycles`.
  /// Each billing cycle needs: `frequency`, `tenure_type`, `sequence`.
  /// Regular cycles also need: `pricing_scheme`.
  Future<Either<PaymentFailure, Map<String, dynamic>>> createPlan(
      Map<String, dynamic> plan) async {
    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final response = await _client.post(
            Uri.parse('$_baseUrl${PaypalApiConstants.plansPath}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body: jsonEncode(plan),
          );

          if (response.statusCode == 201) {
            return Right(
                jsonDecode(response.body) as Map<String, dynamic>);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.createPlanError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.createPlanFailed,
            code: PaypalErrorCodes.createPlanError,
          ));
        }
      },
    );
  }

  /// Get details of a billing plan.
  Future<Either<PaymentFailure, Map<String, dynamic>>> getPlanDetails(
      String planId) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(planId)) {
      return const Left(PaymentFailure(
        message: 'Invalid plan ID format',
        code: PaypalErrorCodes.validationError,
      ));
    }

    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final response = await _client.get(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.plansPath}/${Uri.encodeComponent(planId)}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
          );

          if (response.statusCode == 200) {
            return Right(
                jsonDecode(response.body) as Map<String, dynamic>);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.getPlanError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.getPlanFailed,
            code: PaypalErrorCodes.getPlanError,
          ));
        }
      },
    );
  }

  /// Update a billing plan with PATCH operations.
  Future<Either<PaymentFailure, void>> updatePlan(
    String planId, {
    required List<Map<String, dynamic>> patchOperations,
  }) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(planId)) {
      return const Left(PaymentFailure(
        message: 'Invalid plan ID format',
        code: PaypalErrorCodes.validationError,
      ));
    }

    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final response = await _client.patch(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.plansPath}/${Uri.encodeComponent(planId)}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body: jsonEncode(patchOperations),
          );

          if (response.statusCode == 204) {
            return const Right(null);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.updatePlanError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.updatePlanFailed,
            code: PaypalErrorCodes.updatePlanError,
          ));
        }
      },
    );
  }

  /// Activate a billing plan.
  Future<Either<PaymentFailure, void>> activatePlan(String planId) =>
      _planAction(planId, PaypalApiConstants.activateSubpath);

  /// Deactivate a billing plan.
  Future<Either<PaymentFailure, void>> deactivatePlan(String planId) =>
      _planAction(planId, '/deactivate');

  Future<Either<PaymentFailure, void>> _planAction(
      String planId, String action) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(planId)) {
      return const Left(PaymentFailure(
        message: 'Invalid plan ID format',
        code: PaypalErrorCodes.validationError,
      ));
    }

    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final response = await _client.post(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.plansPath}/${Uri.encodeComponent(planId)}$action'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
          );

          if (response.statusCode == 204) {
            return const Right(null);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.updatePlanError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.updatePlanFailed,
            code: PaypalErrorCodes.updatePlanError,
          ));
        }
      },
    );
  }

  // ─── Subscriptions ───

  /// Create a subscription for a billing plan.
  ///
  /// [subscription] must contain `plan_id`. Optional fields:
  /// `start_time`, `quantity`, `shipping_amount`, `subscriber`,
  /// `application_context` (for return/cancel URLs).
  Future<Either<PaymentFailure, Map<String, dynamic>>> createSubscription(
      Map<String, dynamic> subscription) async {
    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final response = await _client.post(
            Uri.parse('$_baseUrl${PaypalApiConstants.subscriptionsPath}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body: jsonEncode(subscription),
          );

          if (response.statusCode == 201) {
            return Right(
                jsonDecode(response.body) as Map<String, dynamic>);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.createSubscriptionError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.createSubscriptionFailed,
            code: PaypalErrorCodes.createSubscriptionError,
          ));
        }
      },
    );
  }

  /// Get details of a subscription.
  Future<Either<PaymentFailure, Map<String, dynamic>>> getSubscriptionDetails(
      String subscriptionId) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(subscriptionId)) {
      return const Left(PaymentFailure(
        message: 'Invalid subscription ID format',
        code: PaypalErrorCodes.validationError,
      ));
    }

    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final response = await _client.get(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.subscriptionsPath}/${Uri.encodeComponent(subscriptionId)}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
          );

          if (response.statusCode == 200) {
            return Right(
                jsonDecode(response.body) as Map<String, dynamic>);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.getSubscriptionError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.getSubscriptionFailed,
            code: PaypalErrorCodes.getSubscriptionError,
          ));
        }
      },
    );
  }

  /// Activate a subscription.
  Future<Either<PaymentFailure, void>> activateSubscription(
    String subscriptionId, {
    String? reason,
  }) =>
      _subscriptionAction(
          subscriptionId, PaypalApiConstants.activateSubpath, reason);

  /// Suspend a subscription.
  Future<Either<PaymentFailure, void>> suspendSubscription(
    String subscriptionId, {
    required String reason,
  }) =>
      _subscriptionAction(
          subscriptionId, PaypalApiConstants.suspendSubpath, reason);

  /// Cancel a subscription.
  Future<Either<PaymentFailure, void>> cancelSubscription(
    String subscriptionId, {
    required String reason,
  }) =>
      _subscriptionAction(
          subscriptionId, PaypalApiConstants.cancelSubpath, reason);

  Future<Either<PaymentFailure, void>> _subscriptionAction(
    String subscriptionId,
    String action,
    String? reason,
  ) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(subscriptionId)) {
      return const Left(PaymentFailure(
        message: 'Invalid subscription ID format',
        code: PaypalErrorCodes.validationError,
      ));
    }

    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final Map<String, dynamic> body = {};
          if (reason != null) {
            body['reason'] = reason;
          }

          final response = await _client.post(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.subscriptionsPath}/${Uri.encodeComponent(subscriptionId)}$action'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body: body.isNotEmpty ? jsonEncode(body) : null,
          );

          if (response.statusCode == 204) {
            return const Right(null);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.subscriptionActionError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.subscriptionActionFailed,
            code: PaypalErrorCodes.subscriptionActionError,
          ));
        }
      },
    );
  }

  /// Revise a subscription (upgrade/downgrade plan, change quantity).
  Future<Either<PaymentFailure, Map<String, dynamic>>> reviseSubscription(
    String subscriptionId, {
    required Map<String, dynamic> revisionDetails,
  }) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(subscriptionId)) {
      return const Left(PaymentFailure(
        message: 'Invalid subscription ID format',
        code: PaypalErrorCodes.validationError,
      ));
    }

    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final response = await _client.post(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.subscriptionsPath}/${Uri.encodeComponent(subscriptionId)}${PaypalApiConstants.reviseSubpath}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body: jsonEncode(revisionDetails),
          );

          if (response.statusCode == 200) {
            return Right(
                jsonDecode(response.body) as Map<String, dynamic>);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.subscriptionActionError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.subscriptionActionFailed,
            code: PaypalErrorCodes.subscriptionActionError,
          ));
        }
      },
    );
  }

  void dispose() {
    _cachedToken = null;
    _tokenExpiry = null;
    _client.close();
  }
}
