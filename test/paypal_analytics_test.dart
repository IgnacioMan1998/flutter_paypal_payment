import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

void main() {
  // ═══════════════════════════════════════════════════════
  // PaypalSubscriptionAnalytics
  // ═══════════════════════════════════════════════════════

  group('PaypalSubscriptionAnalytics', () {
    // ── Helpers ──────────────────────────────────────────

    Map<String, dynamic> sub0({
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
          sub0(status: 'ACTIVE', lastPaymentValue: 10.00),
          sub0(status: 'ACTIVE', lastPaymentValue: 20.00),
          sub0(status: 'CANCELLED', lastPaymentValue: 30.00),
          sub0(status: 'SUSPENDED', lastPaymentValue: 40.00),
        ];
        expect(PaypalSubscriptionAnalytics.getMRR(subs), closeTo(30.0, 0.001));
      });

      test('normalises annual plans to monthly', () {
        final subs = [
          sub0(
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
          sub0(
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
          sub0(
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
          sub0(
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
          sub0(
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
          sub0(status: 'ACTIVE', lastPaymentValue: 10.00),
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
          sub0(status: 'CANCELLED', lastPaymentValue: 10.00),
        ];
        expect(PaypalSubscriptionAnalytics.getARPU(subs), 0.0);
      });

      test('divides MRR by active count', () {
        final subs = [
          sub0(status: 'ACTIVE', lastPaymentValue: 30.00),
          sub0(status: 'ACTIVE', lastPaymentValue: 30.00),
          sub0(status: 'CANCELLED', lastPaymentValue: 100.00),
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
          sub0(status: 'ACTIVE', lastPaymentValue: 10),
          sub0(status: 'ACTIVE', lastPaymentValue: 10),
          sub0(status: 'CANCELLED', lastPaymentValue: 10),
          sub0(status: 'CANCELLED', lastPaymentValue: 10),
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
          sub0(status: 'ACTIVE', lastPaymentValue: 10),
          sub0(status: 'ACTIVE', lastPaymentValue: 10),
        ];
        expect(PaypalSubscriptionAnalytics.getChurnRate(subs), 0.0);
      });
    });

    // ── countByStatus ────────────────────────────────────

    group('countByStatus()', () {
      test('counts each status correctly', () {
        final subs = [
          sub0(status: 'ACTIVE', lastPaymentValue: 1),
          sub0(status: 'ACTIVE', lastPaymentValue: 1),
          sub0(status: 'CANCELLED', lastPaymentValue: 1),
          sub0(status: 'SUSPENDED', lastPaymentValue: 1),
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
          sub0(status: 'ACTIVE', lastPaymentValue: 10.00),
          sub0(status: 'ACTIVE', lastPaymentValue: 10.00),
          sub0(status: 'CANCELLED', lastPaymentValue: 5.00),
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
          sub0(status: 'ACTIVE', lastPaymentValue: 10),
        ]);
        final str = report.toString();
        expect(str, contains('mrr'));
        expect(str, contains('arr'));
        expect(str, contains('active'));
      });
    });

    // ── revenueByPlan ─────────────────────────────────────

    group('revenueByPlan()', () {
      Map<String, dynamic> subWithPlan({
        required String status,
        required double lastPaymentValue,
        required String planId,
        String intervalUnit = 'MONTH',
        int intervalCount = 1,
      }) {
        final base = {
          'status': status,
          'plan': {'id': planId},
          'billing_info': {
            'last_payment': {
              'amount': {
                'value': lastPaymentValue.toStringAsFixed(2),
                'currency_code': 'USD',
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
        return base;
      }

      test('groups MRR by plan ID for active subs', () {
        final subs = [
          subWithPlan(status: 'ACTIVE', lastPaymentValue: 10, planId: 'P-A'),
          subWithPlan(status: 'ACTIVE', lastPaymentValue: 20, planId: 'P-A'),
          subWithPlan(status: 'ACTIVE', lastPaymentValue: 15, planId: 'P-B'),
          subWithPlan(status: 'CANCELLED', lastPaymentValue: 10, planId: 'P-A'),
        ];

        final result = PaypalSubscriptionAnalytics.revenueByPlan(subs);
        expect(result['P-A'], closeTo(30.0, 0.01));
        expect(result['P-B'], closeTo(15.0, 0.01));
        expect(result.containsKey('CANCELLED'), isFalse);
      });

      test('returns empty map for no active subs', () {
        final subs = [
          subWithPlan(status: 'CANCELLED', lastPaymentValue: 10, planId: 'P-A'),
        ];

        expect(PaypalSubscriptionAnalytics.revenueByPlan(subs), isEmpty);
      });

      test('sorted by MRR descending', () {
        final subs = [
          subWithPlan(status: 'ACTIVE', lastPaymentValue: 5, planId: 'P-LOW'),
          subWithPlan(status: 'ACTIVE', lastPaymentValue: 100, planId: 'P-HIGH'),
        ];

        final result = PaypalSubscriptionAnalytics.revenueByPlan(subs);
        final keys = result.keys.toList();
        expect(keys.first, 'P-HIGH');
        expect(keys.last, 'P-LOW');
      });

      test('handles unknown plan_id gracefully', () {
        final sub = {
          'status': 'ACTIVE',
          'billing_info': {
            'last_payment': {
              'amount': {'value': '10.00', 'currency_code': 'USD'},
            },
          },
          'billing_cycles': [
            {
              'tenure_type': 'REGULAR',
              'frequency': {'interval_unit': 'MONTH', 'interval_count': 1},
            },
          ],
        };

        final result = PaypalSubscriptionAnalytics.revenueByPlan([sub]);
        expect(result.containsKey('unknown'), isTrue);
      });
    });

    // ── revenueByMonth ────────────────────────────────────

    group('revenueByMonth()', () {
      Map<String, dynamic> subWithTime({
        required String status,
        required double lastPaymentValue,
        required String lastPaymentTime,
        String intervalUnit = 'MONTH',
        int intervalCount = 1,
      }) {
        return {
          'status': status,
          'billing_info': {
            'last_payment': {
              'amount': {
                'value': lastPaymentValue.toStringAsFixed(2),
                'currency_code': 'USD',
              },
              'time': lastPaymentTime,
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

      test('groups MRR by YYYY-MM for active subs', () {
        final subs = [
          subWithTime(status: 'ACTIVE', lastPaymentValue: 10, lastPaymentTime: '2025-01-15T10:00:00Z'),
          subWithTime(status: 'ACTIVE', lastPaymentValue: 20, lastPaymentTime: '2025-01-20T10:00:00Z'),
          subWithTime(status: 'ACTIVE', lastPaymentValue: 15, lastPaymentTime: '2025-02-05T10:00:00Z'),
        ];

        final result = PaypalSubscriptionAnalytics.revenueByMonth(subs);
        expect(result['2025-01'], closeTo(30.0, 0.01));
        expect(result['2025-02'], closeTo(15.0, 0.01));
      });

      test('ignores cancelled subs', () {
        final subs = [
          subWithTime(status: 'CANCELLED', lastPaymentValue: 10, lastPaymentTime: '2025-01-15T10:00:00Z'),
        ];

        expect(PaypalSubscriptionAnalytics.revenueByMonth(subs), isEmpty);
      });

      test('ignores subs without last payment time', () {
        final sub = {
          'status': 'ACTIVE',
          'billing_info': {
            'last_payment': {
              'amount': {'value': '10.00', 'currency_code': 'USD'},
              // no 'time' key
            },
          },
          'billing_cycles': [
            {
              'tenure_type': 'REGULAR',
              'frequency': {'interval_unit': 'MONTH', 'interval_count': 1},
            },
          ],
        };

        expect(PaypalSubscriptionAnalytics.revenueByMonth([sub]), isEmpty);
      });

      test('returns months sorted ascending', () {
        final subs = [
          subWithTime(status: 'ACTIVE', lastPaymentValue: 10, lastPaymentTime: '2025-03-01T00:00:00Z'),
          subWithTime(status: 'ACTIVE', lastPaymentValue: 10, lastPaymentTime: '2025-01-01T00:00:00Z'),
          subWithTime(status: 'ACTIVE', lastPaymentValue: 10, lastPaymentTime: '2025-02-01T00:00:00Z'),
        ];

        final keys = PaypalSubscriptionAnalytics.revenueByMonth(subs).keys.toList();
        expect(keys, ['2025-01', '2025-02', '2025-03']);
      });
    });

    // ── revenueTrend ──────────────────────────────────────

    group('revenueTrend()', () {
      Map<String, dynamic> subWithTime(String time, double value) => {
        'status': 'ACTIVE',
        'billing_info': {
          'last_payment': {
            'amount': {'value': value.toStringAsFixed(2), 'currency_code': 'USD'},
            'time': time,
          },
        },
        'billing_cycles': [
          {
            'tenure_type': 'REGULAR',
            'frequency': {'interval_unit': 'MONTH', 'interval_count': 1},
          },
        ],
      };

      test('first month has null growthPercent', () {
        final subs = [subWithTime('2025-01-01T00:00:00Z', 100)];
        final trend = PaypalSubscriptionAnalytics.revenueTrend(subs);
        expect(trend.first.growthPercent, isNull);
      });

      test('positive growth detected', () {
        final subs = [
          subWithTime('2025-01-01T00:00:00Z', 100),
          subWithTime('2025-02-01T00:00:00Z', 120),
        ];
        final trend = PaypalSubscriptionAnalytics.revenueTrend(subs);
        expect(trend[1].isGrowth, isTrue);
        expect(trend[1].growthPercent, closeTo(20.0, 0.01));
      });

      test('negative growth (decline) detected', () {
        final subs = [
          subWithTime('2025-01-01T00:00:00Z', 100),
          subWithTime('2025-02-01T00:00:00Z', 80),
        ];
        final trend = PaypalSubscriptionAnalytics.revenueTrend(subs);
        expect(trend[1].isDecline, isTrue);
        expect(trend[1].growthPercent, closeTo(-20.0, 0.01));
      });

      test('returns empty list when no data', () {
        expect(PaypalSubscriptionAnalytics.revenueTrend([]), isEmpty);
      });

      test('MonthlyRevenueTrend toString includes month and mrr', () {
        const t = MonthlyRevenueTrend(month: '2025-01', mrr: 100.0);
        expect(t.toString(), contains('2025-01'));
        expect(t.toString(), contains('100.0'));
      });
    });
  });
}
