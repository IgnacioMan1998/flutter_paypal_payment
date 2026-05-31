import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../events/paypal_events.dart';

// ═══════════════════════════════════════════════════════════
// Debug event record
// ═══════════════════════════════════════════════════════════

/// A single entry in the [PaypalDebugOverlay] event history.
class PaypalDebugEvent {
  PaypalDebugEvent({
    required this.type,
    required this.summary,
    this.detail = '',
  }) : timestamp = DateTime.now();

  final String type;
  final String summary;
  final String detail;
  final DateTime timestamp;

  String get formattedTime {
    final t = timestamp;
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════
// Debug overlay controller
// ═══════════════════════════════════════════════════════════

/// Controller for the [PaypalDebugOverlay].
///
/// Add events manually or let [PaypalDebugOverlay] subscribe to the event bus.
class PaypalDebugController extends ChangeNotifier {
  final _events = <PaypalDebugEvent>[];

  /// Maximum events kept in history. Older entries are dropped. Default: 50.
  int maxEvents = 50;

  String _sdkStatus = 'NOT INITIALIZED';
  String _environment = '—';
  String _activeCheckout = '—';
  String _lastError = '—';

  /// SDK initialization status string.
  String get sdkStatus => _sdkStatus;

  /// Current environment label.
  String get environment => _environment;

  /// Order ID of the active checkout, or `'—'`.
  String get activeCheckout => _activeCheckout;

  /// Most recent error message, or `'—'`.
  String get lastError => _lastError;

  /// Ordered history (most recent first).
  List<PaypalDebugEvent> get events =>
      List.unmodifiable(_events.reversed.toList());

  /// Record that the SDK was initialized.
  void recordInit({required String env}) {
    _sdkStatus = 'INITIALIZED';
    _environment = env;
    _addEvent(
      type: 'INIT',
      summary: 'SDK initialized',
      detail: 'env: $env',
    );
  }

  /// Record a checkout event.
  void recordCheckoutEvent(Object event) {
    if (event is PaypalCheckoutStartedEvent) {
      _activeCheckout = event.orderId;
      _addEvent(
        type: 'CHECKOUT_STARTED',
        summary: 'Checkout started',
        detail: 'orderId: ${event.orderId}',
      );
    } else if (event is PaypalCheckoutCompletedEvent) {
      _activeCheckout = '—';
      _addEvent(
        type: 'CHECKOUT_OK',
        summary: 'Checkout completed',
        detail: 'orderId: ${event.result.orderId}',
      );
    } else if (event is PaypalCheckoutCancelledEvent) {
      _activeCheckout = '—';
      _addEvent(
        type: 'CHECKOUT_CANCELLED',
        summary: 'Checkout cancelled',
        detail: 'orderId: ${event.orderId}',
      );
    } else if (event is PaypalCheckoutFailedEvent) {
      _activeCheckout = '—';
      _lastError = event.failure.message;
      _addEvent(
        type: 'CHECKOUT_FAILED',
        summary: 'Checkout failed',
        detail: '${event.failure.code}: ${event.failure.message}',
      );
    }
  }

  /// Record any card / vault / subscription event.
  void recordEvent({
    required String type,
    required String summary,
    String detail = '',
    bool isError = false,
  }) {
    if (isError) _lastError = summary;
    _addEvent(type: type, summary: summary, detail: detail);
  }

  /// Clear event history.
  void clearEvents() {
    _events.clear();
    notifyListeners();
  }

  void _addEvent({
    required String type,
    required String summary,
    String detail = '',
  }) {
    _events.add(PaypalDebugEvent(type: type, summary: summary, detail: detail));
    if (_events.length > maxEvents) _events.removeAt(0);
    notifyListeners();
  }
}

// ═══════════════════════════════════════════════════════════
// PaypalDebugOverlay
// ═══════════════════════════════════════════════════════════

/// A floating debug overlay for PayPal SDK status and event history.
///
/// **Only renders in debug builds** (`kDebugMode`). In release builds this
/// widget collapses to an empty `SizedBox`.
///
/// ## Usage
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return PaypalDebugOverlay(
///     controller: _debugController,
///     child: Scaffold(...),
///   );
/// }
/// ```
///
/// Wire the controller to your [FlutterPaypalPayment] event bus:
/// ```dart
/// paypal.events.checkoutStarted.listen(_debugController.recordCheckoutEvent);
/// paypal.events.checkoutCompleted.listen(_debugController.recordCheckoutEvent);
/// paypal.events.checkoutFailed.listen(_debugController.recordCheckoutEvent);
/// ```
class PaypalDebugOverlay extends StatefulWidget {
  const PaypalDebugOverlay({
    super.key,
    required this.controller,
    required this.child,
    this.initiallyVisible = false,
    this.alignment = Alignment.bottomRight,
  });

  /// Controller holding SDK state and event history.
  final PaypalDebugController controller;

  /// The widget behind the overlay.
  final Widget child;

  /// Whether the panel starts expanded. Defaults to `false`.
  final bool initiallyVisible;

  /// Where to position the toggle button. Defaults to bottom-right.
  final Alignment alignment;

  @override
  State<PaypalDebugOverlay> createState() => _PaypalDebugOverlayState();
}

class _PaypalDebugOverlayState extends State<PaypalDebugOverlay> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _visible = widget.initiallyVisible;
  }

  @override
  Widget build(BuildContext context) {
    // No-op in release mode
    if (!kDebugMode) return widget.child;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Stack(
          children: [
            widget.child,
            // Toggle button
            Positioned(
              bottom: 24,
              right: 16,
              child: _ToggleFab(
                isOpen: _visible,
                onTap: () => setState(() => _visible = !_visible),
              ),
            ),
            // Overlay panel
            if (_visible)
              Positioned(
                bottom: 80,
                right: 8,
                left: 8,
                child: _DebugPanel(
                  controller: widget.controller,
                  onClose: () => setState(() => _visible = false),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────

class _ToggleFab extends StatelessWidget {
  const _ToggleFab({required this.isOpen, required this.onTap});
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isOpen ? 'Close PayPal debug panel' : 'Open PayPal debug panel',
      button: true,
      child: FloatingActionButton.small(
        heroTag: 'paypal_debug_fab',
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        onPressed: onTap,
        child: Icon(isOpen ? Icons.bug_report : Icons.bug_report_outlined),
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({
    required this.controller,
    required this.onClose,
  });
  final PaypalDebugController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFF1A1A2E),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PanelHeader(onClose: onClose, onClear: controller.clearEvents),
            _StatusSection(controller: controller),
            const Divider(height: 1, color: Color(0xFF333355)),
            Flexible(child: _EventList(events: controller.events)),
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.onClose, required this.onClear});
  final VoidCallback onClose;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF003087),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'PayPal Debug',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.delete_sweep_outlined,
                color: Colors.white70, size: 18),
            onPressed: onClear,
            tooltip: 'Clear events',
          ),
          const SizedBox(width: 4),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            onPressed: onClose,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.controller});
  final PaypalDebugController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          _StatusRow(
              label: 'SDK',
              value: controller.sdkStatus,
              highlight: controller.sdkStatus == 'INITIALIZED'),
          _StatusRow(label: 'Env', value: controller.environment),
          _StatusRow(
              label: 'Active order', value: controller.activeCheckout),
          _StatusRow(
            label: 'Last error',
            value: controller.lastError,
            isError: controller.lastError != '—',
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.isError = false,
  });
  final String label;
  final String value;
  final bool highlight;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    Color valueColor = const Color(0xFFB0BEC5);
    if (highlight) valueColor = const Color(0xFF69F0AE);
    if (isError) valueColor = const Color(0xFFFF5252);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF78909C),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events});
  final List<PaypalDebugEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No events yet.',
          style: TextStyle(color: Color(0xFF546E7A), fontSize: 11),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      itemCount: events.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFF222244)),
      itemBuilder: (context, i) => _EventTile(event: events[i]),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final PaypalDebugEvent event;

  Color get _typeColor {
    if (event.type.contains('FAILED') || event.type.contains('ERROR')) {
      return const Color(0xFFFF5252);
    }
    if (event.type.contains('OK') || event.type.contains('COMPLETED')) {
      return const Color(0xFF69F0AE);
    }
    if (event.type.contains('CANCELLED')) {
      return const Color(0xFFFFD740);
    }
    return const Color(0xFF82B1FF);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.formattedTime,
            style: const TextStyle(
              color: Color(0xFF546E7A),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              event.type,
              style: TextStyle(
                color: _typeColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.summary,
                  style: const TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 11,
                  ),
                ),
                if (event.detail.isNotEmpty)
                  Text(
                    event.detail,
                    style: const TextStyle(
                      color: Color(0xFF546E7A),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
