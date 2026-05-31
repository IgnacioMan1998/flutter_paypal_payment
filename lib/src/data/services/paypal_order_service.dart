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
import '../../domain/entities/payment_params.dart';
import '../../domain/entities/payment_result.dart';
import '../../domain/entities/paypal_config.dart';

/// Service that creates and captures orders directly via PayPal REST API.
/// Use this when you DON'T have a backend.
///
/// ⚠️ **SECURITY WARNING**: This embeds your clientSecret in the app binary.
/// Anyone can decompile the app and extract it. The client secret grants full
/// API access (create orders, capture payments, issue refunds).
///
/// **For production apps, use a backend server** to proxy PayPal API calls.
/// Only use this for prototyping, testing, or apps with trusted users.
class PaypalOrderService {
  PaypalOrderService({
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

  Future<http.Response> _get(
      Uri uri, Map<String, String> headers) async {
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
  /// Caches the token and reuses it until near-expiry.
  Future<Either<PaymentFailure, String>> _getAccessToken() async {
    if (_cachedToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(seconds: PaypalApiConstants.tokenExpiryMarginSeconds)))) {
      return Right(_cachedToken!);
    }

    try {
      final credentials = base64Encode(utf8.encode('${_config.clientId}:$_clientSecret'));

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
        final expiresIn = data['expires_in'] as int? ?? PaypalApiConstants.defaultTokenExpirySeconds;

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

  /// Create an order on PayPal and return the order ID.
  Future<Either<PaymentFailure, String>> createOrder(PaymentParams params) async {
    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final purchaseUnit = <String, dynamic>{
            'amount': {
              'currency_code': params.currencyCode,
              'value': params.amount,
            },
          };

          if (params.description != null) {
            purchaseUnit['description'] = params.description;
          }
          if (params.customId != null) {
            purchaseUnit['custom_id'] = params.customId;
          }
          if (params.invoiceId != null) {
            purchaseUnit['invoice_id'] = params.invoiceId;
          }
          if (params.softDescriptor != null) {
            purchaseUnit['soft_descriptor'] = params.softDescriptor;
          }

          final body = jsonEncode({
            'intent': params.intent,
            'purchase_units': [purchaseUnit],
          });

          final response = await _post(
            Uri.parse('$_baseUrl${PaypalApiConstants.ordersPath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body,
          );

          if (response.statusCode == 201) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data['id'] as String);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.createOrderError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.createOrderFailed,
            code: PaypalErrorCodes.createOrderError,
          ));
        }
      },
    );
  }

  /// Update an order with PATCH operations (e.g., shipping info, amount).
  ///
  /// [orderId] – the order to update.
  /// [patchOperations] – a list of JSON Patch operations, e.g.:
  /// ```dart
  /// [
  ///   {
  ///     'op': 'add',
  ///     'path': '/purchase_units/@reference_id==\'default\'/shipping/address',
  ///     'value': {
  ///       'address_line_1': '123 Main St',
  ///       'admin_area_2': 'San Jose',
  ///       'admin_area_1': 'CA',
  ///       'postal_code': '95131',
  ///       'country_code': 'US',
  ///     },
  ///   },
  /// ]
  /// ```
  Future<Either<PaymentFailure, void>> updateOrder(
    String orderId, {
    required List<Map<String, dynamic>> patchOperations,
  }) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(orderId)) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.invalidOrderId,
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
                '$_baseUrl${PaypalApiConstants.ordersPath}/${Uri.encodeComponent(orderId)}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            jsonEncode(patchOperations),
          );

          // PayPal returns 204 No Content on successful PATCH
          if (response.statusCode == 204) {
            return const Right(null);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.updateOrderError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.updateOrderFailed,
            code: PaypalErrorCodes.updateOrderError,
          ));
        }
      },
    );
  }

  /// Capture a previously approved order.
  Future<Either<PaymentFailure, Map<String, dynamic>>> captureOrder(
      String orderId) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(orderId)) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.invalidOrderId,
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
                '$_baseUrl${PaypalApiConstants.ordersPath}/${Uri.encodeComponent(orderId)}${PaypalApiConstants.captureSubpath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
          );

          if (response.statusCode == 201) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.captureError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.captureOrderFailed,
            code: PaypalErrorCodes.captureError,
          ));
        }
      },
    );
  }

  /// Get the details of an existing order.
  Future<Either<PaymentFailure, Map<String, dynamic>>> getOrderDetails(
      String orderId) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(orderId)) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.invalidOrderId,
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
                '$_baseUrl${PaypalApiConstants.ordersPath}/${Uri.encodeComponent(orderId)}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.getOrderError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.getOrderDetailsFailed,
            code: PaypalErrorCodes.getOrderError,
          ));
        }
      },
    );
  }

  /// Refund a captured payment.
  ///
  /// [captureId] – the capture ID from the order capture response.
  /// [amount] and [currencyCode] are optional; omit them for a full refund.
  Future<Either<PaymentFailure, Map<String, dynamic>>> refundCapture(
    String captureId, {
    String? amount,
    String? currencyCode,
  }) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(captureId)) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.invalidCaptureId,
        code: PaypalErrorCodes.validationError,
      ));
    }

    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final Map<String, dynamic> body = {};
          if (amount != null && currencyCode != null) {
            body['amount'] = {
              'value': amount,
              'currency_code': currencyCode,
            };
          }

          final response = await _post(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.capturesPath}/${Uri.encodeComponent(captureId)}${PaypalApiConstants.refundSubpath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body.isNotEmpty ? jsonEncode(body) : null,
          );

          if (response.statusCode == 201) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.refundError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.refundCaptureFailed,
            code: PaypalErrorCodes.refundError,
          ));
        }
      },
    );
  }

  /// Create a setup token for vaulting a payment method without a backend.
  Future<Either<PaymentFailure, Map<String, dynamic>>> createSetupToken({
    required Map<String, dynamic> paymentSource,
    Map<String, dynamic>? customer,
  }) async {
    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final Map<String, dynamic> requestBody = {
            'payment_source': paymentSource,
          };
          if (customer != null) {
            requestBody['customer'] = customer;
          }

          final response = await _post(
            Uri.parse('$_baseUrl${PaypalApiConstants.setupTokensPath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            jsonEncode(requestBody),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.setupTokenError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.createSetupTokenFailed,
            code: PaypalErrorCodes.setupTokenError,
          ));
        }
      },
    );
  }

  /// Create a payment token from an approved setup token.
  Future<Either<PaymentFailure, Map<String, dynamic>>> createPaymentToken(
      String setupTokenId) async {
    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final body = jsonEncode({
            'payment_source': {
              'token': {
                'id': setupTokenId,
                'type': PaypalApiConstants.tokenTypeSetup,
              },
            },
          });

          final response = await _post(
            Uri.parse('$_baseUrl${PaypalApiConstants.paymentTokensPath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body,
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.paymentTokenError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.createPaymentTokenFailed,
            code: PaypalErrorCodes.paymentTokenError,
          ));
        }
      },
    );
  }

  /// Authorize a previously approved order (for AUTHORIZE intent).
  Future<Either<PaymentFailure, Map<String, dynamic>>> authorizeOrder(
      String orderId) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(orderId)) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.invalidOrderId,
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
                '$_baseUrl${PaypalApiConstants.ordersPath}/${Uri.encodeComponent(orderId)}${PaypalApiConstants.authorizeSubpath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
          );

          if (response.statusCode == 201) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.authorizeError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.authorizeOrderFailed,
            code: PaypalErrorCodes.authorizeError,
          ));
        }
      },
    );
  }

  /// Capture a previously authorized payment.
  Future<Either<PaymentFailure, Map<String, dynamic>>> captureAuthorization(
      String authorizationId) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(authorizationId)) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.invalidAuthorizationId,
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
                '$_baseUrl${PaypalApiConstants.authorizationsPath}/${Uri.encodeComponent(authorizationId)}${PaypalApiConstants.captureSubpath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
          );

          if (response.statusCode == 201) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.captureAuthorizationError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.captureAuthorizationFailed,
            code: PaypalErrorCodes.captureAuthorizationError,
          ));
        }
      },
    );
  }

  /// Void a previously authorized payment (cancel without capturing).
  Future<Either<PaymentFailure, Map<String, dynamic>>> voidAuthorization(
      String authorizationId) async {
    if (!PaypalValidationRules.safeIdPattern.hasMatch(authorizationId)) {
      return const Left(PaymentFailure(
        message: PaypalErrorMessages.invalidAuthorizationId,
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
                '$_baseUrl${PaypalApiConstants.authorizationsPath}/${Uri.encodeComponent(authorizationId)}${PaypalApiConstants.voidSubpath}'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
          );

          // PayPal returns 204 No Content on successful void
          if (response.statusCode == 204) {
            return const Right(<String, dynamic>{'status': 'VOIDED'});
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: PaypalErrorCodes.voidAuthorizationError,
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: PaypalErrorMessages.voidAuthorizationFailed,
            code: PaypalErrorCodes.voidAuthorizationError,
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

  // ─── Pay Later ───────────────────────────────────────────

  /// Fetch Pay Later financing eligibility for the given [amount].
  ///
  /// Calls `POST /v1/credit/assessed-financing` and returns the raw response.
  /// An empty map is returned when no offers are available (204 No Content).
  Future<Either<PaymentFailure, Map<String, dynamic>>> getPayLaterOffer({
    required String amount,
    String currencyCode = 'USD',
    String? buyerCountryCode,
  }) async {
    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final body = jsonEncode({
            'financing_country_code': buyerCountryCode ?? 'US',
            'transaction_amount': {
              'value': amount,
              'currency_code': currencyCode,
            },
          });

          final response = await _post(
            Uri.parse('$_baseUrl/v1/credit/assessed-financing'),
            {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body,
          );

          if (response.statusCode == 204) return const Right({});

          if (response.statusCode == 200 || response.statusCode == 201) {
            return Right(jsonDecode(response.body) as Map<String, dynamic>);
          }

          return Left(PaymentFailure(
            message: PaypalUtils.safeErrorMessage(response),
            code: 'PAY_LATER_ERROR',
          ));
        } catch (e) {
          return const Left(PaymentFailure(
            message: 'Failed to fetch Pay Later offer',
            code: 'PAY_LATER_ERROR',
          ));
        }
      },
    );
  }
}
