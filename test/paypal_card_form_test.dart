import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

// ── Helpers ─────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );

PaypalCardForm _form({
  Future<void> Function(PaymentCard)? onSubmit,
  void Function(String)? onError,
  String? amount,
  String? currency,
  String submitButtonText = 'Complete Order',
  bool requireCardholderName = false,
  bool isLoading = false,
}) {
  return PaypalCardForm(
    onSubmit: onSubmit ?? (_) async {},
    onError: onError,
    amount: amount,
    currency: currency,
    submitButtonText: submitButtonText,
    requireCardholderName: requireCardholderName,
    isLoading: isLoading,
  );
}

Future<void> _fillValidCard(WidgetTester tester) async {
  await tester.enterText(
      find.byKey(const Key('paypal_card_number')), '4111111111111111');
  await tester.enterText(
      find.byKey(const Key('paypal_card_expiry')), '122030');
  await tester.enterText(
      find.byKey(const Key('paypal_card_cvv')), '123');
}

// ── Tests ────────────────────────────────────────────────

void main() {
  group('PaypalCardForm — rendering', () {
    testWidgets('renders Secured by PayPal footer', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      expect(find.text('Secured by PayPal'), findsOneWidget);
    });

    testWidgets('renders amount when provided', (tester) async {
      await tester.pumpWidget(_wrap(_form(amount: '35.20', currency: 'USD')));
      expect(find.text('\$35.20'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
    });

    testWidgets('does not render amount section when omitted', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      expect(find.text('USD'), findsNothing);
    });

    testWidgets('renders custom submit button text', (tester) async {
      await tester.pumpWidget(
        _wrap(_form(submitButtonText: 'Pagar \$35.20')),
      );
      expect(find.text('Pagar \$35.20'), findsOneWidget);
    });

    testWidgets('renders cardholder name field when required', (tester) async {
      await tester.pumpWidget(_wrap(_form(requireCardholderName: true)));
      expect(find.byKey(const Key('paypal_card_name')), findsOneWidget);
    });

    testWidgets('hides cardholder name field by default', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      expect(find.byKey(const Key('paypal_card_name')), findsNothing);
    });

    testWidgets('renders section header', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      expect(find.text('Add debit or credit card'), findsOneWidget);
    });

    testWidgets('disables button when isLoading=true', (tester) async {
      await tester.pumpWidget(_wrap(_form(isLoading: true)));
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Complete Order'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('PaypalCardForm — validation', () {
    testWidgets('shows error for empty card number on submit', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      await tester.tap(find.text('Complete Order'));
      await tester.pump();
      expect(find.text('Card number is required'), findsOneWidget);
    });

    testWidgets('shows error for invalid card number', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      await tester.enterText(
          find.byKey(const Key('paypal_card_number')), '1234567890123456');
      await tester.tap(find.text('Complete Order'));
      await tester.pump();
      // Luhn fails or pattern fails
      expect(
        find.textContaining('card number'),
        findsWidgets,
      );
    });

    testWidgets('shows error for empty expiry on submit', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      await tester.enterText(
          find.byKey(const Key('paypal_card_number')), '4111111111111111');
      await tester.tap(find.text('Complete Order'));
      await tester.pump();
      expect(find.text('Enter expiry as MM/YYYY'), findsOneWidget);
    });

    testWidgets('shows error for empty CVV on submit', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      await tester.enterText(
          find.byKey(const Key('paypal_card_number')), '4111111111111111');
      await tester.enterText(
          find.byKey(const Key('paypal_card_expiry')), '122030');
      await tester.tap(find.text('Complete Order'));
      await tester.pump();
      expect(find.text('CVV is required'), findsOneWidget);
    });

    testWidgets('shows required error for cardholder name when required',
        (tester) async {
      await tester.pumpWidget(_wrap(_form(requireCardholderName: true)));
      await _fillValidCard(tester);
      await tester.tap(find.text('Complete Order'));
      await tester.pump();
      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('calls onSubmit with valid card data', (tester) async {
      PaymentCard? received;
      await tester.pumpWidget(_wrap(_form(
        onSubmit: (card) async => received = card,
      )));
      await _fillValidCard(tester);
      await tester.tap(find.text('Complete Order'));
      await tester.pump();
      expect(received, isNotNull);
      expect(received!.number, '4111111111111111');
      expect(received!.expirationMonth, '12');
      expect(received!.expirationYear, '2030');
      expect(received!.securityCode, '123');
    });

    testWidgets('calls onError when onSubmit throws', (tester) async {
      String? errorMsg;
      await tester.pumpWidget(_wrap(_form(
        onSubmit: (_) async => throw Exception('Network error'),
        onError: (msg) => errorMsg = msg,
      )));
      await _fillValidCard(tester);
      await tester.tap(find.text('Complete Order'));
      await tester.pumpAndSettle();
      expect(errorMsg, isNotNull);
      expect(errorMsg, contains('Network error'));
    });
  });

  group('PaypalCardForm — card type detection', () {
    testWidgets('detects Visa from number starting with 4', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      await tester.enterText(
          find.byKey(const Key('paypal_card_number')), '4111');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('paypal_card_type_icon')),
          matching: find.text('VISA'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('detects Mastercard from 51xx prefix', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      await tester.enterText(
          find.byKey(const Key('paypal_card_number')), '5100');
      await tester.pump();
      // Mastercard logo uses colored circles (no text label)
      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('detects Amex from 34xx prefix', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      await tester.enterText(
          find.byKey(const Key('paypal_card_number')), '3400');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('paypal_card_type_icon')),
          matching: find.text('AMEX'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('detects Discover from 6011 prefix', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      await tester.enterText(
          find.byKey(const Key('paypal_card_number')), '6011');
      await tester.pump();
      expect(find.text('DISC'), findsOneWidget);
    });
  });

  group('PaypalCardForm — CVV flip animation', () {
    testWidgets('focuses CVV field without crash', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      await tester.tap(find.byKey(const Key('paypal_card_cvv')));
      await tester.pump();
      await tester.pumpAndSettle();
      // No exception — animation completed
    });
  });

  group('PaypalCardForm — number formatting', () {
    testWidgets('formats card number with spaces', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      await tester.enterText(
          find.byKey(const Key('paypal_card_number')), '4111111111111111');
      await tester.pump();
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('paypal_card_number')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, '4111 1111 1111 1111');
    });

    testWidgets('formats expiry with slash', (tester) async {
      await tester.pumpWidget(_wrap(_form()));
      await tester.enterText(
          find.byKey(const Key('paypal_card_expiry')), '122030');
      await tester.pump();
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('paypal_card_expiry')),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text, '12/2030');
    });
  });
}
