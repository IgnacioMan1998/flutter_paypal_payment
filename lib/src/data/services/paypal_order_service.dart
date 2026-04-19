import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../../../src/domain/entities/payment_params.dart';
import '../../../src/domain/entities/payment_result.dart';
import '../../../src/domain/entities/paypal_config.dart';

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

  // Token cache
  String? _cachedToken;
  DateTime? _tokenExpiry;

  String get _baseUrl => _config.environment == PaypalEnvironment.sandbox
      ? 'https://api-m.sandbox.paypal.com'
      : 'https://api-m.paypal.com';

  /// Extract a safe error message from a PayPal API response.
  /// Never exposes the raw response body.
  static String _safeErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final name = data['name'] ?? '';
      final message = data['message'] ?? '';
      final debugId = data['debug_id'] ?? '';
      return 'PayPal error: $name – $message (debug_id: $debugId)';
    } catch (_) {
      return 'PayPal API error (HTTP ${response.statusCode})';
    }
  }

  /// Validates that an ID contains only safe characters (alphanumeric, dash, underscore).
  static bool _isValidId(String id) {
    return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id);
  }

  /// Get an OAuth2 access token using client credentials.
  /// Caches the token and reuses it until near-expiry.
  Future<Either<PaymentFailure, String>> _getAccessToken() async {
    // Return cached token if still valid (with 60s safety margin)
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(seconds: 60)))) {
      return Right(_cachedToken!);
    }

    try {
      final credentials =
          base64Encode(utf8.encode('${_config.clientId}:$_clientSecret'));

      final response = await _client.post(
        Uri.parse('$_baseUrl/v1/oauth2/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['access_token'] as String;
        final expiresIn = data['expires_in'] as int? ?? 3600;

        _cachedToken = token;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        return Right(token);
      }

      return Left(PaymentFailure(
        message: _safeErrorMessage(response),
        code: 'AUTH_ERROR',
      ));
    } catch (e) {
      return Left(PaymentFailure(
        message: 'Authentication failed',
        code: 'AUTH_ERROR',
      ));
    }
  }

  /// Create an order on PayPal and return the order ID.
  Future<Either<PaymentFailure, String>> createOrder(
      PaymentParams params) async {
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
            'intent': 'CAPTURE',
            'purchase_units': [purchaseUnit],
          });

          final response = await _client.post(
            Uri.parse('$_baseUrl/v2/checkout/orders'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: body,
          );

          if (response.statusCode == 201) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data['id'] as String);
          }

          return Left(PaymentFailure(
            message: _safeErrorMessage(response),
            code: 'CREATE_ORDER_ERROR',
          ));
        } catch (e) {
          return Left(
              PaymentFailure(message: 'Failed to create order', code: 'CREATE_ORDER_ERROR'));
        }
      },
    );
  }

  /// Capture a previously approved order.
  Future<Either<PaymentFailure, Map<String, dynamic>>> captureOrder(
      String orderId) async {
    if (!_isValidId(orderId)) {
      return const Left(PaymentFailure(
        message: 'Invalid order ID format',
        code: 'VALIDATION_ERROR',
      ));
    }

    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final response = await _client.post(
            Uri.parse('$_baseUrl/v2/checkout/orders/${Uri.encodeComponent(orderId)}/capture'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );

          if (response.statusCode == 201) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data);
          }

          return Left(PaymentFailure(
            message: _safeErrorMessage(response),
            code: 'CAPTURE_ERROR',
          ));
        } catch (e) {
          return Left(
              PaymentFailure(message: 'Failed to capture order', code: 'CAPTURE_ERROR'));
        }
      },
    );
  }

  /// Get the details of an existing order.
  Future<Either<PaymentFailure, Map<String, dynamic>>> getOrderDetails(
      String orderId) async {
    if (!_isValidId(orderId)) {
      return const Left(PaymentFailure(
        message: 'Invalid order ID format',
        code: 'VALIDATION_ERROR',
      ));
    }

    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final response = await _client.get(
            Uri.parse('$_baseUrl/v2/checkout/orders/${Uri.encodeComponent(orderId)}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data);
          }

          return Left(PaymentFailure(
            message: _safeErrorMessage(response),
            code: 'GET_ORDER_ERROR',
          ));
        } catch (e) {
          return Left(
              PaymentFailure(message: 'Failed to get order details', code: 'GET_ORDER_ERROR'));
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
    if (!_isValidId(captureId)) {
      return const Left(PaymentFailure(
        message: 'Invalid capture ID format',
        code: 'VALIDATION_ERROR',
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

          final response = await _client.post(
            Uri.parse(
                '$_baseUrl/v2/payments/captures/${Uri.encodeComponent(captureId)}/refund'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: body.isNotEmpty ? jsonEncode(body) : null,
          );

          if (response.statusCode == 201) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data);
          }

          return Left(PaymentFailure(
            message: _safeErrorMessage(response),
            code: 'REFUND_ERROR',
          ));
        } catch (e) {
          return Left(
              PaymentFailure(message: 'Failed to refund capture', code: 'REFUND_ERROR'));
        }
      },
    );
  }

  /// Create a setup token for vaulting a payment method without a backend.
  ///
  /// [paymentSource] – e.g. `{'paypal': {'usage_type': 'MERCHANT', ...}}`
  /// or `{'card': {'number': '...', 'expiry': '...', ...}}`.
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

          final response = await _client.post(
            Uri.parse('$_baseUrl/v3/vault/setup-tokens'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data);
          }

          return Left(PaymentFailure(
            message: _safeErrorMessage(response),
            code: 'SETUP_TOKEN_ERROR',
          ));
        } catch (e) {
          return Left(PaymentFailure(
              message: 'Failed to create setup token', code: 'SETUP_TOKEN_ERROR'));
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
                'type': 'SETUP_TOKEN',
              },
            },
          });

          final response = await _client.post(
            Uri.parse('$_baseUrl/v3/vault/payment-tokens'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: body,
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return Right(data);
          }

          return Left(PaymentFailure(
            message: _safeErrorMessage(response),
            code: 'PAYMENT_TOKEN_ERROR',
          ));
        } catch (e) {
          return Left(PaymentFailure(
              message: 'Failed to create payment token', code: 'PAYMENT_TOKEN_ERROR'));
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
