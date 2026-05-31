import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../core/enums/paypal_enums.dart';
import '../domain/entities/payment_result.dart';
import '../domain/entities/paypal_config.dart';
import '../web/paypal_js_sdk_loader.dart';

/// Web-platform checkout flow using the PayPal REST API.
///
/// On web, PayPal checkout cannot use the native mobile SDK. Instead this
/// implementation:
/// 1. Creates an order via REST API
/// 2. Returns the approval URL for browser redirect
/// 3. After redirect-back, captures the order
///
/// ## Typical usage (Flutter Web)
/// ```dart
/// final service = PaypalWebCheckout(config: cfg, clientSecret: 'SECRET');
///
/// // Step 1 — create order and get approval URL
/// final order = await service.createOrder(
///   amount: '49.99',
///   currencyCode: 'USD',
///   returnUrl: 'https://yourapp.com/paypal/return',
///   cancelUrl: 'https://yourapp.com/paypal/cancel',
/// );
/// order.fold(
///   (err)  => showError(err.message),
///   (data) => launchUrl(Uri.parse(data['approveUrl']!)),
/// );
///
/// // Step 2 — after redirect back, capture
/// final capture = await service.captureOrder(orderId: 'ORDER_ID');
/// ```
class PaypalWebCheckout {
  PaypalWebCheckout({
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

  String? _cachedToken;
  DateTime? _tokenExpiry;

  // ── Auth ──────────────────────────────────────────────────

  Future<Either<PaymentFailure, String>> _getAccessToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return Right(_cachedToken!);
    }
    final credentials =
        base64Encode(utf8.encode('${_config.clientId}:$_clientSecret'));
    try {
      final resp = await _client.post(
        Uri.parse('$_baseUrl/v1/oauth2/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      );
      if (resp.statusCode != 200) {
        return Left(PaymentFailure(
          code: 'AUTH_ERROR',
          message: 'Web checkout auth failed: ${resp.statusCode}',
        ));
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      _cachedToken = data['access_token'] as String;
      final expiresIn = (data['expires_in'] as int?) ?? 32400;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
      return Right(_cachedToken!);
    } catch (e) {
      return Left(PaymentFailure(
        code: 'AUTH_ERROR',
        message: 'Web checkout auth error: $e',
      ));
    }
  }

  // ── Order creation ────────────────────────────────────────

  /// Create a PayPal order and return the approval URL.
  ///
  /// The response map contains:
  /// - `orderId` — the PayPal order ID
  /// - `approveUrl` — redirect the buyer to this URL
  ///
  /// Optionally specify [fundingSource] to pre-select the funding method.
  Future<Either<PaymentFailure, Map<String, String>>> createOrder({
    required String amount,
    required String currencyCode,
    required String returnUrl,
    required String cancelUrl,
    String intent = 'CAPTURE',
    PaypalFundingSource? fundingSource,
    String? description,
  }) async {
    final tokenResult = await _getAccessToken();
    return tokenResult.fold(Left.new, (token) async {
      final body = jsonEncode({
        'intent': intent,
        'purchase_units': [
          {
            'amount': {
              'currency_code': currencyCode,
              'value': amount,
            },
            'description': ?description,
          }
        ],
        'application_context': {
          'return_url': returnUrl,
          'cancel_url': cancelUrl,
          'user_action': 'PAY_NOW',
          if (fundingSource != null)
            'funding_source': _fundingSourceKey(fundingSource),
        },
      });

      try {
        final resp = await _client.post(
          Uri.parse('$_baseUrl/v2/checkout/orders'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body,
        );
        if (resp.statusCode != 201 && resp.statusCode != 200) {
          return Left(PaymentFailure(
            code: 'CREATE_ORDER_ERROR',
            message:
                'Web createOrder failed: ${resp.statusCode} — ${resp.body}',
          ));
        }
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final orderId = json['id'] as String? ?? '';
        final links = (json['links'] as List<dynamic>?) ?? [];
        final approveLink = links.firstWhere(
          (l) => (l as Map<String, dynamic>)['rel'] == 'approve',
          orElse: () => <String, dynamic>{'href': ''},
        ) as Map<String, dynamic>;
        final approveUrl = approveLink['href'] as String? ?? '';

        return Right({'orderId': orderId, 'approveUrl': approveUrl});
      } catch (e) {
        return Left(PaymentFailure(
          code: 'CREATE_ORDER_ERROR',
          message: 'Web createOrder error: $e',
        ));
      }
    });
  }

  /// Capture a previously-approved order.
  ///
  /// Call this after the buyer is redirected back from PayPal with the
  /// `token` query parameter matching the `orderId`.
  Future<Either<PaymentFailure, PaymentSuccess>> captureOrder({
    required String orderId,
  }) async {
    final tokenResult = await _getAccessToken();
    return tokenResult.fold(Left.new, (token) async {
      try {
        final resp = await _client.post(
          Uri.parse('$_baseUrl/v2/checkout/orders/$orderId/capture'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: '{}',
        );
        if (resp.statusCode != 201 && resp.statusCode != 200) {
          return Left(PaymentFailure(
            code: 'CAPTURE_ERROR',
            message:
                'Web captureOrder failed: ${resp.statusCode} — ${resp.body}',
          ));
        }
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        return Right(PaymentSuccess(
          orderId: json['id'] as String? ?? orderId,
          payerId:
              (json['payment_source'] as Map<String, dynamic>?)?['paypal']
                      ?['account_id'] as String? ??
                  '',
        ));
      } catch (e) {
        return Left(PaymentFailure(
          code: 'CAPTURE_ERROR',
          message: 'Web captureOrder error: $e',
        ));
      }
    });
  }

  // ── JS SDK ────────────────────────────────────────────────

  /// Ensure the PayPal JS SDK is loaded (Flutter Web only).
  ///
  /// Call before rendering [PaypalCheckoutButton] on web so the underlying
  /// `paypal.Buttons()` JS object is available.
  Future<void> ensureSdkLoaded({
    String currency = 'USD',
    List<PaypalFundingSource>? fundingSources,
  }) =>
      PaypalJsSdkLoader.ensureLoaded(
        clientId: _config.clientId,
        environment: _config.environment,
        currency: currency,
        fundingSources: fundingSources,
      );

  // ── Internals ─────────────────────────────────────────────

  static String _fundingSourceKey(PaypalFundingSource source) {
    switch (source) {
      case PaypalFundingSource.paypal:
        return 'paypal';
      case PaypalFundingSource.payLater:
        return 'paylater';
      case PaypalFundingSource.venmo:
        return 'venmo';
      case PaypalFundingSource.credit:
        return 'credit';
      case PaypalFundingSource.debit:
        return 'card';
    }
  }

  void dispose() => _client.close();
}
