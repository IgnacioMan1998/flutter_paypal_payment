import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

void main() {
  // ═══════════════════════════════════════════════════════
  // PaypalSubscriptionAnalytics
  // ═══════════════════════════════════════════════════════

  group('PaypalSubscriptionAnalytics', () {
    // ── Helpers ──────────────────────────────────────────

    Map<String, dynamic> _sub({
      required String status,
      required double lastPaymentValue,
      String currency = 'USD',
      String intervalUnit = 'MONTH',
      int intervalCount = 1,
    }) {
      return {
        'status': status,
        'billing_info': {
          'last_payment': {
            'amount': {
              'value': lastPaymentValue.toStringAsFixed(2),
              'currency_code': currency,
            },
          },
        },
        'billing_cycles': [
          {
            'tenure_type': 'REGULAR',
            'frequency': {
              'interval_unit': intervalUnit,
              'interval_count': intervalCount,
            },
          },
        ],
      };
    }

    // ── getMRR ───────────────────────────────────────────

    group('getMRR()', () {
      test('returns 0 for empty list', () {
        expect(PaypalSubscriptionAnalytics.getMRR([]), 0.0);
      });

      test('sums only ACTIVE subscriptions', () {
        final subs = [
          _sub(status: 'ACTIVE', lastPaymentValue: 10.00),
          _sub(status: 'ACTIVE', lastPaymentValue: 20.00),
          _sub(status: 'CANCELLED', lastPaymentValue: 30.00),
          _sub(status: 'SUSPENDED', lastPaymentValue: 40.00),
        ];
        expect(PaypalSubscriptionAnalytics.getMRR(subs), closeTo(30.0, 0.001));
      });

      test('normalises annual plans to monthly', () {
        final subs = [
          _sub(
            status: 'ACTIVE',
            lastPaymentValue: 120.00,
            intervalUnit: 'YEAR',
            intervalCount: 1,
          ),
        ];
        expect(PaypalSubscriptionAnalytics.getMRR(subs), closeTo(10.0, 0.001));
      });

      test('normalises biannual plans', () {
        final subs = [
          _sub(
            status: 'ACTIVE',
            lastPaymentValue: 240.00,
            intervalUnit: 'YEAR',
            intervalCount: 2,
          ),
        ];
        expect(PaypalSubscriptionAnalytics.getMRR(subs), closeTo(10.0, 0.001));
      });

      test('normalises weekly plans', () {
        // Weekly plan billing $40/week ≈ $40 / 4.345 per month
        final subs = [
          _sub(
            status: 'ACTIVE',
            lastPaymentValue: 40.00,
            intervalUnit: 'WEEK',
            intervalCount: 1,
          ),
        ];
        final expected = 40.0 / 4.345;
        expect(
            PaypalSubscriptionAnalytics.getMRR(subs), closeTo(expected, 0.01));
      });

      test('normalises daily plans', () {
        // 30-day plan charging $30 every 30 days ≈ $1/month
        final subs = [
          _sub(
            status: 'ACTIVE',
            lastPaymentValue: 30.00,
            intervalUnit: 'DAY',
            intervalCount: 30,
          ),
        ];
        final expected = 30.0 / (30.4375 * 30);
        expect(
            PaypalSubscriptionAnalytics.getMRR(subs), closeTo(expected, 0.01));
      });

      test('bi-monthly plan is halved', () {
        final subs = [
          _sub(
            status: 'ACTIVE',
            lastPaymentValue: 20.00,
            intervalUnit: 'MONTH',
            intervalCount: 2,
          ),
        ];
        expect(PaypalSubscriptionAnalytics.getMRR(subs), closeTo(10.0, 0.001));
      });
    });

    // ── getARR ───────────────────────────────────────────

    group('getARR()', () {
      test('equals getMRR × 12', () {
        final subs = [
          _sub(status: 'ACTIVE', lastPaymentValue: 10.00),
        ];
        final mrr = PaypalSubscriptionAnalytics.getMRR(subs);
        expect(
          PaypalSubscriptionAnalytics.getARR(subs),
          closeTo(mrr * 12, 0.001),
        );
      });
    });

    // ── getARPU ──────────────────────────────────────────

    group('getARPU()', () {
      test('returns 0 when no active subscriptions', () {
        final subs = [
          _sub(status: 'CANCELLED', lastPaymentValue: 10.00),
        ];
        expect(PaypalSubscriptionAnalytics.getARPU(subs), 0.0);
      });

      test('divides MRR by active count', () {
        final subs = [
          _sub(status: 'ACTIVE', lastPaymentValue: 30.00),
          _sub(status: 'ACTIVE', lastPaymentValue: 30.00),
          _sub(status: 'CANCELLED', lastPaymentValue: 100.00),
        ];
        // MRR = 60, active = 2 → ARPU = 30
        expect(
          PaypalSubscriptionAnalytics.getARPU(subs),
          closeTo(30.0, 0.001),
        );
      });
    });

    // ── getChurnRate ─────────────────────────────────────

    group('getChurnRate()', () {
      test('returns 0 for empty list', () {
        expect(PaypalSubscriptionAnalytics.getChurnRate([]), 0.0);
      });

      test('calculates correctly from subscription list', () {
        final subs = [
          _sub(status: 'ACTIVE', lastPaymentValue: 10),
          _sub(status: 'ACTIVE', lastPaymentValue: 10),
          _sub(status: 'CANCELLED', lastPaymentValue: 10),
          _sub(status: 'CANCELLED', lastPaymentValue: 10),
        ];
        expect(
          PaypalSubscriptionAnalytics.getChurnRate(subs),
          closeTo(0.5, 0.001),
        );
      });

      test('accepts manual cancelled/total counts', () {
        expect(
          PaypalSubscriptionAnalytics.getChurnRate(
            [],
            cancelledCount: 1,
            totalCount: 4,
          ),
          closeTo(0.25, 0.001),
        );
      });

      test('returns 0 when all are active', () {
        final subs = [
          _sub(status: 'ACTIVE', lastPaymentValue: 10),
          _sub(status: 'ACTIVE', lastPaymentValue: 10),
        ];
        expect(PaypalSubscriptionAnalytics.getChurnRate(subs), 0.0);
      });
    });

    // ── countByStatus ────────────────────────────────────

    group('countByStatus()', () {
      test('counts each status correctly', () {
        final subs = [
          _sub(status: 'ACTIVE', lastPaymentValue: 1),
          _sub(status: 'ACTIVE', lastPaymentValue: 1),
          _sub(status: 'CANCELLED', lastPaymentValue: 1),
          _sub(status: 'SUSPENDED', lastPaymentValue: 1),
        ];
        final counts = PaypalSubscriptionAnalytics.countByStatus(subs);
        expect(counts['ACTIVE'], 2);
        expect(counts['CANCELLED'], 1);
        expect(counts['SUSPENDED'], 1);
      });

      test('returns empty map for empty list', () {
        expect(PaypalSubscriptionAnalytics.countByStatus([]), isEmpty);
      });
    });

    // ── revenueReport ────────────────────────────────────

    group('revenueReport()', () {
      test('produces correct SubscriptionRevenueReport', () {
        final subs = [
          _sub(status: 'ACTIVE', lastPaymentValue: 10.00),
          _sub(status: 'ACTIVE', lastPaymentValue: 10.00),
          _sub(status: 'CANCELLED', lastPaymentValue: 5.00),
        ];

        final report = PaypalSubscriptionAnalytics.revenueReport(subs);

        expect(report.mrr, closeTo(20.0, 0.001));
        expect(report.arr, closeTo(240.0, 0.001));
        expect(report.arpu, closeTo(10.0, 0.001));
        expect(report.churnRate, closeTo(1 / 3, 0.001));
        expect(report.activeSubscriptions, 2);
        expect(report.cancelledSubscriptions, 1);
        expect(report.totalSubscriptions, 3);
        expect(report.statusBreakdown['ACTIVE'], 2);
        expect(report.statusBreakdown['CANCELLED'], 1);
      });

      test('toString() includes key metrics', () {
        final report = PaypalSubscriptionAnalytics.revenueReport([
          _sub(status: 'ACTIVE', lastPaymentValue: 10),
        ]);
        final str = report.toString();
        expect(str, contains('mrr'));
        expect(str, contains('arr'));
        expect(str, contains('active'));
      });
    });
  });
}
