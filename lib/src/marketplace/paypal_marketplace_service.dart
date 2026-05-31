import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../domain/entities/payment_result.dart';
import '../core/enums/paypal_enums.dart';
import '../domain/entities/paypal_config.dart';

// ═══════════════════════════════════════════════════════════
// Marketplace / Commerce Platform models
// ═══════════════════════════════════════════════════════════

/// Represents a PayPal partner referral used to onboard merchants.
class PaypalPartnerReferral {
  const PaypalPartnerReferral({
    required this.partnerId,
    required this.actionUrl,
    this.referralId,
    this.rawResponse,
  });

  /// PayPal payer ID of the partner/platform.
  final String partnerId;

  /// URL the merchant is redirected to for account setup.
  final String actionUrl;

  /// Referral token (PayPal-generated).
  final String? referralId;

  /// Raw API response.
  final Map<String, dynamic>? rawResponse;

  factory PaypalPartnerReferral.fromJson(Map<String, dynamic> json) {
    final links = (json['links'] as List<dynamic>?) ?? [];
    Map<String, dynamic> actionLink = {'href': ''};
    for (final l in links) {
      final link = l as Map<String, dynamic>;
      if (link['rel'] == 'action_url') {
        actionLink = link;
        break;
      }
    }

    return PaypalPartnerReferral(
      partnerId: json['partner_client_id'] as String? ?? '',
      actionUrl: actionLink['href'] as String? ?? '',
      referralId: json['referral_id'] as String?,
      rawResponse: json,
    );
  }
}

/// Status of an onboarded seller/merchant account.
class PaypalSellerStatus {
  const PaypalSellerStatus({
    required this.merchantId,
    required this.paymentsReceivable,
    required this.primaryEmailConfirmed,
    required this.oauthIntegrated,
    this.consentStatus,
    this.rawResponse,
  });

  /// The merchant's PayPal payer ID.
  final String merchantId;

  /// `true` when the merchant can receive payments.
  final bool paymentsReceivable;

  /// `true` when the merchant's primary email is confirmed.
  final bool primaryEmailConfirmed;

  /// `true` when the OAuth grant is still active.
  final bool oauthIntegrated;

  /// Consent status from the partner referral.
  final Map<String, dynamic>? consentStatus;

  /// Raw API response.
  final Map<String, dynamic>? rawResponse;

  /// `true` when the merchant is fully onboarded and can transact.
  bool get isFullyOnboarded =>
      paymentsReceivable && primaryEmailConfirmed && oauthIntegrated;

  factory PaypalSellerStatus.fromJson(Map<String, dynamic> json) {
    return PaypalSellerStatus(
      merchantId: json['merchant_id'] as String? ?? '',
      paymentsReceivable: json['payments_receivable'] as bool? ?? false,
      primaryEmailConfirmed:
          json['primary_email_confirmed'] as bool? ?? false,
      oauthIntegrated: json['oauth_integrations'] != null
          ? ((json['oauth_integrations'] as List<dynamic>).isNotEmpty)
          : false,
      consentStatus:
          json['oauth_third_party'] as Map<String, dynamic>?,
      rawResponse: json,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Marketplace Service
// ═══════════════════════════════════════════════════════════

/// PayPal Commerce Platform (marketplace) operations.
///
/// Enables multi-seller checkout, revenue splitting, and merchant onboarding
/// via the PayPal Partner Referrals API.
///
/// ## Onboarding flow
/// ```dart
/// final service = PaypalMarketplaceService(
///   config: cfg,
///   clientSecret: 'SECRET',
///   partnerMerchantId: 'PARTNER_PAYER_ID',
/// );
///
/// // 1. Create a referral — redirect merchant to actionUrl
/// final ref = await service.createPartnerReferral(
///   merchantEmail: 'seller@example.com',
///   trackingId: 'seller_123',
/// );
///
/// // 2. After merchant completes onboarding, check status
/// final status = await service.getSellerStatus(merchantId: 'MERCHANT_ID');
///
/// // 3. Create a marketplace order with platform fee
/// final order = await service.createMarketplaceOrder(
///   amount: '100.00',
///   currencyCode: 'USD',
///   sellerMerchantId: 'MERCHANT_ID',
///   platformFee: '5.00',
/// );
/// ```
class PaypalMarketplaceService {
  PaypalMarketplaceService({
    required PaypalConfig config,
    required String clientSecret,
    required this.partnerMerchantId,
    http.Client? httpClient,
  })  : _config = config,
        _clientSecret = clientSecret,
        _client = httpClient ?? http.Client();

  final PaypalConfig _config;
  final String _clientSecret;
  final http.Client _client;

  /// The platform's PayPal Payer ID (obtained from your PayPal partner account).
  final String partnerMerchantId;

  String get _baseUrl => _config.environment == PaypalEnvironment.sandbox
      ? 'https://api-m.sandbox.paypal.com'
      : 'https://api-m.paypal.com';

  // Token cache
  String? _cachedToken;
  DateTime? _tokenExpiry;

  // ── Auth ──────────────────────────────────────────────────

  Future<Either<PaymentFailure, String>> _getAccessToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return Right(_cachedToken!);
    }

    final credentials = base64Encode(utf8.encode('${_config.clientId}:$_clientSecret'));
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
          message: 'Marketplace auth failed: ${resp.statusCode}',
        ));
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      _cachedToken = data['access_token'] as String;
      final expiresIn = (data['expires_in'] as int?) ?? 32400;
      _tokenExpiry =
          DateTime.now().add(Duration(seconds: expiresIn - 60));
      return Right(_cachedToken!);
    } catch (e) {
      return Left(PaymentFailure(
        code: 'AUTH_ERROR',
        message: 'Marketplace auth error: $e',
      ));
    }
  }

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'PayPal-Partner-Attribution-Id': partnerMerchantId,
      };

  // ── Partner Referrals ─────────────────────────────────────

  /// Create a partner referral to begin merchant onboarding.
  ///
  /// Redirect the merchant to [PaypalPartnerReferral.actionUrl] to complete
  /// PayPal account setup and grant your platform OAuth permissions.
  ///
  /// [trackingId] is your internal merchant identifier (max 127 chars).
  /// [returnUrl] is where PayPal redirects after onboarding (optional).
  Future<Either<PaymentFailure, PaypalPartnerReferral>> createPartnerReferral({
    required String merchantEmail,
    required String trackingId,
    String? returnUrl,
    List<String> products = const ['EXPRESS_CHECKOUT'],
    List<String> capabilities = const [
      'APPLE_PAY',
      'GOOGLE_PAY',
      'VENMO',
    ],
  }) async {
    final tokenResult = await _getAccessToken();
    return tokenResult.fold(Left.new, (token) async {
      final body = jsonEncode({
        'tracking_id': trackingId,
        'partner_config_override': {
          'return_url': ?returnUrl,
          'return_url_description': 'Return to app after PayPal onboarding',
        },
        'operations': [
          {
            'operation': 'API_INTEGRATION',
            'api_integration_preference': {
              'rest_api_integration': {
                'integration_method': 'PAYPAL',
                'integration_type': 'THIRD_PARTY',
                'third_party_details': {
                  'features': ['PAYMENT', 'REFUND', 'PARTNER_FEE'],
                },
              },
            },
          }
        ],
        'products': products,
        'legal_consents': [
          {'type': 'SHARE_DATA_CONSENT', 'granted': true}
        ],
        'email': merchantEmail,
      });

      try {
        final resp = await _client.post(
          Uri.parse('$_baseUrl/v2/customer/partner-referrals'),
          headers: _authHeaders(token),
          body: body,
        );
        if (resp.statusCode != 201 && resp.statusCode != 200) {
          return Left(PaymentFailure(
            code: 'PARTNER_REFERRAL_ERROR',
            message:
                'createPartnerReferral failed: ${resp.statusCode} — ${resp.body}',
          ));
        }
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        return Right(PaypalPartnerReferral.fromJson(json));
      } catch (e) {
        return Left(PaymentFailure(
          code: 'PARTNER_REFERRAL_ERROR',
          message: 'createPartnerReferral error: $e',
        ));
      }
    });
  }

  /// Retrieve the onboarding and consent status of a merchant.
  ///
  /// Call this after the merchant returns from the PayPal onboarding URL.
  /// Check [PaypalSellerStatus.isFullyOnboarded] before processing payments.
  Future<Either<PaymentFailure, PaypalSellerStatus>> getSellerStatus({
    required String merchantId,
  }) async {
    final tokenResult = await _getAccessToken();
    return tokenResult.fold(Left.new, (token) async {
      try {
        final resp = await _client.get(
          Uri.parse(
              '$_baseUrl/v1/customer/partners/$partnerMerchantId/merchant-integrations/$merchantId'),
          headers: _authHeaders(token),
        );
        if (resp.statusCode != 200) {
          return Left(PaymentFailure(
            code: 'GET_SELLER_STATUS_ERROR',
            message:
                'getSellerStatus failed: ${resp.statusCode} — ${resp.body}',
          ));
        }
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        return Right(PaypalSellerStatus.fromJson(json));
      } catch (e) {
        return Left(PaymentFailure(
          code: 'GET_SELLER_STATUS_ERROR',
          message: 'getSellerStatus error: $e',
        ));
      }
    });
  }

  /// Create a marketplace order with platform fee splitting.
  ///
  /// The [sellerMerchantId] receives [amount] minus [platformFee].
  /// The platform receives [platformFee] automatically via PayPal.
  Future<Either<PaymentFailure, Map<String, dynamic>>> createMarketplaceOrder({
    required String amount,
    required String currencyCode,
    required String sellerMerchantId,
    String? platformFee,
    String intent = 'CAPTURE',
    String? returnUrl,
    String? cancelUrl,
    String? description,
  }) async {
    final tokenResult = await _getAccessToken();
    return tokenResult.fold(Left.new, (token) async {
      final paymentInstruction = platformFee != null
          ? {
              'disbursement_mode': 'INSTANT',
              'platform_fees': [
                {
                  'amount': {
                    'currency_code': currencyCode,
                    'value': platformFee,
                  },
                  'payee': {
                    'merchant_id': partnerMerchantId,
                  },
                }
              ],
            }
          : null;

      final purchaseUnit = {
        'amount': {
          'currency_code': currencyCode,
          'value': amount,
        },
        'payee': {
          'merchant_id': sellerMerchantId,
        },
        'description': ?description,
        'payment_instruction': ?paymentInstruction,
      };

      final orderBody = {
        'intent': intent,
        'purchase_units': [purchaseUnit],
        if (returnUrl != null || cancelUrl != null)
          'application_context': {
            'return_url': ?returnUrl,
            'cancel_url': ?cancelUrl,
          },
      };

      try {
        final resp = await _client.post(
          Uri.parse('$_baseUrl/v2/checkout/orders'),
          headers: {
            ..._authHeaders(token),
            'PayPal-Auth-Assertion': _buildAuthAssertion(sellerMerchantId),
          },
          body: jsonEncode(orderBody),
        );
        if (resp.statusCode != 201 && resp.statusCode != 200) {
          return Left(PaymentFailure(
            code: 'CREATE_MARKETPLACE_ORDER_ERROR',
            message:
                'createMarketplaceOrder failed: ${resp.statusCode} — ${resp.body}',
          ));
        }
        return Right(jsonDecode(resp.body) as Map<String, dynamic>);
      } catch (e) {
        return Left(PaymentFailure(
          code: 'CREATE_MARKETPLACE_ORDER_ERROR',
          message: 'createMarketplaceOrder error: $e',
        ));
      }
    });
  }

  /// Capture a previously-authorized marketplace order on behalf of a seller.
  Future<Either<PaymentFailure, Map<String, dynamic>>> captureForMerchant({
    required String orderId,
    required String sellerMerchantId,
  }) async {
    final tokenResult = await _getAccessToken();
    return tokenResult.fold(Left.new, (token) async {
      try {
        final resp = await _client.post(
          Uri.parse('$_baseUrl/v2/checkout/orders/$orderId/capture'),
          headers: {
            ..._authHeaders(token),
            'PayPal-Auth-Assertion': _buildAuthAssertion(sellerMerchantId),
          },
          body: '{}',
        );
        if (resp.statusCode != 201 && resp.statusCode != 200) {
          return Left(PaymentFailure(
            code: 'CAPTURE_FOR_MERCHANT_ERROR',
            message:
                'captureForMerchant failed: ${resp.statusCode} — ${resp.body}',
          ));
        }
        return Right(jsonDecode(resp.body) as Map<String, dynamic>);
      } catch (e) {
        return Left(PaymentFailure(
          code: 'CAPTURE_FOR_MERCHANT_ERROR',
          message: 'captureForMerchant error: $e',
        ));
      }
    });
  }

  // ── Internals ─────────────────────────────────────────────

  /// Builds a PayPal-Auth-Assertion header for acting on behalf of a seller.
  String _buildAuthAssertion(String sellerMerchantId) {
    final header = base64Url.encode(
      utf8.encode(jsonEncode({'alg': 'none'})),
    );
    final payload = base64Url.encode(
      utf8.encode(jsonEncode({
        'iss': _config.clientId,
        'payer_id': sellerMerchantId,
      })),
    );
    return '$header.$payload.';
  }

  /// Release HTTP resources.
  void dispose() => _client.close();
}
