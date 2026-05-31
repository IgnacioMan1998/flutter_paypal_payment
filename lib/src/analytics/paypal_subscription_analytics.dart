/// Analytics helpers for PayPal subscription data.
///
/// These utilities compute standard SaaS metrics from subscription
/// and transaction payloads returned by [PaypalSubscriptionService].
///
/// All monetary amounts are returned as `double` in the currency of the input.
///
/// ## Example
/// ```dart
/// final service = PaypalSubscriptionService(config: cfg, clientSecret: secret);
/// final result = await service.listSubscriptions(planId: 'P-XXX');
/// result.fold(
///   (f) => print('Error: ${f.message}'),
///   (data) {
///     final subs = (data['subscriptions'] as List).cast<Map<String, dynamic>>();
///     print('MRR: \$${PaypalSubscriptionAnalytics.getMRR(subs).toStringAsFixed(2)}');
///     print('ARR: \$${PaypalSubscriptionAnalytics.getARR(subs).toStringAsFixed(2)}');
///   },
/// );
/// ```
abstract final class PaypalSubscriptionAnalytics {
  // ── Revenue metrics ───────────────────────────────────────

  /// Monthly Recurring Revenue — the normalised monthly amount billed across
  /// all **ACTIVE** subscriptions.
  ///
  /// Billing-cycle normalization rules:
  /// - DAY × `count` → monthly equivalent (count / 30.44)
  /// - WEEK × `count` → monthly equivalent (count / 4.345)
  /// - MONTH × `count` → monthly equivalent (1 / count)
  /// - YEAR × `count` → monthly equivalent (1 / (count * 12))
  ///
  /// The [subscriptions] list must be the raw JSON objects returned by
  /// the PayPal Subscriptions REST API.
  static double getMRR(List<Map<String, dynamic>> subscriptions) {
    double total = 0.0;
    for (final sub in subscriptions) {
      if (_status(sub) != 'ACTIVE') continue;
      total += _monthlyValue(sub);
    }
    return total;
  }

  /// Annual Recurring Revenue — [getMRR] × 12.
  static double getARR(List<Map<String, dynamic>> subscriptions) =>
      getMRR(subscriptions) * 12;

  /// Average Revenue Per User across active subscriptions.
  static double getARPU(List<Map<String, dynamic>> subscriptions) {
    final active =
        subscriptions.where((s) => _status(s) == 'ACTIVE').toList();
    if (active.isEmpty) return 0.0;
    return getMRR(subscriptions) / active.length;
  }

  // ── Churn metrics ─────────────────────────────────────────

  /// Customer churn rate as a value between 0.0 and 1.0.
  ///
  /// `churnRate = cancelledCount / (cancelledCount + activeCount)`
  ///
  /// Pass the raw subscription list to derive counts automatically, or
  /// supply pre-counted values via [cancelledCount] and [totalCount].
  static double getChurnRate(
    List<Map<String, dynamic>> subscriptions, {
    int? cancelledCount,
    int? totalCount,
  }) {
    final cancelled = cancelledCount ??
        subscriptions
            .where((s) => _status(s) == 'CANCELLED')
            .length;
    final total = totalCount ?? subscriptions.length;
    if (total == 0) return 0.0;
    return cancelled / total;
  }

  // ── Aggregates ────────────────────────────────────────────

  /// Count subscriptions by status.
  ///
  /// Returns a map of `status → count` for all subscriptions in the list.
  static Map<String, int> countByStatus(
      List<Map<String, dynamic>> subscriptions) {
    final counts = <String, int>{};
    for (final sub in subscriptions) {
      final s = _status(sub);
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  /// Revenue report summarising key metrics in a single call.
  ///
  /// Returns a strongly-typed [SubscriptionRevenueReport].
  static SubscriptionRevenueReport revenueReport(
      List<Map<String, dynamic>> subscriptions) {
    final byStatus = countByStatus(subscriptions);
    final activeCount = byStatus['ACTIVE'] ?? 0;
    final cancelledCount = byStatus['CANCELLED'] ?? 0;
    final mrr = getMRR(subscriptions);

    return SubscriptionRevenueReport(
      mrr: mrr,
      arr: mrr * 12,
      arpu: activeCount > 0 ? mrr / activeCount : 0.0,
      churnRate: getChurnRate(subscriptions,
          cancelledCount: cancelledCount,
          totalCount: subscriptions.length),
      activeSubscriptions: activeCount,
      cancelledSubscriptions: cancelledCount,
      totalSubscriptions: subscriptions.length,
      statusBreakdown: byStatus,
    );
  }

  // ── Internal helpers ──────────────────────────────────────

  static String _status(Map<String, dynamic> sub) =>
      (sub['status'] as String? ?? '').toUpperCase();

  /// Extract the monthly-normalised billing value from a subscription.
  static double _monthlyValue(Map<String, dynamic> sub) {
    // Navigate: billing_info → last_payment → amount → value
    final billingInfo = sub['billing_info'] as Map<String, dynamic>?;
    final lastPayment =
        billingInfo?['last_payment'] as Map<String, dynamic>?;
    final amount = lastPayment?['amount'] as Map<String, dynamic>?;
    final valueStr = amount?['value'] as String?;
    final value = double.tryParse(valueStr ?? '') ?? 0.0;
    if (value == 0.0) return 0.0;

    // Determine billing frequency from plan_overridden_data or plan billing_cycles
    // Fallback: treat as monthly if not parseable.
    final overridden =
        sub['plan_overridden'] as Map<String, dynamic>?;
    final billingCycles =
        (overridden?['billing_cycles'] as List<dynamic>?) ??
            (sub['billing_cycles'] as List<dynamic>?) ??
            [];

    if (billingCycles.isEmpty) return value; // assume monthly

    // Find the REGULAR cycle (tenure_type == REGULAR)
    final regular = billingCycles
        .whereType<Map<String, dynamic>>()
        .firstWhere(
          (c) =>
              (c['tenure_type'] as String? ?? '').toUpperCase() == 'REGULAR',
          orElse: () => billingCycles.first as Map<String, dynamic>,
        );

    final frequency =
        regular['frequency'] as Map<String, dynamic>? ?? {};
    final unit =
        (frequency['interval_unit'] as String? ?? 'MONTH').toUpperCase();
    final count = (frequency['interval_count'] as num?)?.toInt() ?? 1;

    return switch (unit) {
      'DAY' => value / (30.4375 * count),
      'WEEK' => value / (4.345 * count),
      'MONTH' => value / count,
      'YEAR' => value / (count * 12),
      _ => value,
    };
  }
}

/// Immutable summary of subscription revenue metrics.
class SubscriptionRevenueReport {
  const SubscriptionRevenueReport({
    required this.mrr,
    required this.arr,
    required this.arpu,
    required this.churnRate,
    required this.activeSubscriptions,
    required this.cancelledSubscriptions,
    required this.totalSubscriptions,
    required this.statusBreakdown,
  });

  /// Monthly Recurring Revenue.
  final double mrr;

  /// Annual Recurring Revenue.
  final double arr;

  /// Average Revenue Per User.
  final double arpu;

  /// Customer churn rate (0.0 – 1.0).
  final double churnRate;

  /// Number of ACTIVE subscriptions.
  final int activeSubscriptions;

  /// Number of CANCELLED subscriptions.
  final int cancelledSubscriptions;

  /// Total subscriptions in the dataset.
  final int totalSubscriptions;

  /// Count per status string (e.g. `{'ACTIVE': 10, 'CANCELLED': 2}`).
  final Map<String, int> statusBreakdown;

  @override
  String toString() =>
      'SubscriptionRevenueReport(mrr: $mrr, arr: $arr, arpu: $arpu, '
      'churnRate: ${(churnRate * 100).toStringAsFixed(1)}%, '
      'active: $activeSubscriptions, total: $totalSubscriptions)';
}
