import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/paypal_utils.dart';
import '../core/validators/paypal_validation_rules.dart';
import '../domain/entities/payment_card.dart';

// ── PayPal brand colors ────────────────────────────────
const _kPaypalNavy = Color(0xFF0D1D2E);
const _kPaypalBlue = Color(0xFF0070BA);
const _kPaypalLightBlue = Color(0xFF009CDE);
const _kPaypalCardGradientStart = Color(0xFF1A3A5C);
const _kPaypalCardGradientEnd = Color(0xFF0D2137);
const _kPaypalInputBg = Color(0xFF1C3452);
const _kPaypalInputBorder = Color(0xFF2A4D73);
const _kPaypalTextPrimary = Color(0xFFFFFFFF);
const _kPaypalTextSecondary = Color(0xFF8BA8C4);
const _kPaypalDivider = Color(0xFF1E3A55);

/// A PayPal-styled card payment form.
///
/// Renders with the same dark navy aesthetic as the PayPal paysheet:
/// animated card preview (flips to show CVV on back), PayPal branding,
/// and a prominent CTA button.
///
/// Example:
/// ```dart
/// PaypalCardForm(
///   amount: '35.20',
///   currency: 'USD',
///   onSubmit: (card) async {
///     final result = await paypal.payWithCard(
///       CardPaymentRequest(orderId: myOrderId, card: card),
///     );
///     result.fold(
///       (err) => showError(err.message),
///       (ok)  => showSuccess(ok.orderId),
///     );
///   },
/// )
/// ```
class PaypalCardForm extends StatefulWidget {
  const PaypalCardForm({
    super.key,
    required this.onSubmit,
    this.amount,
    this.currency,
    this.submitButtonText = 'Complete Order',
    this.requireCardholderName = false,
    this.isLoading = false,
  });

  /// Called when all fields are valid and the user taps the pay button.
  /// Receives a fully-validated [PaymentCard].
  final Future<void> Function(PaymentCard card) onSubmit;

  /// Amount to display prominently in the header (e.g. "35.20"). Optional.
  final String? amount;

  /// ISO 4217 currency code shown next to [amount] (e.g. "USD"). Optional.
  final String? currency;

  /// Label for the pay button. Defaults to "Complete Order".
  final String submitButtonText;

  /// Whether the cardholder name field is required. Defaults to false.
  final bool requireCardholderName;

  /// External loading state to disable the form while a payment is in flight.
  final bool isLoading;

  @override
  State<PaypalCardForm> createState() => _PaypalCardFormState();
}

class _PaypalCardFormState extends State<PaypalCardForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  final _numberFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _cvvFocus = FocusNode();
  final _nameFocus = FocusNode();

  bool _submitting = false;
  bool _obscureCvv = true;
  _CardType _cardType = _CardType.unknown;

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _showingBack = false;

  bool get _busy => _submitting || widget.isLoading;

  String get _rawNumber =>
      _numberController.text.replaceAll(RegExp(r'\D'), '');

  String get _rawExpiry =>
      _expiryController.text.replaceAll(RegExp(r'\D'), '');

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _cvvFocus.addListener(() {
      if (_cvvFocus.hasFocus && !_showingBack) {
        _showingBack = true;
        _flipController.forward();
      } else if (!_cvvFocus.hasFocus && _showingBack) {
        _showingBack = false;
        _flipController.reverse();
      }
    });

    _numberController.addListener(() {
      setState(() => _cardType = _CardTypeExt.detect(_rawNumber));
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    _numberFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  // ── Validators ─────────────────────────────────────────

  String? _validateNumber(String? _) {
    final raw = _rawNumber;
    if (raw.isEmpty) return 'Card number is required';
    if (!PaypalValidationRules.cardNumberPattern.hasMatch(raw)) {
      return 'Enter a valid card number (13–19 digits)';
    }
    if (!PaypalUtils.luhnCheck(raw)) return 'Invalid card number';
    return null;
  }

  String? _validateExpiry(String? _) {
    final raw = _rawExpiry;
    if (raw.length < 4) return 'Enter expiry as MM/YY';
    final month = int.tryParse(raw.substring(0, 2));
    if (month == null || month < 1 || month > 12) return 'Invalid month';
    final yearShort = int.tryParse(raw.substring(2, 4));
    if (yearShort == null) return 'Invalid year';
    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;
    if (yearShort < currentYear ||
        (yearShort == currentYear && month < currentMonth)) {
      return 'Card has expired';
    }
    return null;
  }

  String? _validateCvv(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'CVV is required';
    if (!PaypalValidationRules.securityCodePattern.hasMatch(v)) {
      return '3 or 4 digits';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (!widget.requireCardholderName) return null;
    if (value == null || value.trim().isEmpty) return 'Name is required';
    return null;
  }

  // ── Submit ──────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_busy) return;
    setState(() => _submitting = true);
    try {
      final raw = _rawExpiry;
      final card = PaymentCard(
        number: _rawNumber,
        expirationMonth: raw.substring(0, 2),
        expirationYear: '20${raw.substring(2, 4)}',
        securityCode: _cvvController.text.trim(),
        cardholderName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
      );
      await widget.onSubmit(card);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Card preview ────────────────────────────────────────

  Widget _buildCardPreview() {
    final number = _rawNumber.isEmpty
        ? '•••• •••• •••• ••••'
        : _numberController.text.padRight(19, ' ');
    final expiry =
        _expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text;

    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, _) {
        final angle = _flipAnimation.value * 3.14159;
        final showBack = _flipAnimation.value > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(3.14159),
                  child: _buildCardBack(),
                )
              : _buildCardFront(number, expiry),
        );
      },
    );
  }

  Widget _buildCardFront(String number, String expiry) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPaypalCardGradientStart, _kPaypalCardGradientEnd],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A017),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              _cardType.logo,
            ],
          ),
          const Spacer(),
          Text(
            number,
            style: const TextStyle(
              color: _kPaypalTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VALID THRU',
                    style: TextStyle(
                      color: _kPaypalTextSecondary,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    expiry,
                    style: const TextStyle(
                      color: _kPaypalTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (widget.requireCardholderName &&
                  _nameController.text.isNotEmpty)
                Text(
                  _nameController.text.toUpperCase(),
                  style: const TextStyle(
                    color: _kPaypalTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPaypalCardGradientStart, _kPaypalCardGradientEnd],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Container(height: 40, color: Colors.black54),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Container(height: 36, color: const Color(0xFFE8E8E8)),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 56,
                  height: 36,
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: Text(
                    _cvvController.text.isEmpty
                        ? '•••'
                        : '•' * _cvvController.text.length,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Input field ─────────────────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required FormFieldValidator<String> validator,
    TextInputType keyboardType = TextInputType.number,
    TextInputAction textInputAction = TextInputAction.next,
    List<TextInputFormatter>? formatters,
    bool obscure = false,
    Widget? suffixIcon,
    VoidCallback? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: !_busy,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscure,
      inputFormatters: formatters,
      style: const TextStyle(color: _kPaypalTextPrimary, fontSize: 15),
      cursorColor: _kPaypalLightBlue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: _kPaypalTextSecondary, fontSize: 13),
        hintStyle:
            TextStyle(color: _kPaypalTextSecondary.withOpacity(0.5), fontSize: 14),
        filled: true,
        fillColor: _kPaypalInputBg,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPaypalInputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPaypalInputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPaypalLightBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 11),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
      onFieldSubmitted: (_) => onSubmitted?.call(),
    );
  }

  // ── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kPaypalNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _kPaypalDivider)),
              ),
              child: Row(
                children: [
                  const _PaypalLogo(),
                  const Spacer(),
                  if (widget.amount != null)
                    Text(
                      '${widget.currency ?? 'USD'} ${widget.amount}',
                      style: const TextStyle(
                        color: _kPaypalTextPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Card preview ──
                  _buildCardPreview(),
                  const SizedBox(height: 24),

                  // ── Card number ──
                  _buildField(
                    controller: _numberController,
                    focusNode: _numberFocus,
                    label: 'Card number',
                    hint: '0000 0000 0000 0000',
                    validator: _validateNumber,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _CardNumberFormatter(),
                    ],
                    onSubmitted: () =>
                        FocusScope.of(context).requestFocus(_expiryFocus),
                  ),
                  const SizedBox(height: 14),

                  // ── Expiry + CVV ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _expiryController,
                          focusNode: _expiryFocus,
                          label: 'Expiry',
                          hint: 'MM/YY',
                          validator: _validateExpiry,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _ExpiryFormatter(),
                          ],
                          onSubmitted: () =>
                              FocusScope.of(context).requestFocus(_cvvFocus),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: _cvvController,
                          focusNode: _cvvFocus,
                          label: 'CVV',
                          hint: '•••',
                          validator: _validateCvv,
                          obscure: _obscureCvv,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCvv
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 18,
                              color: _kPaypalTextSecondary,
                            ),
                            onPressed: () =>
                                setState(() => _obscureCvv = !_obscureCvv),
                          ),
                          textInputAction: widget.requireCardholderName
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onSubmitted: widget.requireCardholderName
                              ? () => FocusScope.of(context)
                                  .requestFocus(_nameFocus)
                              : _handleSubmit,
                        ),
                      ),
                    ],
                  ),

                  // ── Cardholder name ──
                  if (widget.requireCardholderName) ...[
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      label: 'Cardholder name',
                      hint: 'Name on card',
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.done,
                      formatters: [],
                      validator: _validateName,
                      onSubmitted: _handleSubmit,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── CTA Button ──
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPaypalBlue,
                        disabledBackgroundColor: _kPaypalBlue.withOpacity(0.5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.submitButtonText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Footer ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock,
                        size: 12,
                        color: _kPaypalTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Secured by PayPal',
                        style: TextStyle(
                          color: _kPaypalTextSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PayPal Logo widget ──────────────────────────────────

class _PaypalLogo extends StatelessWidget {
  const _PaypalLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text(
          'Pay',
          style: TextStyle(
            color: Color(0xFF009CDE),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          'Pal',
          style: TextStyle(
            color: Color(0xFF003087),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ── Card type detection ─────────────────────────────────

enum _CardType { visa, mastercard, amex, discover, unknown }

class _CardTypeExt {
  static _CardType detect(String number) {
    if (number.startsWith('4')) return _CardType.visa;
    if (RegExp(r'^5[1-5]').hasMatch(number) ||
        RegExp(r'^2(2[2-9][1-9]|[3-6]\d{2}|7[01]\d|720)').hasMatch(number)) {
      return _CardType.mastercard;
    }
    if (RegExp(r'^3[47]').hasMatch(number)) return _CardType.amex;
    if (RegExp(r'^6(011|22[1-9]|4[4-9]|5)').hasMatch(number)) {
      return _CardType.discover;
    }
    return _CardType.unknown;
  }
}

extension _CardTypeLogoExt on _CardType {
  Widget get logo {
    switch (this) {
      case _CardType.visa:
        return const Text(
          'VISA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: 1,
          ),
        );
      case _CardType.mastercard:
        return SizedBox(
          width: 44,
          height: 28,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEB001B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF79E1B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      case _CardType.amex:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'AMEX',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        );
      case _CardType.discover:
        return const Text(
          'DISCOVER',
          style: TextStyle(
            color: Color(0xFFFF6600),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        );
      case _CardType.unknown:
        return Icon(
          Icons.credit_card,
          color: Colors.white.withOpacity(0.4),
          size: 28,
        );
    }
  }
}

// ── Input formatters ────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 19 ? digits.substring(0, 19) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(capped[i]);
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 4 ? digits.substring(0, 4) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(capped[i]);
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
