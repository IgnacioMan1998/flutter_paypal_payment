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
          {'integration_type': 'OAUTH_THIRD_PARTY'},
        ],
      };

      final status = PaypalSellerStatus.fromJson(json);
      expect(status.merchantId, 'MERCHANT123');
      expect(status.paymentsReceivable, isTrue);
      expect(status.primaryEmailConfirmed, isTrue);
      expect(status.oauthIntegrated, isTrue);
    });

    test('isFullyOnboarded true when all conditions met', () {
      const status = PaypalSellerStatus(
        merchantId: 'M123',
        paymentsReceivable: true,
        primaryEmailConfirmed: true,
        oauthIntegrated: true,
      );
      expect(status.isFullyOnboarded, isTrue);
    });

    test('isFullyOnboarded false if primaryEmailConfirmed is false', () {
      const status = PaypalSellerStatus(
        merchantId: 'M123',
        paymentsReceivable: true,
        primaryEmailConfirmed: false,
        oauthIntegrated: true,
      );
      expect(status.isFullyOnboarded, isFalse);
    });

    test('isFullyOnboarded false if oauthIntegrated is false', () {
      const status = PaypalSellerStatus(
        merchantId: 'M123',
        paymentsReceivable: true,
        primaryEmailConfirmed: true,
        oauthIntegrated: false,
      );
      expect(status.isFullyOnboarded, isFalse);
    });

    test('isFullyOnboarded false if paymentsReceivable is false', () {
      const status = PaypalSellerStatus(
        merchantId: 'M123',
        paymentsReceivable: false,
        primaryEmailConfirmed: true,
        oauthIntegrated: true,
      );
      expect(status.isFullyOnboarded, isFalse);
    });

    test('fromJson handles empty oauth_integrations', () {
      final json = {
        'merchant_id': 'M456',
        'payments_receivable': true,
        'primary_email_confirmed': true,
        'oauth_integrations': <dynamic>[],
      };
      final status = PaypalSellerStatus.fromJson(json);
      expect(status.oauthIntegrated, isFalse);
    });

    test('fromJson handles missing oauth_integrations', () {
      final json = {
        'merchant_id': 'M789',
        'payments_receivable': false,
        'primary_email_confirmed': false,
      };
      final status = PaypalSellerStatus.fromJson(json);
      expect(status.oauthIntegrated, isFalse);
    });
  });

  group('PaypalPartnerReferral', () {
    test('fromJson parses actionUrl from links', () {
      final json = {
        'partner_client_id': 'PARTNER123',
        'referral_id': 'REF456',
        'links': [
          {'rel': 'action_url', 'href': 'https://paypal.com/onboard?token=abc'},
        ],
      };

      final referral = PaypalPartnerReferral.fromJson(json);
      expect(referral.partnerId, 'PARTNER123');
      expect(referral.referralId, 'REF456');
      expect(referral.actionUrl, 'https://paypal.com/onboard?token=abc');
    });

    test('fromJson handles missing action_url link gracefully', () {
      final json = {'partner_client_id': 'P1', 'links': <dynamic>[]};
      final referral = PaypalPartnerReferral.fromJson(json);
      expect(referral.actionUrl, isEmpty);
    });
  });
}
