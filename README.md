# paypal_checkout_flutter

[![pub package](https://img.shields.io/pub/v/paypal_checkout_flutter.svg)](https://pub.dev/packages/paypal_checkout_flutter)
[![License: BSD-3](https://img.shields.io/badge/License-BSD--3-blue.svg)](LICENSE)

A complete Flutter package for PayPal payments using the **native PayPal Mobile SDK** (Android v2.3.0 / iOS v2.0.1). Type-safe Dart ↔ Kotlin/Swift communication via [Pigeon](https://pub.dev/packages/pigeon).

> **No WebView.** Opens the system browser or processes cards directly with the native SDK.

## Features

### Native SDK (Pigeon)

| Feature                      | Method                | Backend required |
| ---------------------------- | --------------------- | ---------------- |
| PayPal Checkout              | `pay()`               | Yes              |
| PayPal Checkout (no backend) | `payDirect()`         | No               |
| Pay Later (financing)        | `pay()` + `payLater`  | Yes              |
| Card payment                 | `payWithCard()`       | Yes              |
| Card payment (no backend)    | `payWithCardDirect()` | No               |
| Vault PayPal account         | `vaultPaypal()`       | Yes              |
| Vault card                   | `vaultCard()`         | Yes              |
| Vault PayPal (no backend)    | `vaultPaypalDirect()` | No               |
| Vault card (no backend)      | `vaultCardDirect()`   | No               |

### REST API — Orders & Payments

| Endpoint              | Method                   |
| --------------------- | ------------------------ |
| Create order          | `createOrder()`\*        |
| Get order details     | `getOrderDetails()`      |
| Update order (PATCH)  | `updateOrder()`          |
| Capture order         | `captureOrder()`\*       |
| Authorize order       | `authorizeOrder()`       |
| Capture authorization | `captureAuthorization()` |
| Void authorization    | `voidAuthorization()`    |
| Refund capture        | `refund()`               |

### REST API — Catalog Products (4/4 endpoints)

| Endpoint             | Method                |
| -------------------- | --------------------- |
| Create product       | `createProduct()`     |
| List products        | `listProducts()`      |
| Show product details | `getProductDetails()` |
| Update product       | `updateProduct()`     |

### REST API — Billing Plans (7/7 endpoints)

| Endpoint               | Method                 |
| ---------------------- | ---------------------- |
| Create plan            | `createPlan()`         |
| List plans             | `listPlans()`          |
| Show plan details      | `getPlanDetails()`     |
| Update plan            | `updatePlan()`\*\*     |
| Activate plan          | `activatePlan()`\*\*   |
| Deactivate plan        | `deactivatePlan()`\*\* |
| Update pricing schemes | `updatePlanPricing()`  |

### REST API — Subscriptions (10/10 endpoints)

| Endpoint                  | Method                           |
| ------------------------- | -------------------------------- |
| Create subscription       | `createSubscription()`           |
| Show subscription details | `getSubscriptionDetails()`       |
| List subscriptions        | `listSubscriptions()`            |
| Update subscription       | `updateSubscription()`           |
| Revise subscription       | `reviseSubscription()`           |
| Activate subscription     | `activateSubscription()`         |
| Suspend subscription      | `suspendSubscription()`          |
| Cancel subscription       | `cancelSubscription()`           |
| Capture payment           | `captureSubscriptionPayment()`   |
| List transactions         | `listSubscriptionTransactions()` |

\* Available via `PaypalOrderService` and internally used by `payDirect()`/`payWithCardDirect()`.
\*\* Available via `PaypalSubscriptionService` directly.

- Full **3D Secure** support for card payments
- Clean architecture: entities, repositories, mappers
- `Either<Failure, Success>` with [dartz](https://pub.dev/packages/dartz) for error handling
- **177 unit tests** with full coverage (257 as of v0.2.0)

## Requirements

- **Android**: `minSdk 23`, `compileSdk 34`, Java 17
- **iOS**: iOS 16.0+
- **Flutter**: `>=1.17.0`
- A PayPal app ([developer.paypal.com](https://developer.paypal.com))

## Installation

```yaml
dependencies:
  paypal_checkout_flutter: ^0.2.0
```

### Android Setup

Add the deep link intent filter in your `AndroidManifest.xml`:

```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTop">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.example.myapp" android:host="paypalpay" />
    </intent-filter>
</activity>
```

## Quick Start

### Initialize (once at app startup)

```dart
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

final paypal = FlutterPaypalPayment();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await paypal.init(PaypalConfig(
    clientId: 'YOUR_CLIENT_ID',
    environment: PaypalEnvironment.sandbox,
    returnUrl: 'com.example.myapp://paypalpay',
  ));

  runApp(MyApp());
}
```

## Usage Examples

### 1. PayPal Checkout (with backend)

Your server creates the order via PayPal Orders API and returns the `orderId`.

```dart
final result = await paypal.pay(
  PaymentRequest(orderId: 'ORDER_ID_FROM_BACKEND'),
);

result.fold(
  (failure) => print('Error: ${failure.message}'),
  (success) => print('Paid! Order: ${success.orderId}'),
);
```

### 2. PayPal Checkout (no backend)

Creates the order, opens checkout, and captures — all from Flutter.

> **Note:** Requires your `clientSecret`. Not recommended for production.

```dart
final result = await paypal.payDirect(
  clientSecret: 'YOUR_SECRET',
  params: PaymentParams(
    amount: '25.00',
    currencyCode: 'USD',
    description: 'Product X purchase',
  ),
);
```

### 3. Card Payment

Charge a card directly without PayPal login. Supports 3D Secure automatically.

```dart
final result = await paypal.payWithCard(
  CardPaymentRequest(
    orderId: 'ORDER_ID',
    card: PaymentCard(
      number: '4111111111111111',
      expirationMonth: '12',
      expirationYear: '2028',
      securityCode: '123',
    ),
  ),
);
```

### 3b. PaypalCardForm Widget

Drop-in PayPal-styled card form. Shows animated 3D card preview, auto-detects card network (Visa, Mastercard, Amex, Discover), and validates all fields client-side before calling `onSubmit`.

```dart
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (ctx) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(ctx).viewInsets.bottom,
    ),
    child: SingleChildScrollView(
      child: PaypalCardForm(
        amount: '35.20',
        currency: 'USD',
        submitButtonText: 'Pay \$35.20',
        requireCardholderName: false,   // optional name field
        requireBillingPostalCode: false, // optional ZIP field
        onSubmit: (card) async {
          Navigator.of(ctx).pop();
          final result = await paypal.payWithCard(
            CardPaymentRequest(orderId: 'ORDER_ID', card: card),
          );
          result.fold(
            (err) => showError(err.message),
            (ok)  => showSuccess(ok.orderId),
          );
        },
        onError: (message) => showError(message),
      ),
    ),
  ),
);
```

### 4. Pay Later (Financing)

```dart
final result = await paypal.pay(
  PaymentRequest(
    orderId: 'ORDER_ID',
    fundingSource: PaypalFundingSource.payLater,
  ),
);
```

### 5. Vault: Save PayPal Account

```dart
final result = await paypal.vaultPaypal(
  VaultPaypalRequest(setupTokenId: 'SETUP_TOKEN_FROM_BACKEND'),
);
```

### 6. Vault: Save Card

```dart
final result = await paypal.vaultCard(
  VaultCardRequest(
    setupTokenId: 'SETUP_TOKEN_FROM_BACKEND',
    card: PaymentCard(
      number: '4111111111111111',
      expirationMonth: '12',
      expirationYear: '2028',
      securityCode: '123',
    ),
  ),
);
```

### 7. Refund (Total or Partial)

```dart
// Full refund
final result = await paypal.refund(
  clientSecret: 'YOUR_SECRET',
  captureId: 'CAPTURE_ID',
);

// Partial refund ($5.00)
final partial = await paypal.refund(
  clientSecret: 'YOUR_SECRET',
  captureId: 'CAPTURE_ID',
  amount: '5.00',
  currencyCode: 'USD',
);
```

### 8. Order Authorization Flow

```dart
// Authorize (hold funds)
final auth = await paypal.authorizeOrder(
  clientSecret: 'YOUR_SECRET',
  orderId: 'ORDER_ID',
);

// Capture later
final capture = await paypal.captureAuthorization(
  clientSecret: 'YOUR_SECRET',
  authorizationId: 'AUTH_ID',
);

// Or void
final voided = await paypal.voidAuthorization(
  clientSecret: 'YOUR_SECRET',
  authorizationId: 'AUTH_ID',
);
```

### 9. Update Order (Shipping/Tracking)

```dart
final result = await paypal.updateOrder(
  clientSecret: 'YOUR_SECRET',
  orderId: 'ORDER_ID',
  patchOperations: [
    {
      'op': 'add',
      'path': '/purchase_units/@reference_id==\'default\'/shipping/trackers',
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
```

---

## Subscriptions API

### 10. Create a Product

```dart
final result = await paypal.createProduct(
  clientSecret: 'YOUR_SECRET',
  product: {
    'name': 'Premium Plan',
    'description': 'Access to all features',
    'type': 'SERVICE',
    'category': 'SOFTWARE',
  },
);

result.fold(
  (failure) => print('Error: ${failure.message}'),
  (product) => print('Product created: ${product['id']}'),
);
```

### 11. List Products

```dart
final result = await paypal.listProducts(
  clientSecret: 'YOUR_SECRET',
  pageSize: 10,
  page: 1,
  totalRequired: true,
);

result.fold(
  (failure) => print('Error: ${failure.message}'),
  (data) {
    final products = data['products'] as List;
    print('Total: ${data['total_items']}, Found: ${products.length}');
  },
);
```

### 12. Get Product Details

```dart
final result = await paypal.getProductDetails(
  clientSecret: 'YOUR_SECRET',
  productId: 'PROD-XXXX',
);
```

### 13. Update Product

```dart
final result = await paypal.updateProduct(
  clientSecret: 'YOUR_SECRET',
  productId: 'PROD-XXXX',
  patchOperations: [
    {'op': 'replace', 'path': '/description', 'value': 'New description'},
  ],
);
```

### 14. Create a Billing Plan

```dart
final result = await paypal.createPlan(
  clientSecret: 'YOUR_SECRET',
  plan: {
    'product_id': 'PROD-XXXX',
    'name': 'Monthly Plan',
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
```

### 15. List Plans

```dart
final result = await paypal.listPlans(
  clientSecret: 'YOUR_SECRET',
  productId: 'PROD-XXXX', // optional filter
  pageSize: 10,
);
```

### 16. Update Plan Pricing

```dart
final result = await paypal.updatePlanPricing(
  clientSecret: 'YOUR_SECRET',
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
```

### 17. Create a Subscription

```dart
final result = await paypal.createSubscription(
  clientSecret: 'YOUR_SECRET',
  subscription: {
    'plan_id': 'P-XXXX',
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
```

### 18. List Subscriptions

```dart
final result = await paypal.listSubscriptions(
  clientSecret: 'YOUR_SECRET',
  planIds: 'P-XXXX',
  statuses: 'ACTIVE',
  pageSize: 20,
);
```

### 19. Manage Subscription Lifecycle

```dart
// Activate
await paypal.activateSubscription(
  clientSecret: 'YOUR_SECRET',
  subscriptionId: 'I-XXXX',
  reason: 'Reactivating after pause',
);

// Suspend
await paypal.suspendSubscription(
  clientSecret: 'YOUR_SECRET',
  subscriptionId: 'I-XXXX',
  reason: 'Customer requested pause',
);

// Cancel
await paypal.cancelSubscription(
  clientSecret: 'YOUR_SECRET',
  subscriptionId: 'I-XXXX',
  reason: 'Customer requested cancellation',
);

// Revise (change plan)
final revised = await paypal.reviseSubscription(
  clientSecret: 'YOUR_SECRET',
  subscriptionId: 'I-XXXX',
  revisionDetails: {'plan_id': 'P-NEW-PLAN'},
);
```

### 20. Capture Outstanding Payment

```dart
final result = await paypal.captureSubscriptionPayment(
  clientSecret: 'YOUR_SECRET',
  subscriptionId: 'I-XXXX',
  captureRequest: {
    'note': 'Charging outstanding balance',
    'capture_type': 'OUTSTANDING_BALANCE',
    'amount': {'currency_code': 'USD', 'value': '10.00'},
  },
);
```

### 21. List Subscription Transactions

```dart
final result = await paypal.listSubscriptionTransactions(
  clientSecret: 'YOUR_SECRET',
  subscriptionId: 'I-XXXX',
  startTime: '2026-01-01T00:00:00Z',
  endTime: '2026-04-18T23:59:59Z',
);

result.fold(
  (failure) => print('Error: ${failure.message}'),
  (data) {
    final txns = data['transactions'] as List;
    for (final txn in txns) {
      print('${txn['id']}: ${txn['status']} — ${txn['amount_with_breakdown']}');
    }
  },
);
```

---

## Using the Service Directly

For advanced usage, you can use `PaypalSubscriptionService` or `PaypalOrderService` directly:

```dart
final service = PaypalSubscriptionService(
  config: PaypalConfig(
    clientId: 'YOUR_CLIENT_ID',
    environment: PaypalEnvironment.sandbox,
    returnUrl: 'com.example.myapp://paypalpay',
  ),
  clientSecret: 'YOUR_SECRET',
);

try {
  // Plan lifecycle methods only available via service
  await service.updatePlan('P-XXXX', patchOperations: [...]);
  await service.activatePlan('P-XXXX');
  await service.deactivatePlan('P-XXXX');
} finally {
  service.dispose();
}
```

## Dependency Injection

### GetIt

```dart
final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  final paypal = FlutterPaypalPayment();
  await paypal.init(PaypalConfig(
    clientId: 'YOUR_CLIENT_ID',
    environment: PaypalEnvironment.sandbox,
    returnUrl: 'com.example.myapp://paypalpay',
  ));
  getIt.registerSingleton<FlutterPaypalPayment>(paypal);
}
```

### Riverpod

```dart
final paypalProvider = Provider<FlutterPaypalPayment>((ref) {
  throw UnimplementedError('Initialized in main');
});

// In main:
runApp(
  ProviderScope(
    overrides: [paypalProvider.overrideWithValue(paypal)],
    child: MyApp(),
  ),
);
```

## Architecture

```
lib/
├── paypal_checkout_flutter.dart       # Public exports
└── src/
    ├── flutter_paypal_payment_plugin.dart  # Public API (FlutterPaypalPayment)
    ├── domain/
    │   ├── entities/                 # PaypalConfig, PaymentRequest, PaymentCard, etc.
    │   └── repositories/            # Abstract contracts
    ├── data/
    │   ├── repositories/            # Implementation delegating to Pigeon
    │   ├── mappers/                 # Dart ↔ Pigeon message mappers
    │   └── services/                # PaypalOrderService, PaypalSubscriptionService
    └── generated/                   # Auto-generated Pigeon code
    ├── analytics/
    │   └── paypal_subscription_analytics.dart  # MRR/ARR/ARPU/Churn
    ├── events/
    │   ├── paypal_event_bus.dart   # Reactive streams
    │   └── paypal_events.dart      # Typed event classes
    ├── logger/
    │   └── paypal_logger.dart      # Structured logging
    └── webhooks/
        ├── paypal_webhook_event.dart   # Typed webhook models
        └── paypal_webhook_helper.dart  # Verify & parse webhooks

android/src/main/kotlin/
└── FlutterPaypalPaymentPlugin.kt    # Native implementation (PayPal Android SDK)

ios/Classes/
└── PaypalCheckoutFlutterPlugin.swift # Native implementation (PayPal iOS SDK)
```

## Error Handling

All methods return `Either<Failure, Success>`. Use `.fold()` to handle both cases:

```dart
result.fold(
  (failure) {
    // failure.code  — e.g. 'NOT_INITIALIZED', 'CAPTURE_ERROR'
    // failure.message — human-readable description
    print('${failure.code}: ${failure.message}');
  },
  (success) {
    // Handle success
  },
);
```

### Error Code Reference

| Code                          | When it occurs                                                                     |
| ----------------------------- | ---------------------------------------------------------------------------------- |
| `NOT_INITIALIZED`             | `init()` was not called before `pay()` or `payWithCard()`                          |
| `AUTH_ERROR`                  | OAuth2 token request failed (bad credentials or network)                           |
| `CREATE_ORDER_ERROR`          | Order creation failed                                                              |
| `CAPTURE_ERROR`               | Order capture failed after buyer approval                                          |
| `GET_ORDER_ERROR`             | `getOrderDetails()` failed                                                         |
| `UPDATE_ORDER_ERROR`          | `updateOrder()` PATCH failed                                                       |
| `AUTHORIZE_ERROR`             | `authorizeOrder()` failed (AUTHORIZE intent)                                       |
| `CAPTURE_AUTHORIZATION_ERROR` | `captureAuthorization()` failed                                                    |
| `VOID_AUTHORIZATION_ERROR`    | `voidAuthorization()` failed                                                       |
| `REFUND_ERROR`                | `refundCapture()` failed                                                           |
| `SETUP_TOKEN_ERROR`           | `createSetupToken()` failed (vaulting flow)                                        |
| `PAYMENT_TOKEN_ERROR`         | `createPaymentToken()` failed (vaulting flow)                                      |
| `CREATE_PRODUCT_ERROR`        | `createProduct()` failed (subscriptions)                                           |
| `CREATE_PLAN_ERROR`           | `createPlan()` failed                                                              |
| `GET_PLAN_ERROR`              | `getPlan()` failed                                                                 |
| `UPDATE_PLAN_ERROR`           | `updatePlan()` failed                                                              |
| `LIST_PLANS_ERROR`            | `listPlans()` failed                                                               |
| `UPDATE_PRICING_ERROR`        | `updatePlanPricing()` failed                                                       |
| `CREATE_SUBSCRIPTION_ERROR`   | `createSubscription()` failed                                                      |
| `GET_SUBSCRIPTION_ERROR`      | `getSubscription()` failed                                                         |
| `SUBSCRIPTION_ACTION_ERROR`   | `suspendSubscription()` / `cancelSubscription()` / `activateSubscription()` failed |
| `CAPTURE_SUBSCRIPTION_ERROR`  | `captureSubscriptionPayment()` failed                                              |
| `UPDATE_SUBSCRIPTION_ERROR`   | `updateSubscription()` failed                                                      |
| `LIST_SUBSCRIPTIONS_ERROR`    | `listSubscriptions()` failed                                                       |
| `LIST_TRANSACTIONS_ERROR`     | `listSubscriptionTransactions()` failed                                            |
| `LIST_PRODUCTS_ERROR`         | `listProducts()` failed                                                            |
| `GET_PRODUCT_ERROR`           | `getProduct()` failed                                                              |
| `UPDATE_PRODUCT_ERROR`        | `updateProduct()` failed                                                           |
| `VALIDATION_ERROR`            | Invalid input (e.g. malformed order ID)                                            |
| `UNKNOWN_ERROR`               | Unexpected error not covered above                                                 |

---

## v0.2.0 — New Features

### Event Stream Architecture

Every payment lifecycle event is published on a strongly-typed broadcast stream. Subscribe in any widget without changing your business logic:

```dart
final paypal = FlutterPaypalPayment();

@override
void initState() {
  super.initState();
  // Listen to checkout completions
  paypal.events.checkoutCompleted.listen((event) {
    print('Paid! orderId=${event.result.orderId}');
  });

  // Listen to failures
  paypal.events.checkoutFailed.listen((event) {
    print('Failed: ${event.failure.message}');
  });
}

@override
void dispose() {
  paypal.dispose(); // closes all stream controllers
  super.dispose();
}
```

**Available streams on `paypal.events`:**

| Stream                  | Emits when…                        |
| ----------------------- | ---------------------------------- |
| `checkoutStarted`       | `pay()` begins                     |
| `checkoutCompleted`     | `pay()` succeeds                   |
| `checkoutCancelled`     | Buyer cancels in browser           |
| `checkoutFailed`        | `pay()` returns failure            |
| `cardCheckoutCompleted` | `payWithCard()` succeeds           |
| `cardCheckoutFailed`    | `payWithCard()` returns failure    |
| `vaultCompleted`        | `vaultPaypal()`/`vaultCard()` succeeds |
| `vaultFailed`           | Vault returns failure              |
| `subscriptionCreated`   | `createSubscription()` succeeds    |
| `subscriptionCancelled` | `cancelSubscription()` succeeds    |
| `subscriptionSuspended` | `suspendSubscription()` succeeds   |
| `subscriptionActivated` | `activateSubscription()` succeeds  |

---

### Multiple Funding Sources

Pass a `fundingSource` to any checkout to restrict the payment instrument:

```dart
await paypal.pay(
  PaymentRequest(
    orderId: 'ORDER_ID',
    fundingSource: PaypalFundingSource.venmo,   // or .credit, .debit, .payLater
  ),
);
```

Available values: `PaypalFundingSource.paypal`, `.payLater`, `.venmo`, `.credit`, `.debit`.

---

### Pay Later Offer

Fetch promotional financing offers for a buyer before checkout:

```dart
final result = await paypal.getPayLaterOffer(
  clientSecret: 'YOUR_SECRET',
  amount: '150.00',
  currencyCode: 'USD',
  buyerCountryCode: 'US', // optional
);

result.fold(
  (failure) => print('No offer: ${failure.message}'),
  (offer)   => print('Monthly payment: ${offer['monthly_payment']}'),
);
```

---

### UI Components

#### PaypalCheckoutButton

Drop-in branded button with animated press, loading state, and dark mode support:

```dart
PaypalCheckoutButton(
  fundingSource: PaypalFundingSource.paypal,
  isLoading: _processing,
  onPressed: () async {
    setState(() => _processing = true);
    await paypal.pay(PaymentRequest(orderId: orderId));
    setState(() => _processing = false);
  },
)
```

#### PaypalPayLaterBanner

Inline promotional banner that auto-calculates 4-instalment amounts:

```dart
PaypalPayLaterBanner(
  amount: 120.00,
  currencyCode: 'USD',
  onLearnMoreTap: () => launchUrl(Uri.parse('https://www.paypal.com/paylater')),
)
```

#### PaypalVaultButton

Branded "Save payment method" button for vault flows:

```dart
PaypalVaultButton(
  isLoading: _saving,
  label: 'Save card for later',
  onPressed: () async {
    await paypal.vaultCard(VaultCardRequest(...));
  },
)
```

---

### Structured Logging

All internal plugin operations emit structured logs. Configure globally:

```dart
// Suppress debug logs in production
PaypalLogger.minLevel = PaypalLogLevel.warning;

// Forward logs to your analytics / Crashlytics
PaypalLogger.customHandler = (level, tag, message, [error, stackTrace]) {
  FirebaseCrashlytics.instance.log('[$level] $tag: $message');
  return true; // return true to suppress the default print()
};
```

**Log levels**: `debug`, `info`, `warning`, `error`, `none`.

---

### Webhook Framework

#### Parse an incoming webhook

```dart
final event = PaypalWebhookHelper.parse(requestBody);
print('${event.eventTypeName} — ${event.resource['id']}');

// Or safe variant that returns null on error
final event = PaypalWebhookHelper.tryParse(requestBody);
```

#### Local signature verification (HMAC-SHA256)

```dart
final valid = PaypalWebhookHelper.verifySignatureLocal(
  webhookId: 'WH-ID-FROM-DASHBOARD',
  transmissionId: request.headers['paypal-transmission-id']!,
  transmissionTime: request.headers['paypal-transmission-time']!,
  certUrl: request.headers['paypal-cert-url']!,
  authAlgo: request.headers['paypal-auth-algo']!,
  actualSignature: request.headers['paypal-transmission-sig']!,
  webhookSecret: 'YOUR_WEBHOOK_SECRET',
  body: requestBody,
);
```

#### Server-side verification via PayPal API

```dart
final valid = await PaypalWebhookHelper.verifyViaApi(
  clientId: 'YOUR_CLIENT_ID',
  clientSecret: 'YOUR_SECRET',
  environment: PaypalEnvironment.sandbox,
  webhookId: 'WH-ID-FROM-DASHBOARD',
  headers: {
    'paypal-transmission-id': request.headers['paypal-transmission-id']!,
    'paypal-transmission-time': request.headers['paypal-transmission-time']!,
    'paypal-cert-url': request.headers['paypal-cert-url']!,
    'paypal-auth-algo': request.headers['paypal-auth-algo']!,
    'paypal-transmission-sig': request.headers['paypal-transmission-sig']!,
  },
  body: requestBody,
);
```

**Supported event types** (28 total): `CHECKOUT.ORDER.*`, `PAYMENT.CAPTURE.*`, `PAYMENT.AUTHORIZATION.*`, `PAYMENT.SALE.*`, `BILLING.SUBSCRIPTION.*`, `PAYMENT.SALE.*`, `VAULT.*`, and more.

---

### Subscription Analytics

Compute SaaS metrics from a list of subscription maps returned by `listSubscriptions()`:

```dart
final subs = await paypal.listSubscriptions(
  clientSecret: secret,
  statuses: 'ACTIVE,CANCELLED',
  pageSize: 100,
);

subs.fold((err) => null, (data) {
  final subscriptions = data['subscriptions'] as List<Map<String, dynamic>>;

  final report = PaypalSubscriptionAnalytics.revenueReport(subscriptions);

  print('MRR: \$${report.mrr.toStringAsFixed(2)}');
  print('ARR: \$${report.arr.toStringAsFixed(2)}');
  print('ARPU: \$${report.arpu.toStringAsFixed(2)}');
  print('Churn rate: ${(report.churnRate * 100).toStringAsFixed(1)}%');
  print('Active: ${report.activeSubscriptions}');
});
```

**All metrics normalize billing intervals** (daily, weekly, monthly, annual) to a per-month MRR.

---

### Swift Package Manager (iOS)

A `Package.swift` manifest is now included at the package root. Flutter 3.24+ will auto-detect it. To opt in manually, add to your `ios/Podfile`:

```ruby
# Keep CocoaPods as primary (default)
# SPM will be used automatically by Flutter 3.24+
```

No changes required — existing CocoaPods integrations continue to work.

---

## v0.3.0 — Enterprise Features

### Federated Plugin Architecture

`PaypalPlatform` provides an abstract interface for federated plugin implementations. Third-party packages can implement `PaypalPlatform` to add new platform targets (e.g., macOS, Windows) without forking the plugin.

```dart
// Custom platform implementation
class MyPaypalPlatform extends PaypalPlatform {
  @override
  Future<Either<PaymentFailure, Unit>> initialize(PaypalConfig config) async { ... }
  // ...
}

// Register before first use
PaypalPlatform.instance = MyPaypalPlatform();
```

---

### Web Platform Support

Use `PaypalWebCheckout` for REST-based checkout on Flutter Web (redirect flow — no native SDK required):

```dart
final checkout = PaypalWebCheckout(
  config: config,
  clientSecret: 'YOUR_CLIENT_SECRET',
);

final result = await checkout.createOrder(
  amount: '50.00',
  currencyCode: 'USD',
  returnUrl: 'https://yourapp.com/success',
  cancelUrl: 'https://yourapp.com/cancel',
);

result.fold(
  (f) => print('Error: ${f.message}'),
  (data) {
    final approveUrl = data['approveUrl']!;
    // Redirect buyer to approveUrl, then capture:
    final captured = await checkout.captureOrder(orderId: data['orderId']!);
  },
);
```

#### JS SDK Loader

Load the PayPal JavaScript SDK lazily (idempotent, singleton):

```dart
await PaypalJsSdkLoader.ensureLoaded(
  clientId: 'YOUR_CLIENT_ID',
  environment: PaypalEnvironment.sandbox,
  currency: 'USD',
  fundingSources: ['paypal', 'paylater'],
);

// Check status
if (PaypalJsSdkLoader.isLoaded) {
  print('SDK version: ${PaypalJsSdkLoader.sdkVersion}');
}
```

---

### Funding Eligibility

Check which PayPal funding sources are available for a given buyer — with TTL caching:

```dart
final result = await paypal.checkFundingEligibility(
  clientSecret: 'YOUR_CLIENT_SECRET',
  currencyCode: 'USD',
  buyerCountryCode: 'US',
);

result.fold(
  (f) => print('Error: ${f.message}'),
  (eligibility) {
    if (eligibility.payLaterEligible) showPayLaterBadge();
    if (eligibility.venmoEligible) showVenmoOption();

    // List all eligible sources
    for (final source in eligibility.eligibleSources) {
      print('Eligible: $source');
    }
  },
);

// Or use the static API directly
await PaypalFundingEligibility.check(
  clientId: 'YOUR_CLIENT_ID',
  clientSecret: 'YOUR_SECRET',
  environment: PaypalEnvironment.sandbox,
  currencyCode: 'USD',
);

// Cache is valid for 5 minutes by default
PaypalFundingEligibility.cacheDuration = const Duration(minutes: 10);
PaypalFundingEligibility.clearCache();
```

---

### Pay Later Offer Service

Fetch structured Pay Later financing offers for a given amount:

```dart
final result = await PayLaterOfferService.getOffer(
  clientId: 'CLIENT_ID',
  clientSecret: 'SECRET',
  environment: PaypalEnvironment.sandbox,
  amount: '500.00',
  currencyCode: 'USD',
  buyerCountryCode: 'US',
);

result.fold(
  (f) => print(f.message),
  (offer) {
    print(offer.summary);           // "4 payments of $125.00"
    print(offer.formattedMonthly);  // "$125.00"
    print(offer.installments);      // 4
    print(offer.disclosure);        // Legal text
  },
);
```

---

### Marketplace / Commerce Platform

Multi-seller checkout via PayPal Commerce Platform:

```dart
final service = PaypalMarketplaceService(
  config: config,
  clientSecret: 'SECRET',
  partnerMerchantId: 'PARTNER_PAYER_ID',
);

// 1. Onboard a seller
final referral = await service.createPartnerReferral(
  merchantEmail: 'seller@example.com',
  trackingId: 'seller_unique_id',
  returnUrl: 'https://yourapp.com/onboarding/complete',
);
referral.fold(
  (f) => print(f.message),
  (r) => redirect(r.actionUrl),  // Send seller to PayPal onboarding
);

// 2. Check onboarding status
final status = await service.getSellerStatus(merchantId: 'MERCHANT_PAYER_ID');
status.fold(
  (f) => print(f.message),
  (s) => print('Fully onboarded: ${s.isFullyOnboarded}'),
);

// 3. Create a marketplace order with platform fee
final order = await service.createMarketplaceOrder(
  amount: '100.00',
  currencyCode: 'USD',
  sellerMerchantId: 'SELLER_PAYER_ID',
  platformFee: '5.00',
  returnUrl: 'https://yourapp.com/success',
  cancelUrl: 'https://yourapp.com/cancel',
);

// 4. Capture for the seller
await service.captureForMerchant(
  orderId: 'ORDER_ID',
  sellerMerchantId: 'SELLER_PAYER_ID',
);

service.dispose();
```

---

### Subscription Widget

Display subscription details with status badge and action buttons:

```dart
PaypalSubscriptionWidget(
  subscriptionData: subscriptionJson,  // raw map from getSubscriptionDetails()
  onCancel: () => _cancelSubscription(),
  onSuspend: () => _suspendSubscription(),
  onActivate: () => _activateSubscription(),
  showActions: true,
  backgroundColor: Colors.white,
  borderRadius: 12,
)
```

Status badge colors: ACTIVE (green), SUSPENDED (amber), CANCELLED (red), EXPIRED (grey), APPROVAL_PENDING (blue).

---

### Debug Overlay

A floating debug panel — **automatically hidden in release builds**:

```dart
// 1. Create controller
final debugController = PaypalDebugController();

// 2. Wire up event streams
paypal.events.checkoutStarted.listen(debugController.recordCheckoutEvent);
paypal.events.checkoutCompleted.listen(debugController.recordCheckoutEvent);
paypal.events.checkoutFailed.listen(debugController.recordCheckoutEvent);

// 3. Wrap your UI
PaypalDebugOverlay(
  controller: debugController,
  child: MyApp(),
)

// 4. Record SDK initialization
debugController.recordInit(env: 'sandbox');

// 5. Record custom events
debugController.recordEvent(
  type: 'CAPTURE_STARTED',
  summary: 'Capturing order',
  detail: 'orderId: ORDER-123',
);
```

---

### Trace Log Level

Ultra-verbose `trace` level for debugging raw HTTP traffic — never enable in production:

```dart
PaypalLogger.minLevel = PaypalLogLevel.trace;
```

**Log levels** (most to least verbose): `trace`, `debug`, `info`, `warning`, `error`, `none`.

---

### Enhanced Event Bus

Four new event streams in v0.3.0:

| Stream              | Emits when…                               |
| ------------------- | ----------------------------------------- |
| `cardPaymentStarted` | Card payment submitted to SDK            |
| `vaultStarted`      | Vault operation begins                   |
| `refundCompleted`   | `refund()` succeeds                      |
| `refundFailed`      | `refund()` returns failure               |

```dart
paypal.events.refundCompleted.listen((e) {
  print('Refunded ${e.refundId} for capture ${e.captureId}');
});
paypal.events.cardPaymentStarted.listen((e) {
  print('Card payment started for order ${e.orderId}');
});
```

---

### Revenue Segmentation Analytics

Two new analytics methods and a growth trend utility:

```dart
final subs = [...]; // from listSubscriptions()

// MRR grouped by plan ID (sorted descending)
final byPlan = PaypalSubscriptionAnalytics.revenueByPlan(subs);
byPlan.forEach((planId, mrr) => print('$planId: \$$mrr'));

// MRR grouped by calendar month (YYYY-MM, sorted ascending)
final byMonth = PaypalSubscriptionAnalytics.revenueByMonth(subs);
byMonth.forEach((month, mrr) => print('$month: \$$mrr'));

// Month-over-month growth trend
final trend = PaypalSubscriptionAnalytics.revenueTrend(subs);
for (final t in trend) {
  print('${t.month}: \$${t.mrr.toStringAsFixed(2)} '
        '(${t.growthPercent?.toStringAsFixed(1) ?? 'N/A'}% MoM)');
  print(t.isGrowth ? '↑' : t.isDecline ? '↓' : '—');
}
```

---

### Migration Guide: v0.2.x → v0.3.x

**pubspec.yaml**: Bump version to `^0.3.0`.

**Logger**: `PaypalLogLevel.trace` is now the lowest level (index 0). Existing `minLevel` comparisons still work — no code changes needed unless you compare enum `.index` values directly.

**Event bus**: All new streams (`cardPaymentStarted`, `vaultStarted`, `refundCompleted`, `refundFailed`) are broadcast streams — subscribe normally. Existing streams are unchanged.

**Exports**: All new types (`FundingEligibilityResult`, `PayLaterOffer`, `PaypalMarketplaceService`, `PaypalWebCheckout`, `PaypalSubscriptionWidget`, `PaypalDebugOverlay`, `PaypalPlatform`, etc.) are now exported from `paypal_checkout_flutter.dart` — no additional imports needed.

---

## Support

If this package helps you, consider supporting its development:

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/ignaciomanchu)

## License

BSD-3-Clause — See [LICENSE](LICENSE) for details.
