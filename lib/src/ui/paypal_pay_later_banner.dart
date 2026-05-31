import 'package:flutter/material.dart';

/// A promotional banner that surfaces Pay Later messaging inline.
///
/// Renders a compact, accessible banner informing the buyer of their
/// Pay Later options (e.g., "Pay in 4" interest-free instalments).
///
/// ```dart
/// PaypalPayLaterBanner(
///   amount: '499.99',
///   currencyCode: 'USD',
///   onLearnMoreTap: () { /* open Pay Later details */ },
/// )
/// ```
class PaypalPayLaterBanner extends StatelessWidget {
  const PaypalPayLaterBanner({
    super.key,
    required this.amount,
    this.currencyCode = 'USD',
    this.onLearnMoreTap,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = 8.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  /// Purchase total displayed in the instalment calculation.
  final String amount;

  /// ISO 4217 currency code for display purposes. Defaults to `"USD"`.
  final String currencyCode;

  /// Optional callback for "Learn more" tap. If `null`, the link is hidden.
  final VoidCallback? onLearnMoreTap;

  /// Background color. Defaults to PayPal's Pay Later gold.
  final Color? backgroundColor;

  /// Primary text color. Defaults to PayPal dark blue.
  final Color? textColor;

  /// Corner radius. Defaults to 8.
  final double borderRadius;

  /// Internal padding. Defaults to 16 × 12.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        backgroundColor ?? (isDark ? const Color(0xFF2A2200) : const Color(0xFFFFF3CD));
    final fg = textColor ??
        (isDark ? const Color(0xFFFFC439) : const Color(0xFF001C64));

    final instalment = _calculateInstalment(amount);

    return Semantics(
      label: 'Pay Later: 4 interest-free payments of $instalment $currencyCode',
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isDark
                ? const Color(0xFFFFC439).withAlpha(60)
                : const Color(0xFFFFC439),
            width: 1,
          ),
        ),
        padding: padding,
        child: Row(
          children: [
            // Pay Later icon
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC439),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text(
                  '4',
                  style: TextStyle(
                    color: Color(0xFF001C64),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '4 interest-free payments',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'of $instalment $currencyCode with Pay Later',
                    style: TextStyle(
                      color: fg.withAlpha(180),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onLearnMoreTap != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onLearnMoreTap,
                child: Text(
                  'Learn more',
                  style: TextStyle(
                    color: const Color(0xFF0070BA),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFF0070BA),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Splits [amount] into 4 equal payments, rounded to 2 decimal places.
  String _calculateInstalment(String amount) {
    final value = double.tryParse(amount) ?? 0.0;
    final instalment = value / 4;
    return instalment.toStringAsFixed(2);
  }
}
