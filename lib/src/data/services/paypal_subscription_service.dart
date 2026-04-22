import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/paypal_api_constants.dart';
import '../../core/constants/paypal_error_codes.dart';
import '../../core/constants/paypal_error_messages.dart';
import '../../core/enums/paypal_enums.dart';
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

  void _log(String method, String url, int? status, String? body) {
    if (!_config.debugMode) return;
    developer.log(
      '[PayPal] $method $url => $status${body != null ? '\n$body' : ''}',
      name: 'paypal_checkout_flutter',
    );
  }

  Future<http.Response> _post(Uri uri, Map<String, String> headers,
      [String? body]) async {
    _log('POST', uri.toString(), null, body);
    final response = await _client
        .post(uri, headers: headers, body: body)
        .timeout(_config.httpTimeout);
    _log('POST', uri.toString(), response.statusCode, response.body);
    return response;
  }

  Future<http.Response> _get(Uri uri, Map<String, String> headers) async {
    _log('GET', uri.toString(), null, null);
    final response = await _client
        .get(uri, headers: headers)
        .timeout(_config.httpTimeout);
    _log('GET', uri.toString(), response.statusCode, response.body);
    return response;
  }

  Future<http.Response> _patch(
      Uri uri, Map<String, String> headers, String body) async {
    _log('PATCH', uri.toString(), null, body);
    final response = await _client
        .patch(uri, headers: headers, body: body)
        .timeout(_config.httpTimeout);
    _log('PATCH', uri.toString(), response.statusCode, response.body);
    return response;
  }

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

      final response = await _post(
        Uri.parse('$_baseUrl${PaypalApiConstants.oauthTokenPath}'),
        {
          'Authorization': 'Basic $credentials',
          'Content-Type': PaypalApiConstants.contentTypeForm,
        },
        PaypalApiConstants.grantTypeCredentials,
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
          final response = await _post(
            Uri.parse('$_baseUrl${PaypalApiConstants.productsPath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            jsonEncode(product),
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

  /// List catalog products.
  ///
  /// Optional query parameters: `page_size` (1-20), `page` (1-100000),
  /// `total_required` (boolean).
  Future<Either<PaymentFailure, Map<String, dynamic>>> listProducts({
    int? pageSize,
    int? page,
    bool? totalRequired,
  }) async {
    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final queryParams = <String, String>{};
          if (pageSize != null) queryParams['page_size'] = '$pageSize';
          if (page != null) queryParams['page'] = '$page';
          if (totalRequired != null) {
            queryParams['total_required'] = '$totalRequired';
          }

          final uri = Uri.parse('$_baseUrl${PaypalApiConstants.productsPath}')
              .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

          final response = await _get(
            uri,
            {
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
            code: PaypalErrorCodes.listProductsError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.listProductsFailed,
            code: PaypalErrorCodes.listProductsError,
          ));
        }
      },
    );
  }

  /// Get details of a catalog product.
  Future<Either<PaymentFailure, Map<String, dynamic>>> getProductDetails(
      String productId) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(productId)) {
      return const Left(PaymentFailure(
        message: 'Invalid product ID format',
        code: PaypalErrorCodes.validationError,
      ));
    }

    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final response = await _get(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.productsPath}/${Uri.encodeComponent(productId)}'),
            {
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
            code: PaypalErrorCodes.getProductError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.getProductFailed,
            code: PaypalErrorCodes.getProductError,
          ));
        }
      },
    );
  }

  /// Update a catalog product with PATCH operations.
  ///
  /// Patchable fields: `description`, `category`, `image_url`, `home_url`.
  Future<Either<PaymentFailure, void>> updateProduct(
    String productId, {
    required List<Map<String, dynamic>> patchOperations,
  }) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(productId)) {
      return const Left(PaymentFailure(
        message: 'Invalid product ID format',
        code: PaypalErrorCodes.validationError,
      ));
    }

    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final response = await _patch(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.productsPath}/${Uri.encodeComponent(productId)}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            jsonEncode(patchOperations),
          );

          if (response.statusCode == 204) {
            return const Right(null);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.updateProductError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.updateProductFailed,
            code: PaypalErrorCodes.updateProductError,
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
          final response = await _post(
            Uri.parse('$_baseUrl${PaypalApiConstants.plansPath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            jsonEncode(plan),
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

  /// List billing plans.
  ///
  /// Optional: `productId` to filter by product, `pageSize` (1-20),
  /// `page` (1-100000), `totalRequired`.
  Future<Either<PaymentFailure, Map<String, dynamic>>> listPlans({
    String? productId,
    int? pageSize,
    int? page,
    bool? totalRequired,
  }) async {
    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final queryParams = <String, String>{};
          if (productId != null) queryParams['product_id'] = productId;
          if (pageSize != null) queryParams['page_size'] = '$pageSize';
          if (page != null) queryParams['page'] = '$page';
          if (totalRequired != null) {
            queryParams['total_required'] = '$totalRequired';
          }

          final uri = Uri.parse('$_baseUrl${PaypalApiConstants.plansPath}')
              .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

          final response = await _get(
            uri,
            {
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
            code: PaypalErrorCodes.listPlansError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.listPlansFailed,
            code: PaypalErrorCodes.listPlansError,
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
          final response = await _get(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.plansPath}/${Uri.encodeComponent(planId)}'),
            {
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
          final response = await _patch(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.plansPath}/${Uri.encodeComponent(planId)}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            jsonEncode(patchOperations),
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
      _planAction(planId, PaypalApiConstants.deactivateSubpath);

  /// Update pricing schemes for a billing plan.
  ///
  /// [pricingSchemes] must contain an array of pricing schemes
  /// with `billing_cycle_sequence` and `pricing_scheme` for each.
  Future<Either<PaymentFailure, void>> updatePlanPricing(
    String planId, {
    required List<Map<String, dynamic>> pricingSchemes,
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
          final response = await _post(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.plansPath}/${Uri.encodeComponent(planId)}${PaypalApiConstants.updatePricingSubpath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            jsonEncode({'pricing_schemes': pricingSchemes}),
          );

          if (response.statusCode == 204) {
            return const Right(null);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.updatePricingError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.updatePricingFailed,
            code: PaypalErrorCodes.updatePricingError,
          ));
        }
      },
    );
  }

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
          final response = await _post(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.plansPath}/${Uri.encodeComponent(planId)}$action'),
            {
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

  /// List subscriptions.
  ///
  /// Optional: `planIds`, `statuses`, `createdAfter`, `createdBefore`,
  /// `pageSize` (1-20), `page`.
  Future<Either<PaymentFailure, Map<String, dynamic>>> listSubscriptions({
    String? planIds,
    String? statuses,
    String? createdAfter,
    String? createdBefore,
    int? pageSize,
    int? page,
  }) async {
    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final queryParams = <String, String>{};
          if (planIds != null) queryParams['plan_ids'] = planIds;
          if (statuses != null) queryParams['statuses'] = statuses;
          if (createdAfter != null) {
            queryParams['created_after'] = createdAfter;
          }
          if (createdBefore != null) {
            queryParams['created_before'] = createdBefore;
          }
          if (pageSize != null) queryParams['page_size'] = '$pageSize';
          if (page != null) queryParams['page'] = '$page';

          final uri =
              Uri.parse('$_baseUrl${PaypalApiConstants.subscriptionsPath}')
                  .replace(
                      queryParameters:
                          queryParams.isNotEmpty ? queryParams : null);

          final response = await _get(
            uri,
            {
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
            code: PaypalErrorCodes.listSubscriptionsError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.listSubscriptionsFailed,
            code: PaypalErrorCodes.listSubscriptionsError,
          ));
        }
      },
    );
  }

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
          final response = await _post(
            Uri.parse('$_baseUrl${PaypalApiConstants.subscriptionsPath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            jsonEncode(subscription),
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
          final response = await _get(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.subscriptionsPath}/${Uri.encodeComponent(subscriptionId)}'),
            {
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

  /// Update a subscription with PATCH operations.
  ///
  /// Patchable fields include: `billing_info.outstanding_balance`,
  /// `custom_id`, `plan.billing_cycles`, `plan.payment_preferences`, etc.
  Future<Either<PaymentFailure, void>> updateSubscription(
    String subscriptionId, {
    required List<Map<String, dynamic>> patchOperations,
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
          final response = await _patch(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.subscriptionsPath}/${Uri.encodeComponent(subscriptionId)}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            jsonEncode(patchOperations),
          );

          if (response.statusCode == 204) {
            return const Right(null);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.updateSubscriptionError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.updateSubscriptionFailed,
            code: PaypalErrorCodes.updateSubscriptionError,
          ));
        }
      },
    );
  }

  /// Capture an authorized payment on a subscription.
  ///
  /// [captureRequest] must contain `note`, `capture_type` ("OUTSTANDING_BALANCE"),
  /// and `amount` (with `currency_code` and `value`).
  Future<Either<PaymentFailure, Map<String, dynamic>>>
      captureSubscriptionPayment(
    String subscriptionId, {
    required Map<String, dynamic> captureRequest,
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
          final response = await _post(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.subscriptionsPath}/${Uri.encodeComponent(subscriptionId)}${PaypalApiConstants.captureSubpath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            jsonEncode(captureRequest),
          );

          if (response.statusCode == 202) {
            // 202 Accepted — may have empty body
            if (response.body.isNotEmpty) {
              return Right(
                  jsonDecode(response.body) as Map<String, dynamic>);
            }
            return const Right(<String, dynamic>{});
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.captureSubscriptionError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.captureSubscriptionFailed,
            code: PaypalErrorCodes.captureSubscriptionError,
          ));
        }
      },
    );
  }

  /// List transactions for a subscription.
  ///
  /// Both [startTime] and [endTime] are required in ISO 8601 format.
  Future<Either<PaymentFailure, Map<String, dynamic>>>
      listSubscriptionTransactions(
    String subscriptionId, {
    required String startTime,
    required String endTime,
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
          final uri = Uri.parse(
                  '$_baseUrl${PaypalApiConstants.subscriptionsPath}/${Uri.encodeComponent(subscriptionId)}${PaypalApiConstants.transactionsSubpath}')
              .replace(queryParameters: {
            'start_time': startTime,
            'end_time': endTime,
          });

          final response = await _get(
            uri,
            {
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
            code: PaypalErrorCodes.listTransactionsError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.listTransactionsFailed,
            code: PaypalErrorCodes.listTransactionsError,
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

          final response = await _post(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.subscriptionsPath}/${Uri.encodeComponent(subscriptionId)}$action'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body.isNotEmpty ? jsonEncode(body) : null,
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
          final response = await _post(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.subscriptionsPath}/${Uri.encodeComponent(subscriptionId)}${PaypalApiConstants.reviseSubpath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            jsonEncode(revisionDetails),
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
