import 'package:flutter/material.dart';

/// A PayPal-branded "Save payment method" button for vault flows.
///
/// ```dart
/// PaypalVaultButton(
///   label: 'Save card for future payments',
///   onPressed: () async {
///     final result = await paypal.vaultCard(
///       VaultCardRequest(setupTokenId: token, card: card),
///     );
///   },
/// )
/// ```
class PaypalVaultButton extends StatefulWidget {
  const PaypalVaultButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Save payment method',
    this.width = double.infinity,
    this.height = 50.0,
    this.borderRadius = 8.0,
    this.showLockIcon = true,
  });

  /// Called when the user taps the button. Set `null` to disable.
  final VoidCallback? onPressed;

  /// Shows a loading spinner instead of the label.
  final bool isLoading;

  /// Button label. Defaults to `"Save payment method"`.
  final String label;

  /// Button width. Defaults to [double.infinity].
  final double width;

  /// Button height. Defaults to 50.
  final double height;

  /// Corner radius. Defaults to 8.
  final double borderRadius;

  /// Whether to prefix the label with a lock icon.
  final bool showLockIcon;

  @override
  State<PaypalVaultButton> createState() => _PaypalVaultButtonState();
}

class _PaypalVaultButtonState extends State<PaypalVaultButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final enabledGradient = LinearGradient(
      colors: isDark
          ? [const Color(0xFF1F2235), const Color(0xFF2D3153)]
          : [const Color(0xFF003087), const Color(0xFF0070BA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    const fg = Colors.white;
    final disabledBg =
        isDark ? const Color(0xFF2A2F4A) : const Color(0xFFB0C4D8);

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) =>
          Transform.scale(scale: _scaleAnim.value, child: child),
      child: GestureDetector(
        onTapDown: _isDisabled ? null : (_) => _pressController.forward(),
        onTapUp: _isDisabled
            ? null
            : (_) {
                _pressController.reverse();
                widget.onPressed?.call();
              },
        onTapCancel: _isDisabled ? null : () => _pressController.reverse(),
        child: Semantics(
          button: true,
          label: widget.label,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: _isDisabled ? null : enabledGradient,
              color: _isDisabled ? disabledBg : null,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: _isDisabled
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF003087).withAlpha(70),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: widget.isLoading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.showLockIcon) ...[
                        Icon(
                          Icons.lock_outline_rounded,
                          color: _isDisabled
                              ? fg.withAlpha(100)
                              : fg,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: _isDisabled ? fg.withAlpha(120) : fg,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
