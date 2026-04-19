// Example: How to use flutter_paypal_payment

import 'package:flutter/foundation.dart';
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Shared: Initialize once
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

final paypal = FlutterPaypalPayment();

Future<void> initialize() async {
  final result = await paypal.init(
    const PaypalConfig(
      clientId: 'YOUR_PAYPAL_CLIENT_ID',
      environment: PaypalEnvironment.sandbox,
      returnUrl: 'com.example.myapp://paypalpay',
    ),
  );
  result.fold(
    (f) => debugPrint('Init error: ${f.message}'),
    (_) => debugPrint('PayPal ready'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 1: PayPal checkout with backend
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> payWithBackend() async {
  final orderId = await _createOrderOnYourServer();

  final result = await paypal.pay(
    PaymentRequest(orderId: orderId),
  );

  result.fold(
    (failure) => debugPrint('Error: ${failure.message} (${failure.code})'),
    (success) {
      debugPrint('Paid! Order: ${success.orderId}, Payer: ${success.payerId}');
    },
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 2: PayPal checkout without backend
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> payWithoutBackend() async {
  final result = await paypal.payDirect(
    clientSecret: 'YOUR_PAYPAL_CLIENT_SECRET',
    params: const PaymentParams(
      amount: '25.00',
      currencyCode: 'USD',
      description: 'Compra de producto X',
    ),
  );

  result.fold(
    (failure) => debugPrint('Error: ${failure.message} (${failure.code})'),
    (success) => debugPrint('Paid & captured! Order: ${success.orderId}'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 3: Card payment (no PayPal login)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> payWithCard() async {
  final orderId = await _createOrderOnYourServer();

  final result = await paypal.payWithCard(
    CardPaymentRequest(
      orderId: orderId,
      card: const PaymentCard(
        number: '4111111111111111',
        expirationMonth: '12',
        expirationYear: '2028',
        securityCode: '123',
      ),
    ),
  );

  result.fold(
    (failure) => debugPrint('Card error: ${failure.message} (${failure.code})'),
    (success) => debugPrint('Card paid! Order: ${success.orderId}, '
        'Status: ${success.status}, 3DS: ${success.didAttemptThreeDSecureAuthentication}'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 4: Card payment without backend
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> payWithCardDirect() async {
  final result = await paypal.payWithCardDirect(
    clientSecret: 'YOUR_PAYPAL_CLIENT_SECRET',
    params: const PaymentParams(
      amount: '50.00',
      currencyCode: 'USD',
      description: 'Card purchase',
    ),
    buildRequest: (orderId) => CardPaymentRequest(
      orderId: orderId,
      card: const PaymentCard(
        number: '4111111111111111',
        expirationMonth: '12',
        expirationYear: '2028',
        securityCode: '123',
      ),
    ),
  );

  result.fold(
    (failure) => debugPrint('Error: ${failure.message}'),
    (success) => debugPrint('Card paid & captured! Order: ${success.orderId}'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 5: Vault a PayPal account (save for future)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> vaultPaypalAccount() async {
  final setupTokenId = await _createSetupTokenOnYourServer();

  final result = await paypal.vaultPaypal(
    VaultPaypalRequest(setupTokenId: setupTokenId),
  );

  result.fold(
    (failure) => debugPrint('Vault error: ${failure.message}'),
    (success) => debugPrint('PayPal vaulted! Token: ${success.setupTokenId}, '
        'Status: ${success.status}'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 6: Vault a card (save for future)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> vaultCreditCard() async {
  final setupTokenId = await _createSetupTokenOnYourServer();

  final result = await paypal.vaultCard(
    VaultCardRequest(
      setupTokenId: setupTokenId,
      card: const PaymentCard(
        number: '4111111111111111',
        expirationMonth: '12',
        expirationYear: '2028',
        securityCode: '123',
      ),
    ),
  );

  result.fold(
    (failure) => debugPrint('Card vault error: ${failure.message}'),
    (success) => debugPrint ('Card vaulted! Token: ${success.setupTokenId}'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<String> _createOrderOnYourServer() async {
  // POST to your server -> PayPal Orders API v2 -> return order ID
  return 'MOCK_ORDER_ID';
}

Future<String> _createSetupTokenOnYourServer() async {
  // POST to your server -> PayPal Setup Tokens API -> return setup token ID
  return 'MOCK_SETUP_TOKEN_ID';
}
