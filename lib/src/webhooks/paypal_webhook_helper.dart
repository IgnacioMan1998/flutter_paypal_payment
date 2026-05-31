import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../core/constants/paypal_api_constants.dart';
import '../core/enums/paypal_enums.dart';
import 'paypal_webhook_event.dart';

/// Server-side utilities for validating and parsing PayPal webhook deliveries.
///
/// > **Important:** Webhook verification must happen on your **backend server**,
/// > not inside a Flutter app, as it requires your webhook secret. This helper
/// > is provided for Dart server code (e.g., `shelf`, `dart_frog`, `serverpod`)
/// > that processes PayPal webhooks.
///
/// ## Signature verification (HMAC-SHA256)
///
/// PayPal signs each webhook delivery. Verify locally with your secret:
///
/// ```dart
/// final isValid = PaypalWebhookHelper.verifySignatureLocal(
///   webhookId: 'WH-...',
///   transmissionId: request.headers['paypal-transmission-id']!,
///   transmissionTime: request.headers['paypal-transmission-time']!,
///   certUrl: request.headers['paypal-cert-url']!,
///   authAlgo: request.headers['paypal-auth-algo']!,
///   actualSignature: request.headers['paypal-transmission-sig']!,
///   webhookSecret: 'YOUR_WEBHOOK_SECRET',
///   body: await request.readAsString(),
/// );
/// ```
///
/// ## Remote verification via PayPal API
///
/// For maximum accuracy, offload verification to PayPal's own endpoint:
///
/// ```dart
/// final result = await PaypalWebhookHelper.verifyViaApi(
///   clientId: 'CLIENT_ID',
///   clientSecret: 'CLIENT_SECRET',
///   environment: PaypalEnvironment.sandbox,
///   webhookId: 'WH-...',
///   headers: request.headers,
///   body: rawBody,
/// );
/// ```
abstract final class PaypalWebhookHelper {
  // ── Signature verification (local HMAC) ───────────────────

  /// Verify a PayPal webhook signature locally using HMAC-SHA256.
  ///
  /// Parameters match the HTTP headers PayPal attaches to every delivery:
  /// - `paypal-transmission-id`
  /// - `paypal-transmission-time`
  /// - `paypal-cert-url`
  /// - `paypal-auth-algo`
  /// - `paypal-transmission-sig`
  ///
  /// Returns `true` only when the computed signature matches [actualSignature].
  static bool verifySignatureLocal({
    required String webhookId,
    required String transmissionId,
    required String transmissionTime,
    required String certUrl,
    required String authAlgo,
    required String actualSignature,
    required String webhookSecret,
    required String body,
  }) {
    // PayPal's signature message is: transmissionId|transmissionTime|webhookId|CRC32(body)
    final crc = _crc32(utf8.encode(body));
    final message = '$transmissionId|$transmissionTime|$webhookId|$crc';

    final key = utf8.encode(webhookSecret);
    final bytes = utf8.encode(message);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    final computed = base64.encode(digest.bytes);

    return computed == actualSignature;
  }

  // ── Remote verification via PayPal REST API ───────────────

  /// Verify a webhook delivery using the PayPal
  /// `POST /v1/notifications/verify-webhook-signature` endpoint.
  ///
  /// Returns `true` when PayPal responds with `"SUCCESS"`.
  static Future<bool> verifyViaApi({
    required String clientId,
    required String clientSecret,
    required PaypalEnvironment environment,
    required String webhookId,
    required Map<String, String> headers,
    required String body,
  }) async {
    final baseUrl = environment == PaypalEnvironment.sandbox
        ? PaypalApiConstants.sandboxBaseUrl
        : PaypalApiConstants.liveBaseUrl;

    // 1. Get access token
    final credentials =
        base64.encode(utf8.encode('$clientId:$clientSecret'));
    final tokenResponse = await http.post(
      Uri.parse('$baseUrl${PaypalApiConstants.oauthTokenPath}'),
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': PaypalApiConstants.contentTypeForm,
      },
      body: PaypalApiConstants.grantTypeCredentials,
    );

    if (tokenResponse.statusCode != 200) return false;

    final tokenJson =
        jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    final accessToken = tokenJson['access_token'] as String? ?? '';
    if (accessToken.isEmpty) return false;

    // 2. Verify signature
    final verifyResponse = await http.post(
      Uri.parse('$baseUrl/v1/notifications/verify-webhook-signature'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'auth_algo':
            headers['paypal-auth-algo'] ?? headers['PAYPAL-AUTH-ALGO'] ?? '',
        'cert_url':
            headers['paypal-cert-url'] ?? headers['PAYPAL-CERT-URL'] ?? '',
        'transmission_id': headers['paypal-transmission-id'] ??
            headers['PAYPAL-TRANSMISSION-ID'] ??
            '',
        'transmission_sig': headers['paypal-transmission-sig'] ??
            headers['PAYPAL-TRANSMISSION-SIG'] ??
            '',
        'transmission_time': headers['paypal-transmission-time'] ??
            headers['PAYPAL-TRANSMISSION-TIME'] ??
            '',
        'webhook_id': webhookId,
        'webhook_event': jsonDecode(body),
      }),
    );

    if (verifyResponse.statusCode != 200) return false;

    final result =
        jsonDecode(verifyResponse.body) as Map<String, dynamic>;
    return (result['verification_status'] as String? ?? '') == 'SUCCESS';
  }

  // ── Event parsing ─────────────────────────────────────────

  /// Parse the raw JSON [body] of a PayPal webhook delivery into a
  /// typed [PaypalWebhookEvent].
  ///
  /// Throws [FormatException] when [body] is not valid JSON or not a JSON object.
  static PaypalWebhookEvent parse(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw const FormatException('Webhook body is not valid JSON');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'Webhook body must be a JSON object, not an array or primitive');
    }

    return PaypalWebhookEvent.fromJson(decoded);
  }

  /// Attempts to parse the raw JSON [body] without throwing.
  /// Returns `null` on any error.
  static PaypalWebhookEvent? tryParse(String body) {
    try {
      return parse(body);
    } catch (_) {
      return null;
    }
  }

  // ── CRC-32 helper ─────────────────────────────────────────

  /// Standard CRC-32 checksum used in PayPal's signature message.
  static int _crc32(List<int> bytes) {
    const poly = 0xEDB88320;
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ poly : crc >> 1;
      }
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}
