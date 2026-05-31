import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

void main() {
  group('PaypalSellerStatus', () {
    test('fromJson parses all fields', () {
      final json = {
        'merchant_id': 'MERCHANT123',
        'payments_receivable': true,
        'primary_email_confirmed': true,
        'oauth_integrations': [
          {
            'integration_type': 'OAUTH_THIRD_PARTY',
            'oauth_third_party': [
              {
                'partner_client_id': 'CLIENT_ID',
                'merchant_client_id': 'MERCHANT_CLIENT',
                'scopes': ['https://uri.paypal.com/services/payments/initiatepayment'],
              }
            ],
          }
        ],
      };

      final status = PaypalSellerStatus.fromJson(json);
      expect(status.merchantId, 'MERCHANT123');
      expect(status.paymentsReceivable, isTrue);
      expect(status.primaryEmailConfirmed, isTrue);
    });

    test('isFullyOnboarded true when all conditions met', () {
      const status = PaypalSellerStatus(
        merchantId: 'M123',
        paymentsReceivable: true,
        primaryEmailConfirmed: true,
        oauthIntegrated: true,
        consentStatus: true,
      );

      expect(status.isFullyOnboarded, isTrue);
    });

    test('isFullyOnboarded false if any field false', () {
      const status = PaypalSellerStatus(
        merchantId: 'M123',
        paymentsReceivable: true,
        primaryEmailConfirmed: false, // not confirmed
        oauthIntegrated: true,
        consentStatus: true,
      );

      expect(status.isFullyOnboarded, isFalse);
    });

    test('isFullyOnboarded false if oauthIntegrated is false', () {
      const status = PaypalSellerStatus(
        merchantId: 'M123',
        paymentsReceivable: true,
        primaryEmailConfirmed: true,
        oauthIntegrated: false,
        consentStatus: true,
      );

      expect(status.isFullyOnboarded, isFalse);
    });

    test('isFullyOnboarded false if paymentsReceivable is false', () {
      const status = PaypalSellerStatus(
        merchantId: 'M123',
        paymentsReceivable: false,
        primaryEmailConfirmed: true,
        oauthIntegrated: true,
        consentStatus: true,
      );

      expect(status.isFullyOnboarded, isFalse);
    });
  });

  group('PaypalPartnerReferral', () {
    test('fromJson parses fields', () {
      final json = {
        'partner_referral_id': 'REFERRAL123',
        'links': [
          {'rel': 'action_url', 'href': 'https://paypal.com/onboard?token=abc'},
        ],
      };

      final referral = PaypalPartnerReferral.fromJson(json);
      expect(referral.referralId, 'REFERRAL123');
      expect(referral.actionUrl, 'https://paypal.com/onboard?token=abc');
    });

    test('fromJson handles missing links gracefully', () {
      final json = {'partner_referral_id': 'REF456', 'links': <dynamic>[]};
      final referral = PaypalPartnerReferral.fromJson(json);
      expect(referral.referralId, 'REF456');
      expect(referral.actionUrl, isEmpty);
    });
  });
}
