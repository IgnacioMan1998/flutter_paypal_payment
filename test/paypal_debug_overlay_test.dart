import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

void main() {
  group('PaypalDebugController', () {
    late PaypalDebugController controller;

    setUp(() => controller = PaypalDebugController());
    tearDown(() => controller.dispose());

    test('initial state has no events', () {
      expect(controller.events, isEmpty);
      expect(controller.sdkStatus, 'idle');
      expect(controller.lastError, isNull);
    });

    test('recordInit updates sdkStatus and environment', () {
      controller.recordInit(environment: 'sandbox', clientId: 'CLIENT_123');
      expect(controller.sdkStatus, 'initialized');
      expect(controller.environment, 'sandbox');
    });

    test('recordCheckoutEvent adds event to list', () {
      controller.recordCheckoutEvent(
        type: 'checkout_started',
        summary: 'Checkout started',
      );

      expect(controller.events.length, 1);
      expect(controller.events.first.type, 'checkout_started');
    });

    test('recordEvent adds custom event', () {
      controller.recordEvent(PaypalDebugEvent(
        type: 'custom',
        summary: 'Custom event',
        timestamp: DateTime.now(),
      ));

      expect(controller.events, isNotEmpty);
    });

    test('events are prepended (most recent first)', () {
      controller.recordCheckoutEvent(type: 'first', summary: 'First');
      controller.recordCheckoutEvent(type: 'second', summary: 'Second');

      expect(controller.events.first.type, 'second');
      expect(controller.events.last.type, 'first');
    });

    test('maxEvents caps at 50 events', () {
      for (var i = 0; i < 60; i++) {
        controller.recordCheckoutEvent(type: 'event_$i', summary: 'Event $i');
      }

      expect(controller.events.length, lessThanOrEqualTo(PaypalDebugController.maxEvents));
    });

    test('clearEvents removes all events', () {
      controller.recordCheckoutEvent(type: 'evt', summary: 'Evt');
      controller.clearEvents();

      expect(controller.events, isEmpty);
    });

    test('lastError set by recordCheckoutEvent with isError=true', () {
      controller.recordCheckoutEvent(
        type: 'error',
        summary: 'Something went wrong',
        isError: true,
      );

      expect(controller.lastError, isNotNull);
    });

    test('notifyListeners called on recordInit', () {
      var notified = false;
      controller.addListener(() => notified = true);
      controller.recordInit(environment: 'production', clientId: 'ID');
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
      final event = PaypalDebugEvent(
        type: 'test',
        summary: 'Test event',
        timestamp: DateTime(2025, 1, 15, 10, 30, 45),
      );

      expect(event.formattedTime, isNotEmpty);
    });

    test('detail defaults to null', () {
      final event = PaypalDebugEvent(
        type: 'test',
        summary: 'Summary',
        timestamp: DateTime.now(),
      );

      expect(event.detail, isNull);
    });

    test('detail stored when provided', () {
      final event = PaypalDebugEvent(
        type: 'test',
        summary: 'Summary',
        detail: 'Extra info',
        timestamp: DateTime.now(),
      );

      expect(event.detail, 'Extra info');
    });
  });
}
