import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/paypal_api_constants.dart';
import '../../core/constants/paypal_error_codes.dart';
import '../../core/constants/paypal_error_messages.dart';
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

  // Token cache
  String? _cachedToken;
  DateTime? _tokenExpiry;

  String get _baseUrl => _config.environment == PaypalEnvironment.sandbox
      ? PaypalApiConstants.sandboxBaseUrl
      : PaypalApiConstants.liveBaseUrl;

  /// Get an OAuth2 access token using client credentials.
  /// Caches the token and reuses it until near-expiry.
  Future<Either<PaymentFailure, String>> _getAccessToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(
            const Duration(seconds: PaypalApiConstants.tokenExpiryMarginSeconds)))) {
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
            'intent': PaypalApiConstants.intentCapture,
            'purchase_units': [purchaseUnit],
          });

          final response = await _client.post(
            Uri.parse('$_baseUrl${PaypalApiConstants.ordersPath}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body: body,
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
          final response = await _client.post(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.ordersPath}/${Uri.encodeComponent(orderId)}${PaypalApiConstants.captureSubpath}'),
            headers: {
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
          final response = await _client.get(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.ordersPath}/${Uri.encodeComponent(orderId)}'),
            headers: {
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

          final response = await _client.post(
            Uri.parse(
                '$_baseUrl${PaypalApiConstants.capturesPath}/${Uri.encodeComponent(captureId)}${PaypalApiConstants.refundSubpath}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body: body.isNotEmpty ? jsonEncode(body) : null,
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

          final response = await _client.post(
            Uri.parse('$_baseUrl${PaypalApiConstants.setupTokensPath}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body: jsonEncode(requestBody),
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

          final response = await _client.post(
            Uri.parse('$_baseUrl${PaypalApiConstants.paymentTokensPath}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': PaypalApiConstants.contentTypeJson,
            },
            body: body,
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

  void dispose() {
    _cachedToken = null;
    _tokenExpiry = null;
    _client.close();
  }
}
