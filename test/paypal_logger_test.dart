import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

void main() {
  // ═══════════════════════════════════════════════════════
  // PaypalLogger
  // ═══════════════════════════════════════════════════════

  group('PaypalLogger', () {
    final captured = <String>[];

    setUp(() {
      captured.clear();
      PaypalLogger.minLevel = PaypalLogLevel.debug;
      PaypalLogger.customHandler = (level, tag, message, [error, st]) {
        captured.add('${level.name}:$tag:$message');
        return true; // suppress default output during tests
      };
    });

    tearDown(() {
      PaypalLogger.customHandler = null;
      PaypalLogger.minLevel = PaypalLogLevel.info;
    });

    test('debug() routes to handler at debug level', () {
      PaypalLogger.debug('hello debug', tag: 'Test');
      expect(captured, contains('debug:Test:hello debug'));
    });

    test('info() routes to handler', () {
      PaypalLogger.info('hello info', tag: 'Test');
      expect(captured, contains('info:Test:hello info'));
    });

    test('warning() routes to handler', () {
      PaypalLogger.warning('hello warn', tag: 'Test');
      expect(captured, contains('warning:Test:hello warn'));
    });

    test('error() routes to handler', () {
      PaypalLogger.error('hello error', tag: 'Test');
      expect(captured, contains('error:Test:hello error'));
    });

    test('messages below minLevel are suppressed', () {
      PaypalLogger.minLevel = PaypalLogLevel.warning;
      PaypalLogger.debug('suppressed', tag: 'Test');
      PaypalLogger.info('also suppressed', tag: 'Test');
      PaypalLogger.warning('emitted', tag: 'Test');
      expect(captured.length, 1);
      expect(captured.first, contains('emitted'));
    });

    test('customHandler returning true suppresses default print', () {
      // No exception means it suppressed cleanly
      PaypalLogger.customHandler = (_, _, _, [_, _]) => true;
      expect(
        () => PaypalLogger.info('quiet', tag: 'T'),
        returnsNormally,
      );
    });

    test('customHandler returning false falls through to default', () {
      var handlerCalled = false;
      PaypalLogger.customHandler = (level, tag, message, [error, st]) {
        handlerCalled = true;
        return false; // let default output run
      };
      expect(
        () => PaypalLogger.info('passthrough', tag: 'T'),
        returnsNormally,
      );
      expect(handlerCalled, isTrue);
    });

    test('level none suppresses all output', () {
      PaypalLogger.minLevel = PaypalLogLevel.none;
      PaypalLogger.debug('d', tag: 'T');
      PaypalLogger.info('i', tag: 'T');
      PaypalLogger.warning('w', tag: 'T');
      PaypalLogger.error('e', tag: 'T');
      expect(captured, isEmpty);
    });
  });
}
