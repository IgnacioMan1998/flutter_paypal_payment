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

      expect(result.paypalEligible, isTrue);
      expect(result.payLaterEligible, isTrue);
      expect(result.venmoEligible, isTrue);
      expect(result.creditEligible, isTrue);
      expect(result.debitEligible, isTrue);
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

    test('eligibleSources returns all eligible source names', () {
      const result = FundingEligibilityResult(
        paypalEligible: true,
        payLaterEligible: true,
        venmoEligible: false,
        creditEligible: false,
        debitEligible: true,
      );

      final sources = result.eligibleSources;
      expect(sources, containsAll(['paypal', 'paylater', 'debit']));
      expect(sources, isNot(contains('venmo')));
      expect(sources, isNot(contains('credit')));
    });

    test('hasAnyEligibleSource true when at least one eligible', () {
      const result = FundingEligibilityResult(
        paypalEligible: false,
        payLaterEligible: false,
        venmoEligible: true,
        creditEligible: false,
        debitEligible: false,
      );

      expect(result.hasAnyEligibleSource, isTrue);
    });

    test('isEligible returns correct value for each source', () {
      const result = FundingEligibilityResult(
        paypalEligible: true,
        payLaterEligible: false,
        venmoEligible: true,
        creditEligible: false,
        debitEligible: true,
      );

      expect(result.isEligible('paypal'), isTrue);
      expect(result.isEligible('paylater'), isFalse);
      expect(result.isEligible('venmo'), isTrue);
      expect(result.isEligible('credit'), isFalse);
      expect(result.isEligible('debit'), isTrue);
      expect(result.isEligible('unknown'), isFalse);
    });

    test('eligibleSources length matches eligible count', () {
      const result = FundingEligibilityResult(
        paypalEligible: true,
        payLaterEligible: true,
        venmoEligible: true,
        creditEligible: false,
        debitEligible: false,
      );

      expect(result.eligibleSources.length, 3);
    });

    test('default values are all false', () {
      const result = FundingEligibilityResult();
      expect(result.hasAnyEligibleSource, isFalse);
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
        environment: PaypalEnvironment.sandbox,
        currencyCode: 'USD',
      );
      expect(cached, isNull);
    });

    test('cacheDuration is positive', () {
      expect(PaypalFundingEligibility.cacheDuration.inSeconds, greaterThan(0));
    });
  });
}
