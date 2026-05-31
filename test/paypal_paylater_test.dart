import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

void main() {
  group('PayLaterOffer', () {
    const testAmount = '500.00';
    const testCurrency = 'USD';

    test('fromJson parses correctly', () {
      final json = {
        'financing_options': [
          {
            'qualifying_financing_options': [
              {
                'monthly_payment': {'value': '50.00', 'currency_code': 'USD'},
                'credit_type': 'PAYPAL_CREDIT_INSTALLMENTS',
                'pay_in_x_options': {'number_of_installments': 12},
              }
            ]
          }
        ]
      };

      final offer = PayLaterOffer.fromJson(json, testAmount, testCurrency);
      expect(offer.amount, testAmount);
      expect(offer.currencyCode, testCurrency);
      expect(offer.monthlyAmount, '50.00');
    });

    test('fromJson returns default PAY_IN_4 on empty financing_options', () {
      final json = {'financing_options': <dynamic>[]};
      final offer = PayLaterOffer.fromJson(json, testAmount, testCurrency);
      expect(offer.installments, 4);
      expect(offer.offerType, 'PAY_IN_4');
    });

    test('fromJson returns default PAY_IN_4 on missing key', () {
      final offer = PayLaterOffer.fromJson({}, testAmount, testCurrency);
      expect(offer.installments, 4);
    });

    test('summary contains amount and installments', () {
      const offer = PayLaterOffer(
        amount: '500.00',
        monthlyAmount: '45.83',
        installments: 12,
        currencyCode: 'USD',
        offerType: 'PAYPAL_CREDIT_INSTALLMENTS',
      );

      expect(offer.summary, contains('12'));
      expect(offer.summary, contains('45.83'));
    });

    test('formattedMonthly includes amount', () {
      const offer = PayLaterOffer(
        amount: '100.00',
        monthlyAmount: '10.00',
        installments: 10,
        currencyCode: 'USD',
      );

      expect(offer.formattedMonthly, contains('10.00'));
    });

    test('disclosure defaults to empty string', () {
      const offer = PayLaterOffer(
        amount: '100.00',
        monthlyAmount: '10.00',
        installments: 10,
        currencyCode: 'USD',
      );

      expect(offer.disclosure, '');
    });

    test('rawResponse stored correctly', () {
      final raw = {'key': 'value'};
      final offer = PayLaterOffer(
        amount: '100.00',
        monthlyAmount: '10.00',
        installments: 10,
        currencyCode: 'USD',
        rawResponse: raw,
      );

      expect(offer.rawResponse, equals(raw));
    });
  });

  group('PayLaterOfferService cache', () {
    setUp(() => PayLaterOfferService.clearCache());
    tearDown(() => PayLaterOfferService.clearCache());

    test('clearCache does not throw', () {
      expect(() => PayLaterOfferService.clearCache(), returnsNormally);
    });

    test('cacheDuration is positive', () {
      expect(PayLaterOfferService.cacheDuration.inSeconds, greaterThan(0));
    });
  });
}
