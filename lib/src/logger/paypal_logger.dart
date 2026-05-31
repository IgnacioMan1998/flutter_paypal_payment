import 'package:flutter/foundation.dart';

/// Log severity levels for [PaypalLogger].
enum PaypalLogLevel {
  /// Ultra-verbose tracing (individual HTTP headers, token bytes).
  /// **Never enable in production.**
  trace,

  /// Verbose diagnostic output (request bodies, token values).
  /// **Never enable in production.**
  debug,

  /// Informational milestones: init, checkout start, capture success.
  info,

  /// Non-fatal issues that may affect UX (retries, deprecations).
  warning,

  /// Failures that the caller must handle.
  error,

  /// Suppress all log output.
  none,
}

/// Structured logger for the paypal_checkout_flutter package.
///
/// ## Configuration
///
/// ```dart
/// // Raise the minimum level (default: info in release, debug in debug mode)
/// PaypalLogger.minLevel = PaypalLogLevel.warning;
///
/// // Redirect to your own logging framework
/// PaypalLogger.customHandler = (level, tag, message, [error, stackTrace]) {
///   myLogger.log(message, level: level.name);
///   return true; // true = handled, skip default output
/// };
/// ```
///
/// ## Usage inside the package
///
/// ```dart
/// PaypalLogger.info('Order created', tag: 'OrderService');
/// PaypalLogger.error('Auth failed', tag: 'Auth', error: e, stackTrace: st);
/// ```
abstract final class PaypalLogger {
  static const String _defaultTag = 'PayPal';

  /// The minimum log level to emit. Messages below this level are dropped.
  ///
  /// Defaults to [PaypalLogLevel.debug] in debug mode and
  /// [PaypalLogLevel.info] in profile/release mode.
  ///
  /// Set to [PaypalLogLevel.trace] to enable ultra-verbose HTTP tracing.
  static PaypalLogLevel minLevel =
      kDebugMode ? PaypalLogLevel.debug : PaypalLogLevel.info;

  /// Optional custom log handler. Return `true` to suppress the default output.
  static bool Function(
    PaypalLogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ])? customHandler;

  // ── Public API ────────────────────────────────────────────

  /// Emit a [PaypalLogLevel.trace] message.
  ///
  /// Use for ultra-verbose output: raw HTTP headers, token bytes, serialization.
  /// **Never enable in production.**
  static void trace(String message, {String tag = _defaultTag}) =>
      _emit(PaypalLogLevel.trace, tag, message);

  /// Emit a [PaypalLogLevel.debug] message.
  static void debug(String message, {String tag = _defaultTag}) =>
      _emit(PaypalLogLevel.debug, tag, message);

  /// Emit a [PaypalLogLevel.info] message.
  static void info(String message, {String tag = _defaultTag}) =>
      _emit(PaypalLogLevel.info, tag, message);

  /// Emit a [PaypalLogLevel.warning] message.
  static void warning(
    String message, {
    String tag = _defaultTag,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _emit(PaypalLogLevel.warning, tag, message, error, stackTrace);

  /// Emit a [PaypalLogLevel.error] message.
  static void error(
    String message, {
    String tag = _defaultTag,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _emit(PaypalLogLevel.error, tag, message, error, stackTrace);

  // ── Internal ──────────────────────────────────────────────

  static void _emit(
    PaypalLogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (level.index < minLevel.index) return;

    if (customHandler != null) {
      final handled = customHandler!(level, tag, message, error, stackTrace);
      if (handled) return;
    }

    final prefix = _prefix(level);
    final timestamp = DateTime.now().toIso8601String();
    final buffer = StringBuffer()
      ..write('[$timestamp] $prefix [$tag] $message');

    if (error != null) buffer.write('\n  Error: $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');

    debugPrint(buffer.toString());
  }

  static String _prefix(PaypalLogLevel level) => switch (level) {
        PaypalLogLevel.trace => 'TRACE',
        PaypalLogLevel.debug => 'DEBUG',
        PaypalLogLevel.info => 'INFO ',
        PaypalLogLevel.warning => 'WARN ',
        PaypalLogLevel.error => 'ERROR',
        PaypalLogLevel.none => '',
      };
}
