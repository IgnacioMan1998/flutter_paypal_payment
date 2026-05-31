import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════
// PaypalSubscriptionWidget
// ═══════════════════════════════════════════════════════════

/// Status badge color mapping.
const _kStatusColors = {
  'ACTIVE': Color(0xFF2E7D32),
  'SUSPENDED': Color(0xFFF57F17),
  'CANCELLED': Color(0xFFC62828),
  'EXPIRED': Color(0xFF616161),
  'APPROVAL_PENDING': Color(0xFF1565C0),
};

/// A widget that displays a PayPal subscription with plan info, status badge,
/// billing details, and management actions.
///
/// ## Usage
/// ```dart
/// PaypalSubscriptionWidget(
///   subscriptionData: subscriptionMap, // raw PayPal API response
///   onCancel: () async => await paypal.cancelSubscription(...),
///   onSuspend: () async => await paypal.suspendSubscription(...),
///   onActivate: () async => await paypal.activateSubscription(...),
/// )
/// ```
///
/// [subscriptionData] is the raw `Map<String, dynamic>` returned by
/// `PaypalSubscriptionService.getSubscriptionDetails()` or
/// `PaypalSubscriptionService.listSubscriptions()`.
class PaypalSubscriptionWidget extends StatelessWidget {
  const PaypalSubscriptionWidget({
    super.key,
    required this.subscriptionData,
    this.onCancel,
    this.onSuspend,
    this.onActivate,
    this.onTap,
    this.showActions = true,
    this.backgroundColor,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.all(16),
  });

  /// Raw subscription map from the PayPal Subscriptions REST API.
  final Map<String, dynamic> subscriptionData;

  /// Called when the user taps "Cancel subscription".
  /// Return `true` to confirm the action, `false` to abort UI update.
  final Future<bool> Function()? onCancel;

  /// Called when the user taps "Suspend subscription".
  final Future<bool> Function()? onSuspend;

  /// Called when the user taps "Reactivate subscription".
  final Future<bool> Function()? onActivate;

  /// Called when the card itself is tapped.
  final VoidCallback? onTap;

  /// Whether to show Cancel / Suspend / Reactivate action buttons.
  final bool showActions;

  /// Card background color. Defaults to the theme surface color.
  final Color? backgroundColor;

  /// Card border radius.
  final double borderRadius;

  /// Internal padding.
  final EdgeInsets padding;

  // ── Computed getters ──────────────────────────────────────

  String get _id => subscriptionData['id'] as String? ?? '—';

  String get _status =>
      (subscriptionData['status'] as String? ?? 'UNKNOWN').toUpperCase();

  String get _planId {
    final plan = subscriptionData['plan'] as Map<String, dynamic>?;
    return plan?['id'] as String? ??
        subscriptionData['plan_id'] as String? ??
        '—';
  }

  String get _planName {
    final plan = subscriptionData['plan'] as Map<String, dynamic>?;
    return plan?['name'] as String? ?? _planId;
  }

  String get _subscriberName {
    final sub = subscriptionData['subscriber'] as Map<String, dynamic>?;
    final name = sub?['name'] as Map<String, dynamic>?;
    final given = name?['given_name'] as String? ?? '';
    final surname = name?['surname'] as String? ?? '';
    return '$given $surname'.trim().isEmpty ? '—' : '$given $surname'.trim();
  }

  String get _subscriberEmail {
    final sub = subscriptionData['subscriber'] as Map<String, dynamic>?;
    return sub?['email_address'] as String? ?? '—';
  }

  String get _nextBillingTime {
    final billing =
        subscriptionData['billing_info'] as Map<String, dynamic>?;
    final raw = billing?['next_billing_time'] as String?;
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String get _lastPayment {
    final billing =
        subscriptionData['billing_info'] as Map<String, dynamic>?;
    final last =
        billing?['last_payment'] as Map<String, dynamic>?;
    final amount =
        last?['amount'] as Map<String, dynamic>?;
    if (amount == null) return '—';
    final value = amount['value'] as String? ?? '0';
    final currency = amount['currency_code'] as String? ?? '';
    return '$currency $value';
  }

  Color get _statusColor =>
      _kStatusColors[_status] ?? const Color(0xFF616161);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      color: backgroundColor ?? cs.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                planName: _planName,
                status: _status,
                statusColor: _statusColor,
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Subscription ID', value: _id),
              _InfoRow(label: 'Subscriber', value: _subscriberName),
              _InfoRow(label: 'Email', value: _subscriberEmail),
              _InfoRow(label: 'Next billing', value: _nextBillingTime),
              _InfoRow(label: 'Last payment', value: _lastPayment),
              if (showActions && _hasAnyAction) ...[
                const SizedBox(height: 16),
                _Actions(
                  status: _status,
                  onCancel: onCancel,
                  onSuspend: onSuspend,
                  onActivate: onActivate,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasAnyAction =>
      onCancel != null || onSuspend != null || onActivate != null;
}

// ── Sub-widgets ───────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.planName,
    required this.status,
    required this.statusColor,
  });
  final String planName;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            planName,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        _StatusBadge(status: status, color: statusColor),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatefulWidget {
  const _Actions({
    required this.status,
    this.onCancel,
    this.onSuspend,
    this.onActivate,
  });
  final String status;
  final Future<bool> Function()? onCancel;
  final Future<bool> Function()? onSuspend;
  final Future<bool> Function()? onActivate;

  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  bool _loading = false;

  Future<void> _invoke(Future<bool> Function() fn) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = widget.status == 'ACTIVE';
    final isSuspended = widget.status == 'SUSPENDED';
    final isCancellable = isActive || isSuspended;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isActive && widget.onSuspend != null)
          _ActionButton(
            label: 'Suspend',
            icon: Icons.pause_rounded,
            color: const Color(0xFFF57F17),
            loading: _loading,
            onTap: () => _invoke(widget.onSuspend!),
          ),
        if (isSuspended && widget.onActivate != null)
          _ActionButton(
            label: 'Reactivate',
            icon: Icons.play_arrow_rounded,
            color: cs.primary,
            loading: _loading,
            onTap: () => _invoke(widget.onActivate!),
          ),
        if (isCancellable && widget.onCancel != null)
          _ActionButton(
            label: 'Cancel',
            icon: Icons.cancel_outlined,
            color: const Color(0xFFC62828),
            loading: _loading,
            onTap: () => _invoke(widget.onCancel!),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: loading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: loading ? null : onTap,
    );
  }
}
