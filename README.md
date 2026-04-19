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
- **177 unit tests** with full coverage

## Requirements

- **Android**: `minSdk 23`, `compileSdk 34`, Java 17
- **iOS**: iOS 16.0+
- **Flutter**: `>=1.17.0`
- A PayPal app ([developer.paypal.com](https://developer.paypal.com))

## Installation

```yaml
dependencies:
  paypal_checkout_flutter: ^0.0.3
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

## License

BSD-3-Clause — See [LICENSE](LICENSE) for details.
