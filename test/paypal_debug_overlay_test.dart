import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

void main() {
  group('PaypalDebugController', () {
    late PaypalDebugController controller;

    setUp(() => controller = PaypalDebugController());
    tearDown(() => controller.dispose());

    test('initial state has no events', () {
      expect(controller.events, isEmpty);
      expect(controller.sdkStatus, isNotEmpty);
    });

    test('recordInit updates sdkStatus and environment', () {
      controller.recordInit(env: 'sandbox');
      expect(controller.sdkStatus, 'INITIALIZED');
      expect(controller.environment, 'sandbox');
    });

    test('recordCheckoutEvent adds event for started', () {
      controller.recordCheckoutEvent(PaypalCheckoutStartedEvent('ORDER123'));
      expect(controller.events.length, 1);
      expect(controller.events.first.type, 'CHECKOUT_STARTED');
    });

    test('recordEvent adds custom event', () {
      controller.recordEvent(type: 'custom', summary: 'Custom event');
      expect(controller.events, isNotEmpty);
    });

    test('events are most recent first', () {
      controller.recordEvent(type: 'first', summary: 'First');
      controller.recordEvent(type: 'second', summary: 'Second');
      expect(controller.events.first.type, 'second');
      expect(controller.events.last.type, 'first');
    });

    test('maxEvents caps list size', () {
      for (var i = 0; i < 60; i++) {
        controller.recordEvent(type: 'event_$i', summary: 'Event $i');
      }
      expect(controller.events.length, lessThanOrEqualTo(controller.maxEvents));
    });

    test('clearEvents removes all events', () {
      controller.recordEvent(type: 'evt', summary: 'Evt');
      controller.clearEvents();
      expect(controller.events, isEmpty);
    });

    test('lastError updated when isError=true', () {
      controller.recordEvent(
        type: 'error',
        summary: 'Something went wrong',
        isError: true,
      );
      expect(controller.lastError, contains('Something went wrong'));
    });

    test('notifyListeners called on recordInit', () {
      var notified = false;
      controller.addListener(() => notified = true);
      controller.recordInit(env: 'production');
      expect(notified, isTrue);
    });

    test('notifyListeners called on clearEvents', () {
      var notified = false;
      controller.addListener(() => notified = true);
      controller.clearEvents();
      expect(notified, isTrue);
    });
  });

  group('PaypalDebugEvent', () {
    test('formattedTime is not empty', () {
      final event = PaypalDebugEvent(type: 'test', summary: 'Test event');
      expect(event.formattedTime, isNotEmpty);
    });

    test('detail defaults to empty string', () {
      final event = PaypalDebugEvent(type: 'test', summary: 'Summary');
      expect(event.detail, '');
    });

    test('detail stored when provided', () {
      final event = PaypalDebugEvent(
        type: 'test',
        summary: 'Summary',
        detail: 'Extra info',
      );
      expect(event.detail, 'Extra info');
    });

    test('timestamp is set automatically', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final event = PaypalDebugEvent(type: 'test', summary: 'Summary');
      expect(event.timestamp.isAfter(before), isTrue);
    });
  });
}
