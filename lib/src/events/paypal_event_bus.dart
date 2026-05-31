import 'dart:async';

import 'paypal_events.dart';

/// Reactive event bus for PayPal payment lifecycle events.
///
/// Access via [FlutterPaypalPayment.events]:
/// ```dart
/// paypal.events.checkoutCompleted.listen((e) {
///   print('Order: ${e.result.orderId}');
/// });
/// ```
///
/// All streams are **broadcast** — multiple listeners are supported.
/// Call [dispose] when the owning object is destroyed to free resources.
class PaypalEventBus {
  PaypalEventBus._();

  // ── Checkout ──────────────────────────────────────────────

  final _checkoutStarted =
      StreamController<PaypalCheckoutStartedEvent>.broadcast();
  final _checkoutCompleted =
      StreamController<PaypalCheckoutCompletedEvent>.broadcast();
  final _checkoutCancelled =
      StreamController<PaypalCheckoutCancelledEvent>.broadcast();
  final _checkoutFailed =
      StreamController<PaypalCheckoutFailedEvent>.broadcast();

  // ── Card ──────────────────────────────────────────────────

  final _cardCheckoutCompleted =
      StreamController<PaypalCardCheckoutCompletedEvent>.broadcast();
  final _cardCheckoutFailed =
      StreamController<PaypalCardCheckoutFailedEvent>.broadcast();

  // ── Vault ─────────────────────────────────────────────────

  final _vaultCompleted =
      StreamController<PaypalVaultCompletedEvent>.broadcast();
  final _vaultFailed = StreamController<PaypalVaultFailedEvent>.broadcast();

  // ── Subscriptions ─────────────────────────────────────────

  final _subscriptionCreated =
      StreamController<PaypalSubscriptionCreatedEvent>.broadcast();
  final _subscriptionCancelled =
      StreamController<PaypalSubscriptionCancelledEvent>.broadcast();
  final _subscriptionSuspended =
      StreamController<PaypalSubscriptionSuspendedEvent>.broadcast();
  final _subscriptionActivated =
      StreamController<PaypalSubscriptionActivatedEvent>.broadcast();

  // ── Public streams ────────────────────────────────────────

  /// Fires just before the native checkout sheet appears.
  Stream<PaypalCheckoutStartedEvent> get checkoutStarted =>
      _checkoutStarted.stream;

  /// Fires when the buyer approves the PayPal checkout.
  Stream<PaypalCheckoutCompletedEvent> get checkoutCompleted =>
      _checkoutCompleted.stream;

  /// Fires when the buyer dismisses or cancels the checkout sheet.
  Stream<PaypalCheckoutCancelledEvent> get checkoutCancelled =>
      _checkoutCancelled.stream;

  /// Fires when a PayPal checkout attempt fails.
  Stream<PaypalCheckoutFailedEvent> get checkoutFailed =>
      _checkoutFailed.stream;

  /// Fires when a card payment is approved (after optional 3DS).
  Stream<PaypalCardCheckoutCompletedEvent> get cardCheckoutCompleted =>
      _cardCheckoutCompleted.stream;

  /// Fires when a card payment fails.
  Stream<PaypalCardCheckoutFailedEvent> get cardCheckoutFailed =>
      _cardCheckoutFailed.stream;

  /// Fires when a PayPal account or card vault operation succeeds.
  Stream<PaypalVaultCompletedEvent> get vaultCompleted =>
      _vaultCompleted.stream;

  /// Fires when a vault operation fails.
  Stream<PaypalVaultFailedEvent> get vaultFailed => _vaultFailed.stream;

  /// Fires when a subscription is created successfully.
  Stream<PaypalSubscriptionCreatedEvent> get subscriptionCreated =>
      _subscriptionCreated.stream;

  /// Fires when a subscription is cancelled.
  Stream<PaypalSubscriptionCancelledEvent> get subscriptionCancelled =>
      _subscriptionCancelled.stream;

  /// Fires when a subscription is suspended.
  Stream<PaypalSubscriptionSuspendedEvent> get subscriptionSuspended =>
      _subscriptionSuspended.stream;

  /// Fires when a suspended subscription is reactivated.
  Stream<PaypalSubscriptionActivatedEvent> get subscriptionActivated =>
      _subscriptionActivated.stream;

  // ── Internal emitters (package-private) ──────────────────

  void emitCheckoutStarted(PaypalCheckoutStartedEvent e) =>
      _checkoutStarted.add(e);
  void emitCheckoutCompleted(PaypalCheckoutCompletedEvent e) =>
      _checkoutCompleted.add(e);
  void emitCheckoutCancelled(PaypalCheckoutCancelledEvent e) =>
      _checkoutCancelled.add(e);
  void emitCheckoutFailed(PaypalCheckoutFailedEvent e) =>
      _checkoutFailed.add(e);

  void emitCardCheckoutCompleted(PaypalCardCheckoutCompletedEvent e) =>
      _cardCheckoutCompleted.add(e);
  void emitCardCheckoutFailed(PaypalCardCheckoutFailedEvent e) =>
      _cardCheckoutFailed.add(e);

  void emitVaultCompleted(PaypalVaultCompletedEvent e) =>
      _vaultCompleted.add(e);
  void emitVaultFailed(PaypalVaultFailedEvent e) => _vaultFailed.add(e);

  void emitSubscriptionCreated(PaypalSubscriptionCreatedEvent e) =>
      _subscriptionCreated.add(e);
  void emitSubscriptionCancelled(PaypalSubscriptionCancelledEvent e) =>
      _subscriptionCancelled.add(e);
  void emitSubscriptionSuspended(PaypalSubscriptionSuspendedEvent e) =>
      _subscriptionSuspended.add(e);
  void emitSubscriptionActivated(PaypalSubscriptionActivatedEvent e) =>
      _subscriptionActivated.add(e);

  // ── Lifecycle ─────────────────────────────────────────────

  /// Close all event streams. Call when the owning [FlutterPaypalPayment]
  /// instance is no longer needed.
  void dispose() {
    _checkoutStarted.close();
    _checkoutCompleted.close();
    _checkoutCancelled.close();
    _checkoutFailed.close();
    _cardCheckoutCompleted.close();
    _cardCheckoutFailed.close();
    _vaultCompleted.close();
    _vaultFailed.close();
    _subscriptionCreated.close();
    _subscriptionCancelled.close();
    _subscriptionSuspended.close();
    _subscriptionActivated.close();
  }

  /// Creates the event bus. Used only by [FlutterPaypalPayment].
  factory PaypalEventBus.create() => PaypalEventBus._();
}
