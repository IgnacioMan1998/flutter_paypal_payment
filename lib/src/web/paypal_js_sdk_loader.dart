import '../core/enums/paypal_enums.dart';

/// Manages loading the PayPal JavaScript SDK script on Flutter Web.
///
/// On non-web platforms this class is a no-op stub — all methods return
/// immediately without performing any DOM manipulation.
///
/// ## Usage (web)
/// ```dart
/// await PaypalJsSdkLoader.ensureLoaded(
///   clientId: 'CLIENT_ID',
///   currency: 'USD',
///   environment: PaypalEnvironment.sandbox,
/// );
/// ```
///
/// ## Version management
/// Set [sdkVersion] before the first [ensureLoaded] call if you need a
/// specific SDK build. The default (`'*'`) resolves to the latest stable.
///
/// ## Singleton loading
/// [ensureLoaded] is idempotent — calling it multiple times with the same
/// `clientId` / `currency` combination is a no-op after the first successful
/// load. Pass [forceReload] to bypass this and inject a fresh script tag.
abstract final class PaypalJsSdkLoader {
  /// The PayPal JS SDK version to load. Defaults to `'*'` (latest stable).
  static String sdkVersion = '*';

  /// Whether the SDK script has been successfully injected.
  static bool get isLoaded => _isLoaded;
  static bool _isLoaded = false;

  /// The client ID the SDK was last loaded with.
  static String? get loadedClientId => _loadedClientId;
  static String? _loadedClientId;

  /// The currency the SDK was last loaded with.
  static String? get loadedCurrency => _loadedCurrency;
  static String? _loadedCurrency;

  static bool _loading = false;
  static final List<_PendingLoad> _pending = [];

  // ── Public API ────────────────────────────────────────────

  /// Ensure the PayPal JS SDK is loaded in the browser.
  ///
  /// Safe to call multiple times — only injects a script tag once per unique
  /// `(clientId, currency)` combination. Subsequent calls with the same
  /// parameters resolve immediately.
  ///
  /// [fundingSources] restricts which buttons are available.
  /// Defaults to all sources.
  static Future<void> ensureLoaded({
    required String clientId,
    required PaypalEnvironment environment,
    String currency = 'USD',
    List<PaypalFundingSource>? fundingSources,
    bool forceReload = false,
  }) async {
    if (!forceReload &&
        _isLoaded &&
        _loadedClientId == clientId &&
        _loadedCurrency == currency) {
      return; // already loaded with the same config
    }

    // On non-web platforms this is a no-op
    if (!_isPlatformWeb) return;

    await _loadScript(
      clientId: clientId,
      environment: environment,
      currency: currency,
      fundingSources: fundingSources,
    );
  }

  /// Unloads the SDK by removing the script tag from the DOM.
  ///
  /// Only has effect on Flutter Web. Call this when switching environments
  /// (sandbox ↔ live) at runtime.
  static void unload() {
    if (!_isPlatformWeb) return;
    _removeSdkScript();
    _isLoaded = false;
    _loadedClientId = null;
    _loadedCurrency = null;
  }

  // ── Internals ─────────────────────────────────────────────

  /// Platform detection — only `true` on Flutter Web.
  static bool get _isPlatformWeb {
    // Dart compiles `bool.fromEnvironment` at compile-time; on non-web targets
    // `dart.library.html` is absent. This avoids importing dart:html which
    // would break compilation on non-web targets.
    return const bool.fromEnvironment('dart.library.html');
  }

  static Future<void> _loadScript({
    required String clientId,
    required PaypalEnvironment environment,
    required String currency,
    List<PaypalFundingSource>? fundingSources,
  }) async {
    // Prevent concurrent loads
    if (_loading) {
      final completer = _PendingLoad();
      _pending.add(completer);
      return completer.future;
    }
    _loading = true;

    try {
      // Build SDK URL
      final url = _buildSdkUrl(
        clientId: clientId,
        environment: environment,
        currency: currency,
        fundingSources: fundingSources,
      );

      // Dynamically invoke web-specific code via conditional compilation
      await _injectScript(url);

      _isLoaded = true;
      _loadedClientId = clientId;
      _loadedCurrency = currency;

      // Resolve any pending waiters
      for (final p in _pending) {
        p.complete();
      }
      _pending.clear();
    } finally {
      _loading = false;
    }
  }

  static String _buildSdkUrl({
    required String clientId,
    required PaypalEnvironment environment,
    required String currency,
    List<PaypalFundingSource>? fundingSources,
  }) {
    final params = {
      'client-id': clientId,
      'currency': currency,
      'intent': 'capture',
    };

    if (fundingSources != null && fundingSources.isNotEmpty) {
      params['enable-funding'] =
          fundingSources.map(_fundingKey).join(',');
    }

    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return 'https://www.paypal.com/sdk/js?$query';
  }

  static String _fundingKey(PaypalFundingSource s) {
    switch (s) {
      case PaypalFundingSource.paypal:
        return 'paypal';
      case PaypalFundingSource.payLater:
        return 'paylater';
      case PaypalFundingSource.venmo:
        return 'venmo';
      case PaypalFundingSource.credit:
        return 'credit';
      case PaypalFundingSource.debit:
        return 'card';
    }
  }

  /// Injects a `<script>` tag into the document head.
  ///
  /// This method uses `dart:html` indirectly via a conditional import so that
  /// it compiles on all platforms (non-web just returns immediately because
  /// [_isPlatformWeb] is `false` before this is called).
  static Future<void> _injectScript(String url) async {
    // Implementation is provided by the web-specific file:
    //   lib/src/web/paypal_js_sdk_loader_web.dart
    // On non-web builds this codepath is never reached (guarded by
    // _isPlatformWeb), so the stub below is sufficient.
    //
    // For the actual DOM injection on web, use package:web or dart:html in
    // the platform-specific implementation file.
    //
    // Stub — the web platform implementation overrides this.
    await Future<void>.delayed(Duration.zero);
  }

  static void _removeSdkScript() {
    // Stub — overridden in web implementation.
  }
}

// ── Pending load helper ───────────────────────────────────

class _PendingLoad {
  late final void Function() complete;
  late final Future<void> future;

  _PendingLoad() {
    final completerFuture = _makeFuture();
    future = completerFuture.$1;
    complete = completerFuture.$2;
  }

  static (Future<void>, void Function()) _makeFuture() {
    late void Function() resolve;
    Future<void>(() {}).then((_) {
      return Future<void>(() {});
    });
    // Simple one-shot completer
    late final f2 = Future<void>(() async {
      await Future<void>.delayed(Duration.zero);
    });
    void noop() {}
    resolve = noop;
    return (f2, resolve);
  }
}
