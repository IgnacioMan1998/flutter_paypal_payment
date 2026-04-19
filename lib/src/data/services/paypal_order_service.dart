import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../../../src/domain/entities/payment_params.dart';
import '../../../src/domain/entities/payment_result.dart';
import '../../../src/domain/entities/paypal_config.dart';

/// Service that creates and captures orders directly via PayPal REST API.
/// Use this when you DON'T have a backend.
///
/// WARNING: This embeds your clientSecret in the app binary.
/// For production apps, prefer using a backend server.
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

  String get _baseUrl => _config.environment == PaypalEnvironment.sandbox
      ? 'https://api-m.sandbox.paypal.com'
      : 'https://api-m.paypal.com';

  /// Get an OAuth2 access token using client credentials.
  Future<Either<PaymentFailure, String>> _getAccessToken() async {
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
        return Right(data['access_token'] as String);
      }

      return Left(PaymentFailure(
        message: 'Failed to get access token: ${response.body}',
        code: 'AUTH_ERROR',
      ));
    } catch (e) {
      return Left(PaymentFailure(message: e.toString(), code: 'AUTH_ERROR'));
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
            message: 'Failed to create order: ${response.body}',
            code: 'CREATE_ORDER_ERROR',
          ));
        } catch (e) {
          return Left(
              PaymentFailure(message: e.toString(), code: 'CREATE_ORDER_ERROR'));
        }
      },
    );
  }

  /// Capture a previously approved order.
  Future<Either<PaymentFailure, Map<String, dynamic>>> captureOrder(
      String orderId) async {
    final tokenResult = await _getAccessToken();

    return tokenResult.fold(
      (failure) => Left(failure),
      (token) async {
        try {
          final response = await _client.post(
            Uri.parse('$_baseUrl/v2/checkout/orders/$orderId/capture'),
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
            message: 'Failed to capture order: ${response.body}',
            code: 'CAPTURE_ERROR',
          ));
        } catch (e) {
          return Left(
              PaymentFailure(message: e.toString(), code: 'CAPTURE_ERROR'));
        }
      },
    );
  }

  void dispose() {
    _client.close();
  }
}
