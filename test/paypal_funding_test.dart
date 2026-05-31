import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

void main() {
  group('FundingEligibilityResult', () {
    test('all eligible', () {
      const result = FundingEligibilityResult(
        paypalEligible: true,
        payLaterEligible: true,
        venmoEligible: true,
        creditEligible: true,
        debitEligible: true,
      );
      expect(result.hasAnyEligibleSource, isTrue);
      expect(result.eligibleSources.length, 5);
    });

    test('none eligible', () {
      const result = FundingEligibilityResult(
        paypalEligible: false,
        payLaterEligible: false,
        venmoEligible: false,
        creditEligible: false,
        debitEligible: false,
      );
      expect(result.hasAnyEligibleSource, isFalse);
      expect(result.eligibleSources, isEmpty);
    });

    test('eligibleSources returns typed sources', () {
      const result = FundingEligibilityResult(
        paypalEligible: true,
        payLaterEligible: true,
        venmoEligible: false,
        creditEligible: false,
        debitEligible: true,
      );
      final sources = result.eligibleSources;
      expect(sources, contains(PaypalFundingSource.paypal));
      expect(sources, contains(PaypalFundingSource.payLater));
      expect(sources, contains(PaypalFundingSource.debit));
      expect(sources, isNot(contains(PaypalFundingSource.venmo)));
      expect(sources, isNot(contains(PaypalFundingSource.credit)));
    });

    test('isEligible returns correct value', () {
      const result = FundingEligibilityResult(
        paypalEligible: true,
        payLaterEligible: false,
        venmoEligible: true,
        creditEligible: false,
        debitEligible: true,
      );
      expect(result.isEligible(PaypalFundingSource.paypal), isTrue);
      expect(result.isEligible(PaypalFundingSource.payLater), isFalse);
      expect(result.isEligible(PaypalFundingSource.venmo), isTrue);
      expect(result.isEligible(PaypalFundingSource.credit), isFalse);
      expect(result.isEligible(PaypalFundingSource.debit), isTrue);
    });

    test('toString includes field names', () {
      const result = FundingEligibilityResult(
        paypalEligible: true,
        payLaterEligible: false,
        venmoEligible: false,
        creditEligible: false,
        debitEligible: false,
      );
      expect(result.toString(), contains('paypal'));
    });
  });

  group('PaypalFundingEligibility cache', () {
    setUp(() => PaypalFundingEligibility.clearCache());
    tearDown(() => PaypalFundingEligibility.clearCache());

    test('clearCache does not throw', () {
      expect(() => PaypalFundingEligibility.clearCache(), returnsNormally);
    });

    test('getCachedSources returns null when cache is empty', () {
      final cached = PaypalFundingEligibility.getCachedSources(
        clientId: 'id',
        currencyCode: 'USD',
      );
      expect(cached, isNull);
    });

    test('cacheDuration is positive', () {
      expect(PaypalFundingEligibility.cacheDuration.inSeconds, greaterThan(0));
    });
  });
}
