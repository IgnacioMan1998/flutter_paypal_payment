import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../core/enums/paypal_enums.dart';
import '../domain/entities/payment_result.dart';

// ═══════════════════════════════════════════════════════════
// Funding eligibility models
// ═══════════════════════════════════════════════════════════

/// Eligibility result for all supported PayPal funding sources.
///
/// Obtained via [PaypalFundingEligibility.check] — uses the PayPal REST API
/// to determine which funding sources are available for a given buyer context.
///
/// ```dart
/// final result = await PaypalFundingEligibility.check(
///   clientId: 'CLIENT_ID',
///   clientSecret: 'SECRET',
///   environment: PaypalEnvironment.sandbox,
///   currencyCode: 'USD',
///   buyerCountryCode: 'US',
/// );
/// result.fold(
///   (err)  => print('Error: ${err.message}'),
///   (elig) => print('PayPal: ${elig.paypalEligible}, Pay Later: ${elig.payLaterEligible}'),
/// );
/// ```
class FundingEligibilityResult {
  const FundingEligibilityResult({
    required this.paypalEligible,
    required this.payLaterEligible,
    required this.venmoEligible,
    required this.creditEligible,
    required this.debitEligible,
    this.rawResponse,
  });

  /// PayPal balance / linked bank account checkout.
  final bool paypalEligible;

  /// Pay Later (Pay in 4, Pay Monthly, BNPL).
  final bool payLaterEligible;

  /// Venmo (US only, requires Venmo app).
  final bool venmoEligible;

  /// PayPal Credit (revolving credit line, US only).
  final bool creditEligible;

  /// Debit card via PayPal.
  final bool debitEligible;

  /// Raw API response for custom processing.
  final Map<String, dynamic>? rawResponse;

  /// Ordered list of eligible funding sources, most preferred first.
  List<PaypalFundingSource> get eligibleSources {
    return [
      if (paypalEligible) PaypalFundingSource.paypal,
      if (payLaterEligible) PaypalFundingSource.payLater,
      if (venmoEligible) PaypalFundingSource.venmo,
      if (creditEligible) PaypalFundingSource.credit,
      if (debitEligible) PaypalFundingSource.debit,
    ];
  }

  /// `true` when at least one funding source is available.
  bool get hasAnyEligibleSource => eligibleSources.isNotEmpty;

  /// Returns `true` if [source] is eligible.
  bool isEligible(PaypalFundingSource source) {
    switch (source) {
      case PaypalFundingSource.paypal:
        return paypalEligible;
      case PaypalFundingSource.payLater:
        return payLaterEligible;
      case PaypalFundingSource.venmo:
        return venmoEligible;
      case PaypalFundingSource.credit:
        return creditEligible;
      case PaypalFundingSource.debit:
        return debitEligible;
    }
  }

  @override
  String toString() => 'FundingEligibilityResult('
      'paypal=$paypalEligible, '
      'payLater=$payLaterEligible, '
      'venmo=$venmoEligible, '
      'credit=$creditEligible, '
      'debit=$debitEligible'
      ')';
}

// ═══════════════════════════════════════════════════════════
// Eligibility service
// ═══════════════════════════════════════════════════════════

/// Checks which PayPal funding sources are available for a buyer context.
///
/// Results are **cached** for [cacheDuration] (default 5 minutes) per unique
/// `(clientId, currencyCode, countryCode)` key — suitable for calling in
/// `initState` or before rendering checkout UI.
abstract final class PaypalFundingEligibility {
  static final Map<String, _CachedEligibility> _cache = {};

  /// How long a cached eligibility result is considered fresh.
  static Duration cacheDuration = const Duration(minutes: 5);

  // ── Public API ────────────────────────────────────────────

  /// Determine which funding sources are available for the given context.
  ///
  /// Uses PayPal's `/v1/credit/assessed-financing` and eligibility signals
  /// to build a complete [FundingEligibilityResult].
  ///
  /// **Cache:** Results for the same `(clientId, currencyCode, buyerCountryCode)`
  /// tuple are cached for [cacheDuration]. Pass [forceRefresh] to bypass.
  static Future<Either<PaymentFailure, FundingEligibilityResult>> check({
    required String clientId,
    required String clientSecret,
    required PaypalEnvironment environment,
    String currencyCode = 'USD',
    String? buyerCountryCode,
    bool forceRefresh = false,
    http.Client? httpClient,
  }) async {
    final key = '$clientId|$currencyCode|${buyerCountryCode ?? ''}';

    if (!forceRefresh) {
      final cached = _cache[key];
      if (cached != null && !cached.isExpired) {
        return Right(cached.result);
      }
    }

    final client = httpClient ?? http.Client();
    final baseUrl = environment == PaypalEnvironment.sandbox
        ? 'https://api-m.sandbox.paypal.com'
        : 'https://api-m.paypal.com';

    try {
      // Obtain access token
      final tokenResult = await _getAccessToken(
        client: client,
        baseUrl: baseUrl,
        clientId: clientId,
        clientSecret: clientSecret,
      );
      if (tokenResult == null) {
        return Left(PaymentFailure(
          code: 'AUTH_ERROR',
          message: 'Failed to obtain access token for eligibility check',
        ));
      }

      final headers = {
        'Authorization': 'Bearer $tokenResult',
        'Content-Type': 'application/json',
      };

      // Build query: PayPal evaluates eligibility from the buyer country /
      // currency. Pay Later eligibility comes from assessed-financing endpoint.
      bool payLaterEligible = false;
      Map<String, dynamic>? payLaterRaw;

      final queryParams = {
        'currency_code': currencyCode,
        'country_code': ?buyerCountryCode,
      };
      final uri = Uri.parse('$baseUrl/v1/credit/assessed-financing')
          .replace(queryParameters: queryParams);

      final resp =
          await client.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        payLaterRaw = jsonDecode(resp.body) as Map<String, dynamic>;
        final financing = payLaterRaw['financing_options'] as List<dynamic>?;
        payLaterEligible = financing != null && financing.isNotEmpty;
      }
      // 204 = no offer → not eligible; other errors are non-fatal

      // Venmo eligibility: US-only
      final venmoEligible =
          (buyerCountryCode ?? '').toUpperCase() == 'US' ||
              (buyerCountryCode == null && currencyCode == 'USD');

      // Credit eligibility: US-only
      final creditEligible =
          (buyerCountryCode ?? '').toUpperCase() == 'US' ||
              (buyerCountryCode == null && currencyCode == 'USD');

      final result = FundingEligibilityResult(
        paypalEligible: true, // PayPal checkout is always available
        payLaterEligible: payLaterEligible,
        venmoEligible: venmoEligible,
        creditEligible: creditEligible,
        debitEligible: true, // Debit via PayPal is always available
        rawResponse: payLaterRaw,
      );

      _cache[key] = _CachedEligibility(result);
      return Right(result);
    } catch (e) {
      return Left(PaymentFailure(
        code: 'ELIGIBILITY_ERROR',
        message: 'Failed to check funding eligibility: $e',
      ));
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Returns the cached eligible funding sources without making a network call.
  /// Returns `null` if no cached result exists for this key.
  static List<PaypalFundingSource>? getCachedSources({
    required String clientId,
    String currencyCode = 'USD',
    String? buyerCountryCode,
  }) {
    final key = '$clientId|$currencyCode|${buyerCountryCode ?? ''}';
    final cached = _cache[key];
    if (cached == null || cached.isExpired) return null;
    return cached.result.eligibleSources;
  }

  /// Clears the in-memory eligibility cache.
  static void clearCache() => _cache.clear();

  // ── Internal ──────────────────────────────────────────────

  static Future<String?> _getAccessToken({
    required http.Client client,
    required String baseUrl,
    required String clientId,
    required String clientSecret,
  }) async {
    try {
      final credentials = base64Encode(
        utf8.encode('$clientId:$clientSecret'),
      );
      final response = await client.post(
        Uri.parse('$baseUrl/v1/oauth2/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['access_token'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ── Cache support ─────────────────────────────────────────

class _CachedEligibility {
  _CachedEligibility(this.result) : _createdAt = DateTime.now();
  final FundingEligibilityResult result;
  final DateTime _createdAt;

  bool get isExpired =>
      DateTime.now().difference(_createdAt) >
      PaypalFundingEligibility.cacheDuration;
}
