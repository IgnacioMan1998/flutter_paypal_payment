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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 12: Authorize & Capture (two-step payments)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> authorizeAndCapture() async {
  // Step 1: Authorize order (hold funds)
  final authResult = await paypal.authorizeOrder(
    clientSecret: 'YOUR_PAYPAL_CLIENT_SECRET',
    orderId: 'ORDER_ID',
  );

  authResult.fold(
    (failure) => debugPrint('Auth error: ${failure.message}'),
    (auth) async {
      final authId = auth['purchase_units']?[0]?['payments']?['authorizations']
          ?[0]?['id'] as String?;
      debugPrint('Authorized! ID: $authId');

      // Step 2: Capture the authorization later
      if (authId != null) {
        final captureResult = await paypal.captureAuthorization(
          clientSecret: 'YOUR_PAYPAL_CLIENT_SECRET',
          authorizationId: authId,
        );
        captureResult.fold(
          (f) => debugPrint('Capture error: ${f.message}'),
          (c) => debugPrint('Captured! ID: ${c['id']}'),
        );
      }
    },
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 13: Update order (shipping/tracking)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> updateOrderTracking() async {
  final result = await paypal.updateOrder(
    clientSecret: 'YOUR_PAYPAL_CLIENT_SECRET',
    orderId: 'ORDER_ID',
    patchOperations: [
      {
        'op': 'add',
        'path':
            '/purchase_units/@reference_id==\'default\'/shipping/trackers',
        'value': [
          {
            'carrier': 'FEDEX',
            'tracking_number': '1234567890',
            'status': 'SHIPPED',
          }
        ],
      }
    ],
  );

  result.fold(
    (failure) => debugPrint('Update error: ${failure.message}'),
    (_) => debugPrint('Order updated with tracking!'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 14: Create product + plan + subscription (full)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> createFullSubscription() async {
  const secret = 'YOUR_PAYPAL_CLIENT_SECRET';

  // Step 1: Create a product
  final productResult = await paypal.createProduct(
    clientSecret: secret,
    product: {
      'name': 'Premium Plan',
      'description': 'Access to all premium features',
      'type': 'SERVICE',
      'category': 'SOFTWARE',
    },
  );

  final productId = productResult.fold(
    (f) {
      debugPrint('Product error: ${f.message}');
      return null;
    },
    (product) {
      debugPrint('Product created: ${product['id']}');
      return product['id'] as String;
    },
  );
  if (productId == null) return;

  // Step 2: Create a billing plan
  final planResult = await paypal.createPlan(
    clientSecret: secret,
    plan: {
      'product_id': productId,
      'name': 'Monthly Premium',
      'billing_cycles': [
        {
          'frequency': {'interval_unit': 'MONTH', 'interval_count': 1},
          'tenure_type': 'REGULAR',
          'sequence': 1,
          'total_cycles': 0,
          'pricing_scheme': {
            'fixed_price': {'value': '9.99', 'currency_code': 'USD'},
          },
        }
      ],
      'payment_preferences': {
        'auto_bill_outstanding': true,
        'payment_failure_threshold': 3,
      },
    },
  );

  final planId = planResult.fold(
    (f) {
      debugPrint('Plan error: ${f.message}');
      return null;
    },
    (plan) {
      debugPrint('Plan created: ${plan['id']}');
      return plan['id'] as String;
    },
  );
  if (planId == null) return;

  // Step 3: Create a subscription
  final subResult = await paypal.createSubscription(
    clientSecret: secret,
    subscription: {
      'plan_id': planId,
      'subscriber': {
        'name': {'given_name': 'John', 'surname': 'Doe'},
        'email_address': 'john@example.com',
      },
      'application_context': {
        'return_url': 'https://example.com/return',
        'cancel_url': 'https://example.com/cancel',
      },
    },
  );

  subResult.fold(
    (f) => debugPrint('Subscription error: ${f.message}'),
    (sub) => debugPrint(
        'Subscription created: ${sub['id']}, Status: ${sub['status']}'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 15: List & manage products
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> manageProducts() async {
  const secret = 'YOUR_PAYPAL_CLIENT_SECRET';

  // List all products
  final listResult = await paypal.listProducts(
    clientSecret: secret,
    pageSize: 10,
    totalRequired: true,
  );

  listResult.fold(
    (f) => debugPrint('List error: ${f.message}'),
    (data) {
      final products = data['products'] as List;
      debugPrint('Total products: ${data['total_items']}');
      for (final p in products) {
        debugPrint('  ${p['id']}: ${p['name']}');
      }
    },
  );

  // Get product details
  final detailResult = await paypal.getProductDetails(
    clientSecret: secret,
    productId: 'PROD-XXXX',
  );

  detailResult.fold(
    (f) => debugPrint('Detail error: ${f.message}'),
    (product) => debugPrint('Product: ${product['name']} (${product['type']})'),
  );

  // Update product description
  final updateResult = await paypal.updateProduct(
    clientSecret: secret,
    productId: 'PROD-XXXX',
    patchOperations: [
      {'op': 'replace', 'path': '/description', 'value': 'Updated desc'},
    ],
  );

  updateResult.fold(
    (f) => debugPrint('Update error: ${f.message}'),
    (_) => debugPrint('Product updated!'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 16: List & manage plans
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> managePlans() async {
  const secret = 'YOUR_PAYPAL_CLIENT_SECRET';

  // List plans for a product
  final listResult = await paypal.listPlans(
    clientSecret: secret,
    productId: 'PROD-XXXX',
    pageSize: 10,
  );

  listResult.fold(
    (f) => debugPrint('List error: ${f.message}'),
    (data) {
      final plans = data['plans'] as List;
      for (final p in plans) {
        debugPrint('  ${p['id']}: ${p['name']} (${p['status']})');
      }
    },
  );

  // Update plan pricing
  final priceResult = await paypal.updatePlanPricing(
    clientSecret: secret,
    planId: 'P-XXXX',
    pricingSchemes: [
      {
        'billing_cycle_sequence': 1,
        'pricing_scheme': {
          'fixed_price': {'value': '14.99', 'currency_code': 'USD'},
        },
      }
    ],
  );

  priceResult.fold(
    (f) => debugPrint('Price update error: ${f.message}'),
    (_) => debugPrint('Plan pricing updated!'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 17: Subscription lifecycle
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> manageSubscription() async {
  const secret = 'YOUR_PAYPAL_CLIENT_SECRET';
  const subId = 'I-XXXX';

  // List active subscriptions
  final listResult = await paypal.listSubscriptions(
    clientSecret: secret,
    statuses: 'ACTIVE',
    pageSize: 20,
  );

  listResult.fold(
    (f) => debugPrint('List error: ${f.message}'),
    (data) {
      final subs = data['subscriptions'] as List;
      debugPrint('Active subscriptions: ${subs.length}');
    },
  );

  // Suspend a subscription
  final suspendResult = await paypal.suspendSubscription(
    clientSecret: secret,
    subscriptionId: subId,
    reason: 'Customer requested pause',
  );

  suspendResult.fold(
    (f) => debugPrint('Suspend error: ${f.message}'),
    (_) => debugPrint('Subscription suspended!'),
  );

  // Reactivate
  final activateResult = await paypal.activateSubscription(
    clientSecret: secret,
    subscriptionId: subId,
    reason: 'Customer wants to resume',
  );

  activateResult.fold(
    (f) => debugPrint('Activate error: ${f.message}'),
    (_) => debugPrint('Subscription reactivated!'),
  );

  // Revise subscription (change plan)
  final reviseResult = await paypal.reviseSubscription(
    clientSecret: secret,
    subscriptionId: subId,
    revisionDetails: {'plan_id': 'P-NEW-PLAN'},
  );

  reviseResult.fold(
    (f) => debugPrint('Revise error: ${f.message}'),
    (data) => debugPrint('Revision link: ${data['links']}'),
  );

  // Cancel
  final cancelResult = await paypal.cancelSubscription(
    clientSecret: secret,
    subscriptionId: subId,
    reason: 'Customer requested cancellation',
  );

  cancelResult.fold(
    (f) => debugPrint('Cancel error: ${f.message}'),
    (_) => debugPrint('Subscription cancelled.'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 18: Capture outstanding payment
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> captureOutstandingPayment() async {
  final result = await paypal.captureSubscriptionPayment(
    clientSecret: 'YOUR_PAYPAL_CLIENT_SECRET',
    subscriptionId: 'I-XXXX',
    captureRequest: {
      'note': 'Charging outstanding balance',
      'capture_type': 'OUTSTANDING_BALANCE',
      'amount': {'currency_code': 'USD', 'value': '10.00'},
    },
  );

  result.fold(
    (f) => debugPrint('Capture error: ${f.message}'),
    (data) => debugPrint('Payment captured! $data'),
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 19: List subscription transactions
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> listTransactions() async {
  final result = await paypal.listSubscriptionTransactions(
    clientSecret: 'YOUR_PAYPAL_CLIENT_SECRET',
    subscriptionId: 'I-XXXX',
    startTime: '2026-01-01T00:00:00Z',
    endTime: '2026-04-18T23:59:59Z',
  );

  result.fold(
    (f) => debugPrint('Error: ${f.message}'),
    (data) {
      final txns = data['transactions'] as List;
      debugPrint('Transactions: ${txns.length}');
      for (final txn in txns) {
        debugPrint('  ${txn['id']}: ${txn['status']} — '
            '${txn['amount_with_breakdown']?['gross_amount']}');
      }
    },
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FLOW 20: Use PaypalSubscriptionService directly
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> useServiceDirectly() async {
  final service = PaypalSubscriptionService(
    config: PaypalConfig(
      clientId: 'YOUR_PAYPAL_CLIENT_ID',
      environment: PaypalEnvironment.sandbox,
      returnUrl: 'com.example.myapp://paypalpay',
    ),
    clientSecret: 'YOUR_PAYPAL_CLIENT_SECRET',
  );

  try {
    // These plan lifecycle methods are only available via the service
    await service.updatePlan(
      'P-XXXX',
      patchOperations: [
        {'op': 'replace', 'path': '/description', 'value': 'Updated plan'},
      ],
    );

    await service.activatePlan('P-XXXX');
    debugPrint('Plan activated!');

    await service.deactivatePlan('P-XXXX');
    debugPrint('Plan deactivated!');
  } finally {
    service.dispose();
  }
}
