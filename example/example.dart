// Example: How to use paypal_checkout_flutter

import 'package:flutter/foundation.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Shared: Initialize once
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

final paypal = FlutterPaypalPayment();

Future<void> initialize() async {
  final result = await paypal.init(
    PaypalConfig(
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
    params: PaymentParams(
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
      card: PaymentCard(
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
    params: PaymentParams(
      amount: '50.00',
      currencyCode: 'USD',
      description: 'Card purchase',
    ),
    buildRequest: (orderId) => CardPaymentRequest(
      orderId: orderId,
      card: PaymentCard(
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
      card: PaymentCard(
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
// FLOW 7: Pay Later (PayPal financing)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> payLater() async {
  final orderId = await _createOrderOnYourServer();

  final result = await paypal.pay(
    PaymentRequest(
      orderId: orderId,
      fundingSource: PaypalFundingSource.payLater,
    ),
  );

  result.fold(
    (failure) => debugPrint('Pay Later error: ${failure.message}'),
    (success) => debugPrint('Pay Later done! Order: ${success.orderId}'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 8: Vault PayPal without backend
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> vaultPaypalDirect() async {
  final result = await paypal.vaultPaypalDirect(
    clientSecret: 'YOUR_PAYPAL_CLIENT_SECRET',
    customer: {'id': 'CUSTOMER_123'},
  );

  result.fold(
    (failure) => debugPrint('Vault error: ${failure.message}'),
    (success) => debugPrint('PayPal vaulted! Payment Token: $success'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 9: Vault card without backend
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> vaultCardDirect() async {
  final result = await paypal.vaultCardDirect(
    clientSecret: 'YOUR_PAYPAL_CLIENT_SECRET',
    card: PaymentCard(
      number: '4111111111111111',
      expirationMonth: '12',
      expirationYear: '2028',
      securityCode: '123',
    ),
    customer: {'id': 'CUSTOMER_123'},
  );

  result.fold(
    (failure) => debugPrint('Card vault error: ${failure.message}'),
    (success) => debugPrint('Card vaulted! Payment Token: $success'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 10: Get order details
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> checkOrderDetails() async {
  final result = await paypal.getOrderDetails(
    clientSecret: 'YOUR_PAYPAL_CLIENT_SECRET',
    orderId: 'ORDER_ID',
  );

  result.fold(
    (failure) => debugPrint('Error: ${failure.message}'),
    (order) => debugPrint('Order status: ${order['status']}, '
        'Amount: ${order['purchase_units']?[0]?['amount']}'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 11: Refund a captured payment
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> refundPayment() async {
  // Full refund
  final result = await paypal.refund(
    clientSecret: 'YOUR_PAYPAL_CLIENT_SECRET',
    captureId: 'CAPTURE_ID',
  );

  result.fold(
    (failure) => debugPrint('Refund error: ${failure.message}'),
    (refund) => debugPrint('Refunded! ID: ${refund['id']}, '
        'Status: ${refund['status']}'),
  );
}

Future<void> partialRefund() async {
  // Partial refund: refund only $5.00 of a larger capture
  final result = await paypal.refund(
    clientSecret: 'YOUR_PAYPAL_CLIENT_SECRET',
    captureId: 'CAPTURE_ID',
    amount: '5.00',
    currencyCode: 'USD',
  );

  result.fold(
    (failure) => debugPrint('Partial refund error: ${failure.message}'),
    (refund) => debugPrint('Partial refund done! ID: ${refund['id']}'),
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
