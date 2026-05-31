import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../domain/entities/payment_result.dart';
import '../core/enums/paypal_enums.dart';

// ═══════════════════════════════════════════════════════════
// Pay Later Offer model
// ═══════════════════════════════════════════════════════════

/// A financing offer returned by PayPal's assessed-financing API.
///
/// Obtain via [PayLaterOfferService.getOffer].
class PayLaterOffer {
  const PayLaterOffer({
    required this.amount,
    required this.monthlyAmount,
    required this.installments,
    required this.currencyCode,
    this.disclosure = '',
    this.offerType = '',
    this.rawResponse,
  });

  /// Total purchase amount.
  final String amount;

  /// Estimated monthly payment (amount / installments).
  final String monthlyAmount;

  /// Number of installments (e.g. 4 for Pay in 4).
  final int installments;

  /// ISO 4217 currency code.
  final String currencyCode;

  /// Legal disclosure text shown to the buyer.
  final String disclosure;

  /// PayPal offer type identifier (e.g. `'PAY_IN_X'`, `'PAYPAL_CREDIT'`).
  final String offerType;

  /// Raw API response for custom processing.
  final Map<String, dynamic>? rawResponse;

  /// Formats [monthlyAmount] as a display string with currency symbol.
  String get formattedMonthly {
    final symbol = _currencySymbol(currencyCode);
    return '$symbol$monthlyAmount';
  }

  /// Human-readable summary, e.g. `"4 payments of $12.50"`.
  String get summary => '$installments payments of $formattedMonthly';

  factory PayLaterOffer.fromJson(Map<String, dynamic> json, String amount, String currencyCode) {
    // Extract from PayPal assessed-financing response
    final options = (json['financing_options'] as List<dynamic>?) ?? [];
    if (options.isEmpty) {
      return PayLaterOffer(
        amount: amount,
        monthlyAmount: _calculateMonthly(amount, 4),
        installments: 4,
        currencyCode: currencyCode,
        offerType: 'PAY_IN_4',
        rawResponse: json,
      );
    }
    final first = options.first as Map<String, dynamic>;
    final qualifier = (first['qualifying_financing_options'] as List<dynamic>?)?.first
        as Map<String, dynamic>? ?? {};

    final installments = (qualifier['credit_financing'] as Map<String, dynamic>?)?
        ['minimum_amount_due'] != null
        ? 4
        : _parseInstallments(qualifier);

    final monthlyRaw = qualifier['monthly_payment'] as Map<String, dynamic>?;
    final monthlyValue = (monthlyRaw?['value'] as String?) ??
        _calculateMonthly(amount, installments);

    return PayLaterOffer(
      amount: amount,
      monthlyAmount: monthlyValue,
      installments: installments,
      currencyCode: (monthlyRaw?['currency_code'] as String?) ?? currencyCode,
      disclosure: (qualifier['disclosure'] as String?) ?? '',
      offerType: (qualifier['credit_type'] as String?) ?? 'PAY_IN_X',
      rawResponse: json,
    );
  }

  static int _parseInstallments(Map<String, dynamic> qualifier) {
    final payInX = qualifier['pay_in_x_options'] as Map<String, dynamic>?;
    return (payInX?['number_of_installments'] as int?) ?? 4;
  }

  static String _calculateMonthly(String totalStr, int installments) {
    final total = double.tryParse(totalStr) ?? 0.0;
    if (installments <= 0) return totalStr;
    return (total / installments).toStringAsFixed(2);
  }

  static String _currencySymbol(String code) {
    const symbols = {
      'USD': '\$', 'EUR': '€', 'GBP': '£', 'JPY': '¥',
      'AUD': 'A\$', 'CAD': 'C\$', 'MXN': 'MX\$', 'BRL': 'R\$',
    };
    return symbols[code.toUpperCase()] ?? '$code ';
  }
}

// ═══════════════════════════════════════════════════════════
// Pay Later Offer Service
// ═══════════════════════════════════════════════════════════

/// Retrieves Pay Later financing offers from PayPal's REST API.
///
/// ```dart
/// final result = await PayLaterOfferService.getOffer(
///   clientId: 'CLIENT_ID',
///   clientSecret: 'SECRET',
///   environment: PaypalEnvironment.sandbox,
///   amount: '120.00',
///   currencyCode: 'USD',
///   buyerCountryCode: 'US',
/// );
/// result.fold(
///   (err)   => print('No offer: ${err.message}'),
///   (offer) => print(offer.summary), // "4 payments of $30.00"
/// );
/// ```
abstract final class PayLaterOfferService {
  static final Map<String, _CachedOffer> _cache = {};

  /// How long a cached offer is considered fresh.
  static Duration cacheDuration = const Duration(minutes: 10);

  /// Fetch a Pay Later offer for the given amount and buyer context.
  ///
  /// Returns [PayLaterOffer] on success, or [PaymentFailure] if:
  /// - No Pay Later offer is available for this combination
  /// - Authentication fails
  /// - Network error occurs
  static Future<Either<PaymentFailure, PayLaterOffer>> getOffer({
    required String clientId,
    required String clientSecret,
    required PaypalEnvironment environment,
    required String amount,
    String currencyCode = 'USD',
    String? buyerCountryCode,
    bool forceRefresh = false,
    http.Client? httpClient,
  }) async {
    final key = '$clientId|$amount|$currencyCode|${buyerCountryCode ?? ''}';

    if (!forceRefresh) {
      final cached = _cache[key];
      if (cached != null && !cached.isExpired) {
        return Right(cached.offer);
      }
    }

    final client = httpClient ?? http.Client();
    final baseUrl = environment == PaypalEnvironment.sandbox
        ? 'https://api-m.sandbox.paypal.com'
        : 'https://api-m.paypal.com';

    try {
      // OAuth token
      final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
      final tokenResp = await client.post(
        Uri.parse('$baseUrl/v1/oauth2/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      );
      if (tokenResp.statusCode != 200) {
        return Left(PaymentFailure(
          code: 'AUTH_ERROR',
          message: 'Failed to authenticate for Pay Later offer',
        ));
      }
      final tokenData = jsonDecode(tokenResp.body) as Map<String, dynamic>;
      final accessToken = tokenData['access_token'] as String;

      // Fetch offer
      final queryParams = {
        'financing_country_code': buyerCountryCode ?? 'US',
        'transaction_amount': amount,
        'currency_code': currencyCode,
      };
      final uri = Uri.parse('$baseUrl/v1/credit/assessed-financing')
          .replace(queryParameters: queryParams);
      final resp = await client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 204 || resp.body.isEmpty) {
        return Left(PaymentFailure(
          code: 'NO_PAYLATER_OFFER',
          message:
              'No Pay Later offer available for $currencyCode $amount in ${buyerCountryCode ?? 'this region'}',
        ));
      }

      if (resp.statusCode != 200) {
        return Left(PaymentFailure(
          code: 'PAYLATER_API_ERROR',
          message: 'Pay Later API returned ${resp.statusCode}: ${resp.body}',
        ));
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final offer = PayLaterOffer.fromJson(json, amount, currencyCode);
      _cache[key] = _CachedOffer(offer);
      return Right(offer);
    } catch (e) {
      return Left(PaymentFailure(
        code: 'PAYLATER_ERROR',
        message: 'Failed to get Pay Later offer: $e',
      ));
    } finally {
      if (httpClient == null) client.close();
    }
  }

  /// Clears the in-memory offer cache.
  static void clearCache() => _cache.clear();
}

// ── Cache support ─────────────────────────────────────────

class _CachedOffer {
  _CachedOffer(this.offer) : _createdAt = DateTime.now();
  final PayLaterOffer offer;
  final DateTime _createdAt;

  bool get isExpired =>
      DateTime.now().difference(_createdAt) > PayLaterOfferService.cacheDuration;
}
