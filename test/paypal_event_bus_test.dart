
import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

void main() {
  group('PaypalEventBus', () {
    late PaypalEventBus bus;

    setUp(() => bus = PaypalEventBus.create());
    tearDown(() => bus.dispose());

    // ── Checkout ──────────────────────────────────────────

    test('checkoutStarted emits event', () async {
      const event = PaypalCheckoutStartedEvent('ORDER-1');
      expectLater(
        bus.checkoutStarted,
        emits(predicate<PaypalCheckoutStartedEvent>(
          (e) => e.orderId == 'ORDER-1',
        )),
      );
      bus.emitCheckoutStarted(event);
    });

    test('checkoutCompleted emits event', () async {
      const success = PaymentSuccess(orderId: 'ORDER-2', payerId: 'PAYER-1');
      const event = PaypalCheckoutCompletedEvent(success);
      expectLater(
        bus.checkoutCompleted,
        emits(predicate<PaypalCheckoutCompletedEvent>(
          (e) => e.result.orderId == 'ORDER-2',
        )),
      );
      bus.emitCheckoutCompleted(event);
    });

    test('checkoutCancelled emits event', () async {
      const event = PaypalCheckoutCancelledEvent('ORDER-3');
      expectLater(
        bus.checkoutCancelled,
        emits(predicate<PaypalCheckoutCancelledEvent>(
          (e) => e.orderId == 'ORDER-3',
        )),
      );
      bus.emitCheckoutCancelled(event);
    });

    test('checkoutFailed emits event', () async {
      const failure = PaymentFailure(
        message: 'Network error',
        code: 'NETWORK_ERROR',
      );
      const event = PaypalCheckoutFailedEvent(failure);
      expectLater(
        bus.checkoutFailed,
        emits(predicate<PaypalCheckoutFailedEvent>(
          (e) => e.failure.code == 'NETWORK_ERROR',
        )),
      );
      bus.emitCheckoutFailed(event);
    });

    // ── Card ──────────────────────────────────────────────

    test('cardCheckoutCompleted emits event', () async {
      const success = CardPaymentSuccess(
        orderId: 'ORDER-4',
        didAttemptThreeDSecureAuthentication: true,
      );
      const event = PaypalCardCheckoutCompletedEvent(success);
      expectLater(
        bus.cardCheckoutCompleted,
        emits(predicate<PaypalCardCheckoutCompletedEvent>(
          (e) =>
              e.result.orderId == 'ORDER-4' &&
              e.result.didAttemptThreeDSecureAuthentication == true,
        )),
      );
      bus.emitCardCheckoutCompleted(event);
    });

    test('cardCheckoutFailed emits event', () async {
      const failure = CardPaymentFailure(message: 'Card declined');
      const event = PaypalCardCheckoutFailedEvent(failure);
      expectLater(
        bus.cardCheckoutFailed,
        emits(predicate<PaypalCardCheckoutFailedEvent>(
          (e) => e.failure.message == 'Card declined',
        )),
      );
      bus.emitCardCheckoutFailed(event);
    });

    // ── Vault ─────────────────────────────────────────────

    test('vaultCompleted emits event', () async {
      const success = VaultSuccess(setupTokenId: 'TOKEN-1', status: 'VAULTED');
      const event = PaypalVaultCompletedEvent(success);
      expectLater(
        bus.vaultCompleted,
        emits(predicate<PaypalVaultCompletedEvent>(
          (e) => e.result.setupTokenId == 'TOKEN-1',
        )),
      );
      bus.emitVaultCompleted(event);
    });

    test('vaultFailed emits event', () async {
      const failure = VaultFailure(message: 'Token expired');
      const event = PaypalVaultFailedEvent(failure);
      expectLater(
        bus.vaultFailed,
        emits(predicate<PaypalVaultFailedEvent>(
          (e) => e.failure.message == 'Token expired',
        )),
      );
      bus.emitVaultFailed(event);
    });

    // ── Subscriptions ─────────────────────────────────────

    test('subscriptionCreated emits event', () async {
      final event = PaypalSubscriptionCreatedEvent(
        subscriptionId: 'I-1234',
        data: {'status': 'ACTIVE'},
      );
      expectLater(
        bus.subscriptionCreated,
        emits(predicate<PaypalSubscriptionCreatedEvent>(
          (e) => e.subscriptionId == 'I-1234',
        )),
      );
      bus.emitSubscriptionCreated(event);
    });

    test('subscriptionCancelled emits event', () async {
      const event = PaypalSubscriptionCancelledEvent('I-5678');
      expectLater(
        bus.subscriptionCancelled,
        emits(predicate<PaypalSubscriptionCancelledEvent>(
          (e) => e.subscriptionId == 'I-5678',
        )),
      );
      bus.emitSubscriptionCancelled(event);
    });

    test('subscriptionSuspended emits event', () async {
      const event = PaypalSubscriptionSuspendedEvent('I-9999');
      expectLater(
        bus.subscriptionSuspended,
        emits(predicate<PaypalSubscriptionSuspendedEvent>(
          (e) => e.subscriptionId == 'I-9999',
        )),
      );
      bus.emitSubscriptionSuspended(event);
    });

    test('subscriptionActivated emits event', () async {
      const event = PaypalSubscriptionActivatedEvent('I-AAAA');
      expectLater(
        bus.subscriptionActivated,
        emits(predicate<PaypalSubscriptionActivatedEvent>(
          (e) => e.subscriptionId == 'I-AAAA',
        )),
      );
      bus.emitSubscriptionActivated(event);
    });

    // ── Multiple listeners ────────────────────────────────

    test('broadcast streams support multiple listeners', () async {
      final results = <String>[];
      bus.checkoutStarted.listen((e) => results.add('L1:${e.orderId}'));
      bus.checkoutStarted.listen((e) => results.add('L2:${e.orderId}'));

      bus.emitCheckoutStarted(const PaypalCheckoutStartedEvent('ORDER-X'));
      await Future<void>.delayed(Duration.zero);

      expect(results, containsAll(['L1:ORDER-X', 'L2:ORDER-X']));
    });

    // ── Dispose ───────────────────────────────────────────

    test('dispose closes all streams', () async {
      bus.dispose();
      expect(bus.checkoutStarted.isBroadcast, isTrue);

      bool threw = false;
      try {
        bus.emitCheckoutStarted(
            const PaypalCheckoutStartedEvent('AFTER_DISPOSE'));
      } catch (_) {
        threw = true;
      }
      expect(threw, isTrue);
    });
  });
}
