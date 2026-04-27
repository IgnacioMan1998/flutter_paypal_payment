
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/paypal_utils.dart';
import '../core/validators/paypal_validation_rules.dart';
import '../domain/entities/payment_card.dart';
import 'paypal_card_form_theme.dart';

export 'paypal_card_form_theme.dart';


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
    this.onError,
    this.amount,
    this.currency,
    this.submitButtonText = 'Complete Order',
    this.requireCardholderName = false,
    this.requireBillingPostalCode = false,
    this.isLoading = false,
    this.theme,
  });

  /// Called when all fields are valid and the user taps the pay button.
  /// Receives a fully-validated [PaymentCard].
  final Future<void> Function(PaymentCard card) onSubmit;

  /// Called when [onSubmit] throws. Receives the error message.
  /// If null, errors are silently swallowed.
  final void Function(String message)? onError;

  /// Amount to display prominently in the header (e.g. "35.20"). Optional.
  final String? amount;

  /// ISO 4217 currency code shown next to [amount] (e.g. "USD"). Optional.
  final String? currency;

  /// Label for the pay button. Defaults to "Complete Order".
  final String submitButtonText;

  /// Whether the cardholder name field is required. Defaults to false.
  final bool requireCardholderName;

  /// Whether a billing postal code field is required. Defaults to false.
  final bool requireBillingPostalCode;

  /// External loading state to disable the form while a payment is in flight.
  final bool isLoading;

  /// Visual theme. Defaults to [PaypalCardFormTheme.paypal].
  final PaypalCardFormTheme? theme;

  @override
  State<PaypalCardForm> createState() => _PaypalCardFormState();
}

class _PaypalCardFormState extends State<PaypalCardForm>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  final _zipController = TextEditingController();

  final _numberFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _cvvFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _zipFocus = FocusNode();

  bool _submitting = false;
  bool _obscureCvv = true;
  _CardType _cardType = _CardType.unknown;

  bool get _busy => _submitting || widget.isLoading;

  String get _rawNumber =>
      _numberController.text.replaceAll(RegExp(r'\D'), '');

  String get _rawExpiry =>
      _expiryController.text.replaceAll(RegExp(r'\D'), '');

  @override
  void initState() {
    super.initState();
    _numberController.addListener(() {
      setState(() => _cardType = _CardTypeExt.detect(_rawNumber));
    });
  }

  @override
  void dispose() {
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    _zipController.dispose();
    _numberFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    _nameFocus.dispose();
    _zipFocus.dispose();
    super.dispose();
  }

  // ── Theme ───────────────────────────────────────

  PaypalCardFormTheme get _t => widget.theme ?? PaypalCardFormTheme.paypal;

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
    if (raw.length < 6) return 'Enter expiry as MM/YYYY';
    final month = int.tryParse(raw.substring(0, 2));
    if (month == null || month < 1 || month > 12) return 'Invalid month';
    final year = int.tryParse(raw.substring(2));
    if (year == null || year < 1000) return 'Invalid year';
    final now = DateTime.now();
    if (year < now.year || (year == now.year && month < now.month)) {
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

  String? _validateZip(String? value) {
    if (!widget.requireBillingPostalCode) return null;
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Postal code is required';
    if (v.length < 3 || v.length > 10) return 'Invalid postal code';
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
        expirationYear: raw.substring(2),
        securityCode: _cvvController.text.trim(),
        cardholderName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
      );
      await widget.onSubmit(card);
    } catch (e) {
      widget.onError?.call(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Input field ─────────────────────────────────────────

  Widget _buildField({
    Key? widgetKey,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required FormFieldValidator<String> validator,
    TextInputType keyboardType = TextInputType.number,
    TextInputAction textInputAction = TextInputAction.next,
    List<TextInputFormatter>? formatters,
    bool obscure = false,
    Widget? prefixIcon,
    Widget? suffixIcon,
    VoidCallback? onSubmitted,
  }) {
    final t = _t;
    return Semantics(
      label: label,
      textField: true,
      child: TextFormField(
        key: widgetKey,
        controller: controller,
        focusNode: focusNode,
        enabled: !_busy,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        obscureText: obscure,
        inputFormatters: formatters,
        style: TextStyle(
          color: t.inputTextColor,
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: t.inputFocusBorderColor,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: t.inputLabelColor, fontSize: 13),
          hintStyle: TextStyle(
              color: t.inputLabelColor.withValues(alpha: 0.7), fontSize: 14),
          filled: true,
          fillColor: t.inputFillColor,
          prefixIcon: prefixIcon,
          prefixIconConstraints: prefixIcon != null
              ? const BoxConstraints(minWidth: 52, minHeight: 0)
              : null,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(t.inputRadius),
            borderSide: BorderSide(color: t.inputBorderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(t.inputRadius),
            borderSide: BorderSide(color: t.inputBorderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(t.inputRadius),
            borderSide: BorderSide(color: t.inputFocusBorderColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(t.inputRadius),
            borderSide: BorderSide(color: t.errorColor),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(t.inputRadius),
            borderSide: BorderSide(color: t.errorColor, width: 1.5),
          ),
          errorStyle: TextStyle(color: t.errorColor, fontSize: 11),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        validator: validator,
        onFieldSubmitted: (_) => onSubmitted?.call(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
        color: t.backgroundColor,
        borderRadius: BorderRadius.circular(t.containerRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ──
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  if (widget.amount != null) ...[
                    Text(
                      '\$${widget.amount}',
                      style: TextStyle(
                        color: t.primaryColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.currency ?? 'USD',
                      style: TextStyle(
                        color: t.secondaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 8),
                  Divider(color: t.dividerColor, height: 1),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Section label ──
                  Text(
                    'Add debit or credit card',
                    style: TextStyle(
                      color: t.primaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Card number ──
                  _buildField(
                    widgetKey: const Key('paypal_card_number'),
                    controller: _numberController,
                    focusNode: _numberFocus,
                    label: 'Card number',
                    hint: '0000 0000 0000 0000',
                    validator: _validateNumber,
                    formatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _CardNumberFormatter(),
                    ],
                    prefixIcon: SizedBox(
                      key: const Key('paypal_card_type_icon'),
                      width: 52,
                      child: Center(child: _cardType.fieldIcon),
                    ),
                    onSubmitted: () =>
                        FocusScope.of(context).requestFocus(_expiryFocus),
                  ),
                  const SizedBox(height: 12),

                  // ── Expiry + CVV ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildField(
                          widgetKey: const Key('paypal_card_expiry'),
                          controller: _expiryController,
                          focusNode: _expiryFocus,
                          label: 'Expiry date',
                          hint: 'MM/YYYY',
                          validator: _validateExpiry,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _ExpiryFormatter(),
                          ],
                          prefixIcon: Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: t.inputLabelColor,
                          ),
                          onSubmitted: () =>
                              FocusScope.of(context).requestFocus(_cvvFocus),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          widgetKey: const Key('paypal_card_cvv'),
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
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: t.inputLabelColor,
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
                    const SizedBox(height: 12),
                    _buildField(
                      widgetKey: const Key('paypal_card_name'),
                      controller: _nameController,
                      focusNode: _nameFocus,
                      label: 'Name on card',
                      hint: 'JOHN DOE',
                      keyboardType: TextInputType.name,
                      textInputAction: widget.requireBillingPostalCode
                          ? TextInputAction.next
                          : TextInputAction.done,
                      formatters: [],
                      validator: _validateName,
                      onSubmitted: widget.requireBillingPostalCode
                          ? () => FocusScope.of(context).requestFocus(_zipFocus)
                          : _handleSubmit,
                    ),
                  ],

                  // ── Billing postal code ──
                  if (widget.requireBillingPostalCode) ...[
                    const SizedBox(height: 12),
                    _buildField(
                      widgetKey: const Key('paypal_card_zip'),
                      controller: _zipController,
                      focusNode: _zipFocus,
                      label: 'Billing postal code',
                      hint: '90210',
                      keyboardType: TextInputType.streetAddress,
                      textInputAction: TextInputAction.done,
                      formatters: [
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: _validateZip,
                      onSubmitted: _handleSubmit,
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── CTA section ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(color: t.dividerColor, height: 1),
                  const SizedBox(height: 16),

                  // Complete Order button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.buttonColor,
                        disabledBackgroundColor:
                            t.buttonColor.withValues(alpha: 0.45),
                        foregroundColor: t.buttonTextColor,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(t.buttonRadius),
                        ),
                        elevation: 0,
                      ),
                      child: _submitting
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: t.buttonTextColor,
                              ),
                            )
                          : Text(
                              widget.submitButtonText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Payment method rights link
                  GestureDetector(
                    onTap: () {},
                    child: Center(
                      child: Text(
                        'Payment method rights',
                        style: TextStyle(
                          color: t.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: t.accentColor,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Secured by PayPal footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 12, color: t.secondaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'Secured by PayPal',
                        style: TextStyle(
                          color: t.secondaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
        ),

        // ── Full-screen overlay while submitting ──
        if (_submitting)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(t.containerRadius),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
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
  Widget get fieldIcon {
    switch (this) {
      case _CardType.visa:
        return const Text(
          'VISA',
          style: TextStyle(
            color: Color(0xFF1A1F71),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        );
      case _CardType.mastercard:
        return SizedBox(
          width: 36,
          height: 22,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEB001B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF79E1B).withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      case _CardType.amex:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF006FCF),
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Text(
            'AMEX',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        );
      case _CardType.discover:
        return const Text(
          'DISC',
          style: TextStyle(
            color: Color(0xFFFF6600),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        );
      case _CardType.unknown:
        return const Icon(
          Icons.credit_card_outlined,
          size: 20,
          color: Color(0xFF6C7378),
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
    // MM/YYYY = 6 digits max
    final capped = digits.length > 6 ? digits.substring(0, 6) : digits;
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
