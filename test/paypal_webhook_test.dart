import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

void main() {
  // ═══════════════════════════════════════════════════════
  // PaypalWebhookEvent.fromJson
  // ═══════════════════════════════════════════════════════

  group('PaypalWebhookEvent.fromJson', () {
    Map<String, dynamic> payloadFor(
        String eventType, String resourceType, Map<String, dynamic> resource) {
      return {
        'id': 'WH-TEST-001',
        'event_type': eventType,
        'resource_type': resourceType,
        'resource': resource,
        'summary': 'Test event',
        'create_time': '2026-01-01T12:00:00Z',
        'webhook_id': 'WH-ID-123',
      };
    }

    test('parses PAYMENT.CAPTURE.COMPLETED correctly', () {
      final json = payloadFor(
        'PAYMENT.CAPTURE.COMPLETED',
        'capture',
        {'id': 'CAPTURE-123', 'status': 'COMPLETED'},
      );
      final event = PaypalWebhookEvent.fromJson(json);

      expect(event.id, 'WH-TEST-001');
      expect(event.eventType, PaypalWebhookEventType.paymentCaptureCompleted);
      expect(event.eventTypeName, 'PAYMENT.CAPTURE.COMPLETED');
      expect(event.resourceType, PaypalWebhookResourceType.capture);
      expect(event.resource['id'], 'CAPTURE-123');
      expect(event.webhookId, 'WH-ID-123');
      expect(event.createTime, DateTime.parse('2026-01-01T12:00:00Z'));
    });

    test('parses CHECKOUT.ORDER.APPROVED correctly', () {
      final json = payloadFor(
        'CHECKOUT.ORDER.APPROVED',
        'checkout_order',
        {'id': 'ORDER-456'},
      );
      final event = PaypalWebhookEvent.fromJson(json);

      expect(event.eventType, PaypalWebhookEventType.checkoutOrderApproved);
      expect(event.resourceType, PaypalWebhookResourceType.checkoutOrder);
    });

    test('parses BILLING.SUBSCRIPTION.ACTIVATED correctly', () {
      final json = payloadFor(
        'BILLING.SUBSCRIPTION.ACTIVATED',
        'subscription',
        {'id': 'I-12345'},
      );
      final event = PaypalWebhookEvent.fromJson(json);

      expect(event.eventType,
          PaypalWebhookEventType.billingSubscriptionActivated);
      expect(event.resourceType, PaypalWebhookResourceType.subscription);
    });

    test('unknown event type maps to PaypalWebhookEventType.unknown', () {
      final json = payloadFor('SOME.FUTURE.EVENT', 'payment', {});
      final event = PaypalWebhookEvent.fromJson(json);

      expect(event.eventType, PaypalWebhookEventType.unknown);
    });

    test('unknown resource type maps to PaypalWebhookResourceType.unknown', () {
      final json = payloadFor('PAYMENT.CAPTURE.COMPLETED', 'new_type', {});
      final event = PaypalWebhookEvent.fromJson(json);

      expect(event.resourceType, PaypalWebhookResourceType.unknown);
    });

    test('missing create_time falls back to epoch', () {
      final json = {
        'id': 'WH-X',
        'event_type': 'PAYMENT.CAPTURE.COMPLETED',
        'resource_type': 'capture',
        'resource': {},
        'summary': '',
      };
      final event = PaypalWebhookEvent.fromJson(json);

      expect(event.createTime,
          DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('toJson round-trips the event', () {
      final json = payloadFor(
        'PAYMENT.CAPTURE.COMPLETED',
        'capture',
        {'id': 'CAPTURE-999'},
      );
      final event = PaypalWebhookEvent.fromJson(json);
      final roundTripped = event.toJson();

      expect(roundTripped['id'], 'WH-TEST-001');
      expect(roundTripped['event_type'], 'PAYMENT.CAPTURE.COMPLETED');
      expect(
          (roundTripped['resource'] as Map<String, dynamic>)['id'],
          'CAPTURE-999');
    });
  });

  // ═══════════════════════════════════════════════════════
  // PaypalWebhookHelper.parse
  // ═══════════════════════════════════════════════════════

  group('PaypalWebhookHelper.parse', () {
    test('parses a valid JSON webhook body', () {
      final body = jsonEncode({
        'id': 'WH-1',
        'event_type': 'PAYMENT.CAPTURE.COMPLETED',
        'resource_type': 'capture',
        'resource': {'id': 'CAP-1'},
        'summary': 'Payment captured',
        'create_time': '2026-03-01T00:00:00Z',
      });

      final event = PaypalWebhookHelper.parse(body);
      expect(event.id, 'WH-1');
      expect(event.eventType, PaypalWebhookEventType.paymentCaptureCompleted);
    });

    test('throws FormatException on invalid JSON', () {
      expect(
        () => PaypalWebhookHelper.parse('not-json'),
        throwsFormatException,
      );
    });

    test('throws FormatException on JSON array', () {
      expect(
        () => PaypalWebhookHelper.parse('[1,2,3]'),
        throwsFormatException,
      );
    });

    test('tryParse returns null on invalid JSON', () {
      expect(PaypalWebhookHelper.tryParse('bad'), isNull);
    });

    test('tryParse returns event on valid JSON', () {
      final body = jsonEncode({
        'id': 'WH-2',
        'event_type': 'CHECKOUT.ORDER.COMPLETED',
        'resource_type': 'checkout_order',
        'resource': {},
        'summary': '',
        'create_time': '2026-01-01T00:00:00Z',
      });
      final event = PaypalWebhookHelper.tryParse(body);
      expect(event, isNotNull);
      expect(event!.eventType, PaypalWebhookEventType.checkoutOrderCompleted);
    });
  });

  // ═══════════════════════════════════════════════════════
  // PaypalWebhookHelper.verifySignatureLocal
  // ═══════════════════════════════════════════════════════

  group('PaypalWebhookHelper.verifySignatureLocal', () {
    const body = '{"id":"WH-001","event_type":"PAYMENT.CAPTURE.COMPLETED"}';

    test('returns false when signature does not match', () {
      final valid = PaypalWebhookHelper.verifySignatureLocal(
        webhookId: 'WH-ID',
        transmissionId: 'TX-1',
        transmissionTime: '2026-01-01T00:00:00Z',
        certUrl: 'https://example.com/cert',
        authAlgo: 'SHA256withRSA',
        actualSignature: 'WRONG_SIGNATURE',
        webhookSecret: 'my_secret',
        body: body,
      );
      expect(valid, isFalse);
    });

    test('consistent signature for same inputs', () {
      const inputs = (
        webhookId: 'WH-ID-CONS',
        transmissionId: 'TX-CONS',
        transmissionTime: '2026-01-01T00:00:00Z',
        certUrl: 'https://cert.example.com',
        authAlgo: 'SHA256withRSA',
        webhookSecret: 'super_secret',
        body: '{"id":"test"}',
      );

      // Generate "correct" sig by trusting first call result
      // (used to verify determinism, not correctness).
      final firstCall = PaypalWebhookHelper.verifySignatureLocal(
        webhookId: inputs.webhookId,
        transmissionId: inputs.transmissionId,
        transmissionTime: inputs.transmissionTime,
        certUrl: inputs.certUrl,
        authAlgo: inputs.authAlgo,
        actualSignature: 'mismatch',
        webhookSecret: inputs.webhookSecret,
        body: inputs.body,
      );

      final secondCall = PaypalWebhookHelper.verifySignatureLocal(
        webhookId: inputs.webhookId,
        transmissionId: inputs.transmissionId,
        transmissionTime: inputs.transmissionTime,
        certUrl: inputs.certUrl,
        authAlgo: inputs.authAlgo,
        actualSignature: 'mismatch',
        webhookSecret: inputs.webhookSecret,
        body: inputs.body,
      );

      // Both should produce the same result (deterministic)
      expect(firstCall, equals(secondCall));
    });
  });
}
