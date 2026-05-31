import 'package:flutter/material.dart';

import '../core/enums/paypal_enums.dart';

/// A production-ready PayPal-branded checkout button.
///
/// Automatically adapts its appearance to the selected [fundingSource],
/// supports Material 3, and respects the system dark-mode preference.
///
/// ```dart
/// PaypalCheckoutButton(
///   onPressed: () async {
///     final result = await paypal.pay(
///       PaymentRequest(orderId: 'ORDER_ID'),
///     );
///   },
/// )
/// ```
class PaypalCheckoutButton extends StatefulWidget {
  const PaypalCheckoutButton({
    super.key,
    required this.onPressed,
    this.fundingSource = PaypalFundingSource.paypal,
    this.isLoading = false,
    this.label,
    this.width = double.infinity,
    this.height = 50.0,
    this.borderRadius = 8.0,
  });

  /// Called when the user taps the button. Set `null` to disable.
  final VoidCallback? onPressed;

  /// Controls which brand identity to render.
  final PaypalFundingSource fundingSource;

  /// If `true`, shows a spinner and disables taps.
  final bool isLoading;

  /// Override the default label text.
  final String? label;

  /// Button width. Defaults to [double.infinity] (fills its parent).
  final double width;

  /// Button height. Defaults to 50.
  final double height;

  /// Corner radius. Defaults to 8.
  final double borderRadius;

  @override
  State<PaypalCheckoutButton> createState() => _PaypalCheckoutButtonState();
}

class _PaypalCheckoutButtonState extends State<PaypalCheckoutButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  _ButtonStyle get _style =>
      _ButtonStyle.forSource(widget.fundingSource, context);

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: isDisabled
            ? null
            : (_) => _pressController.forward(),
        onTapUp: isDisabled
            ? null
            : (_) {
                _pressController.reverse();
                widget.onPressed?.call();
              },
        onTapCancel:
            isDisabled ? null : () => _pressController.reverse(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: isDisabled ? null : style.gradient,
            color: isDisabled ? style.disabledColor : null,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: style.shadowColor,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: widget.isLoading
              ? Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(style.foregroundColor),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (style.logoWidget != null) ...[
                      style.logoWidget!,
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label ?? style.defaultLabel,
                      style: TextStyle(
                        color: isDisabled
                            ? style.foregroundColor.withAlpha(120)
                            : style.foregroundColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Internal helpers ──────────────────────────────────────

class _ButtonStyle {
  const _ButtonStyle({
    required this.gradient,
    required this.disabledColor,
    required this.foregroundColor,
    required this.shadowColor,
    required this.defaultLabel,
    this.logoWidget,
  });

  final LinearGradient gradient;
  final Color disabledColor;
  final Color foregroundColor;
  final Color shadowColor;
  final String defaultLabel;
  final Widget? logoWidget;

  static _ButtonStyle forSource(
      PaypalFundingSource source, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return switch (source) {
      PaypalFundingSource.paypal => _ButtonStyle(
          gradient: const LinearGradient(
            colors: [Color(0xFF003087), Color(0xFF0070BA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          disabledColor: isDark
              ? const Color(0xFF2A3A50)
              : const Color(0xFFB0C4D8),
          foregroundColor: Colors.white,
          shadowColor: const Color(0xFF003087).withAlpha(80),
          defaultLabel: 'Pay with PayPal',
          logoWidget: const _PayPalWordmark(color: Colors.white),
        ),
      PaypalFundingSource.payLater => _ButtonStyle(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFC439), Color(0xFFFFB800)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          disabledColor: isDark
              ? const Color(0xFF4A3A10)
              : const Color(0xFFEEDDA0),
          foregroundColor: const Color(0xFF001C64),
          shadowColor: const Color(0xFFFFC439).withAlpha(80),
          defaultLabel: 'Pay Later',
        ),
      PaypalFundingSource.venmo => _ButtonStyle(
          gradient: const LinearGradient(
            colors: [Color(0xFF3D95CE), Color(0xFF3282B8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          disabledColor: isDark
              ? const Color(0xFF1A3040)
              : const Color(0xFFB0D0E8),
          foregroundColor: Colors.white,
          shadowColor: const Color(0xFF3D95CE).withAlpha(80),
          defaultLabel: 'Pay with Venmo',
        ),
      PaypalFundingSource.credit => _ButtonStyle(
          gradient: const LinearGradient(
            colors: [Color(0xFF001C64), Color(0xFF003087)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          disabledColor: isDark
              ? const Color(0xFF1A2040)
              : const Color(0xFFB0B8D0),
          foregroundColor: Colors.white,
          shadowColor: const Color(0xFF001C64).withAlpha(80),
          defaultLabel: 'Pay with Credit',
        ),
      PaypalFundingSource.debit => _ButtonStyle(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A7F3C), Color(0xFF155E2C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          disabledColor: isDark
              ? const Color(0xFF1A3020)
              : const Color(0xFFB0D0B8),
          foregroundColor: Colors.white,
          shadowColor: const Color(0xFF1A7F3C).withAlpha(80),
          defaultLabel: 'Pay with Debit',
        ),
    };
  }
}

/// Minimal PayPal wordmark rendered via [CustomPaint] — no image assets needed.
class _PayPalWordmark extends StatelessWidget {
  const _PayPalWordmark({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'PayPal',
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: 15,
        letterSpacing: -0.5,
      ),
    );
  }
}
