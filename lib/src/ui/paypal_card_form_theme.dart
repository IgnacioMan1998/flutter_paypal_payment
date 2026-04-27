import 'package:flutter/material.dart';

/// Visual theme for [PaypalCardForm].
///
/// Use one of the built-in presets or construct a fully custom theme:
///
/// ```dart
/// PaypalCardForm(
///   theme: PaypalCardFormTheme.dark,
///   ...
/// )
/// ```
@immutable
class PaypalCardFormTheme {
  const PaypalCardFormTheme({
    required this.backgroundColor,
    required this.cardGradient,
    required this.inputFillColor,
    required this.inputBorderColor,
    required this.inputFocusBorderColor,
    required this.inputLabelColor,
    required this.inputTextColor,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.errorColor,
    required this.dividerColor,
    required this.cardTextColor,
    this.containerRadius = 20.0,
    this.inputRadius = 10.0,
    this.buttonRadius = 26.0,
  });

  /// Form container background.
  final Color backgroundColor;

  /// Gradient painted on the animated card preview.
  final Gradient cardGradient;

  /// Input field fill / background color.
  final Color inputFillColor;

  /// Input border color (unfocused).
  final Color inputBorderColor;

  /// Input border color when focused.
  final Color inputFocusBorderColor;

  /// Label and hint text color inside inputs.
  final Color inputLabelColor;

  /// Text typed into inputs.
  final Color inputTextColor;

  /// Primary text color — titles, amounts.
  final Color primaryColor;

  /// Secondary / caption text color.
  final Color secondaryColor;

  /// Accent color used for links and wordmark highlights.
  final Color accentColor;

  /// Pay button background color.
  final Color buttonColor;

  /// Pay button foreground (text / icon) color.
  final Color buttonTextColor;

  /// Validation error color.
  final Color errorColor;

  /// Divider line color.
  final Color dividerColor;

  /// Text color rendered on the card preview widget.
  final Color cardTextColor;

  /// Corner radius of the outer form container. Default 20.
  final double containerRadius;

  /// Corner radius of every input field. Default 10.
  final double inputRadius;

  /// Corner radius of the pay button. Default 26.
  final double buttonRadius;

  // ── Built-in presets ──────────────────────────────────

  /// Classic PayPal light paysheet. **Default.**
  static const PaypalCardFormTheme paypal = PaypalCardFormTheme(
    backgroundColor: Color(0xFFFFFFFF),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF003087), Color(0xFF009CDE)],
    ),
    inputFillColor: Color(0xFFF5F7FA),
    inputBorderColor: Color(0xFFCDD1D4),
    inputFocusBorderColor: Color(0xFF0070BA),
    inputLabelColor: Color(0xFF6C7378),
    inputTextColor: Color(0xFF001C64),
    primaryColor: Color(0xFF001C64),
    secondaryColor: Color(0xFF6C7378),
    accentColor: Color(0xFF009CDE),
    buttonColor: Color(0xFF003087),
    buttonTextColor: Color(0xFFFFFFFF),
    errorColor: Color(0xFFD0021B),
    dividerColor: Color(0xFFE8ECF0),
    cardTextColor: Color(0xFFFFFFFF),
  );

  /// Dark / night mode with violet accent.
  static const PaypalCardFormTheme dark = PaypalCardFormTheme(
    backgroundColor: Color(0xFF12141E),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1F2235), Color(0xFF2D3153)],
    ),
    inputFillColor: Color(0xFF1E2033),
    inputBorderColor: Color(0xFF3A3F5C),
    inputFocusBorderColor: Color(0xFF7B61FF),
    inputLabelColor: Color(0xFF7F84A8),
    inputTextColor: Color(0xFFE8EAF6),
    primaryColor: Color(0xFFE8EAF6),
    secondaryColor: Color(0xFF7F84A8),
    accentColor: Color(0xFF7B61FF),
    buttonColor: Color(0xFF7B61FF),
    buttonTextColor: Color(0xFFFFFFFF),
    errorColor: Color(0xFFFF6B6B),
    dividerColor: Color(0xFF2A2F4A),
    cardTextColor: Color(0xFFFFFFFF),
  );

  /// Aurora — deep purple to teal.
  static const PaypalCardFormTheme aurora = PaypalCardFormTheme(
    backgroundColor: Color(0xFFF3F0FF),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF5E35B1), Color(0xFF00ACC1)],
    ),
    inputFillColor: Color(0xFFFFFFFF),
    inputBorderColor: Color(0xFFCEC3EE),
    inputFocusBorderColor: Color(0xFF5E35B1),
    inputLabelColor: Color(0xFF7E57C2),
    inputTextColor: Color(0xFF311B92),
    primaryColor: Color(0xFF311B92),
    secondaryColor: Color(0xFF7E57C2),
    accentColor: Color(0xFF00ACC1),
    buttonColor: Color(0xFF5E35B1),
    buttonTextColor: Color(0xFFFFFFFF),
    errorColor: Color(0xFFE53935),
    dividerColor: Color(0xFFD8CFF5),
    cardTextColor: Color(0xFFFFFFFF),
  );

  /// Midnight gold — obsidian background with gold accents.
  static const PaypalCardFormTheme gold = PaypalCardFormTheme(
    backgroundColor: Color(0xFF0E0C0A),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1C1507), Color(0xFF3B2D0A)],
    ),
    inputFillColor: Color(0xFF1A1611),
    inputBorderColor: Color(0xFF3D3220),
    inputFocusBorderColor: Color(0xFFD4AF37),
    inputLabelColor: Color(0xFF8A7A45),
    inputTextColor: Color(0xFFE8D5A0),
    primaryColor: Color(0xFFD4AF37),
    secondaryColor: Color(0xFF8A7A45),
    accentColor: Color(0xFFD4AF37),
    buttonColor: Color(0xFFD4AF37),
    buttonTextColor: Color(0xFF0E0C0A),
    errorColor: Color(0xFFFF5555),
    dividerColor: Color(0xFF2A2310),
    cardTextColor: Color(0xFFD4AF37),
  );
}
