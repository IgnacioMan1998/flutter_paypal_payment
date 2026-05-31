import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

void main() {
  group('New event classes', () {
    test('PaypalRefundCompletedEvent stores all fields', () {
      const event = PaypalRefundCompletedEvent(
        captureId: 'CAP123',
        refundId: 'REF456',
        amount: '50.00',
        currencyCode: 'USD',
      );

      expect(event.captureId, 'CAP123');
      expect(event.refundId, 'REF456');
      expect(event.amount, '50.00');
      expect(event.currencyCode, 'USD');
    });

    test('PaypalRefundCompletedEvent optional fields nullable', () {
      const event = PaypalRefundCompletedEvent(
        captureId: 'CAP123',
        refundId: 'REF456',
      );

      expect(event.amount, isNull);
      expect(event.currencyCode, isNull);
    });

    test('PaypalRefundFailedEvent stores captureId and failure', () {
      const failure = PaymentFailure(message: 'Refund denied', code: 'refund_error');
      const event = PaypalRefundFailedEvent(captureId: 'CAP123', failure: failure);

      expect(event.captureId, 'CAP123');
      expect(event.failure.message, 'Refund denied');
    });

    test('PaypalCardPaymentStartedEvent stores orderId', () {
      const event = PaypalCardPaymentStartedEvent('ORDER123');
      expect(event.orderId, 'ORDER123');
    });

    test('PaypalVaultStartedEvent stores setupTokenId', () {
      const event = PaypalVaultStartedEvent('SETUP_TOKEN_456');
      expect(event.setupTokenId, 'SETUP_TOKEN_456');
    });
  });

  group('PaypalEventBus new streams', () {
    late PaypalEventBus bus;

    setUp(() => bus = PaypalEventBus.create());
    tearDown(() => bus.dispose());

    test('refundCompleted stream emits event', () async {
      final future = bus.refundCompleted.first;
      bus.emitRefundCompleted(const PaypalRefundCompletedEvent(
        captureId: 'CAP1',
        refundId: 'REF1',
      ));
      final event = await future;
      expect(event.captureId, 'CAP1');
    });

    test('refundFailed stream emits event', () async {
      const failure = PaymentFailure(message: 'Error', code: 'err');
      final future = bus.refundFailed.first;
      bus.emitRefundFailed(const PaypalRefundFailedEvent(
        captureId: 'CAP2',
        failure: failure,
      ));
      final event = await future;
      expect(event.failure.message, 'Error');
    });

    test('cardPaymentStarted stream emits event', () async {
      final future = bus.cardPaymentStarted.first;
      bus.emitCardPaymentStarted(const PaypalCardPaymentStartedEvent('ORD1'));
      final event = await future;
      expect(event.orderId, 'ORD1');
    });

    test('vaultStarted stream emits event', () async {
      final future = bus.vaultStarted.first;
      bus.emitVaultStarted(const PaypalVaultStartedEvent('SETUP1'));
      final event = await future;
      expect(event.setupTokenId, 'SETUP1');
    });
  });
}
