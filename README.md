# flutter_paypal_payment

Paquete Flutter para integrar pagos con PayPal usando el **PayPal Mobile SDK v2.3.0** nativo de Android. Comunicación type-safe entre Dart y Kotlin vía [Pigeon](https://pub.dev/packages/pigeon).

> **No usa WebView.** Abre el navegador del sistema o procesa tarjetas directamente con el SDK nativo.

## Características

| Funcionalidad                 | Método                | Backend requerido     |
| ----------------------------- | --------------------- | --------------------- |
| Checkout PayPal               | `pay()`               | Sí (crea la orden)    |
| Checkout PayPal sin backend   | `payDirect()`         | No                    |
| Pay Later (financiación)      | `pay()` + `payLater`  | Sí (crea la orden)    |
| Pago con tarjeta              | `payWithCard()`       | Sí (crea la orden)    |
| Pago con tarjeta sin backend  | `payWithCardDirect()` | No                    |
| Guardar cuenta PayPal (Vault) | `vaultPaypal()`       | Sí (crea setup token) |
| Guardar tarjeta (Vault)       | `vaultCard()`         | Sí (crea setup token) |
| Vault PayPal sin backend      | `vaultPaypalDirect()` | No                    |
| Vault tarjeta sin backend     | `vaultCardDirect()`   | No                    |
| Consultar orden               | `getOrderDetails()`   | No                    |
| Reembolso                     | `refund()`            | No                    |

- Soporte completo de **3D Secure** en pagos con tarjeta
- Arquitectura limpia: entidades, repositorios, mappers
- `Either<Failure, Success>` con [dartz](https://pub.dev/packages/dartz) para manejo de errores

## Requisitos

- **Android**: `minSdk 23`, `compileSdk 34`, Java 17
- **Flutter**: `>=1.17.0`
- Una app de PayPal ([developer.paypal.com](https://developer.paypal.com))

## Instalación

```yaml
dependencies:
  flutter_paypal_payment:
    git:
      url: https://github.com/TU_USUARIO/flutter_paypal_payment.git
```

### Configuración Android

En tu `AndroidManifest.xml`, agrega el intent filter para el deep link de retorno:

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

## Uso

### 1. Inicializar (una sola vez)

```dart
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';

final paypal = FlutterPaypalPayment();

await paypal.init(
  const PaypalConfig(
    clientId: 'TU_CLIENT_ID',
    environment: PaypalEnvironment.sandbox, // o .live
    returnUrl: 'com.example.myapp://paypalpay',
  ),
);
```

---

### 2. Checkout PayPal (con backend)

Tu servidor crea la orden con la API de PayPal y te devuelve el `orderId`.

```dart
final result = await paypal.pay(
  PaymentRequest(orderId: 'ORDER_ID_DEL_BACKEND'),
);

result.fold(
  (failure) => print('Error: ${failure.message} (${failure.code})'),
  (success) => print('Pagado! Orden: ${success.orderId}, Payer: ${success.payerId}'),
);
```

---

### 3. Checkout PayPal (sin backend)

Crea la orden, abre el checkout y captura el pago — todo desde Flutter.

> **Nota:** Requiere tu `clientSecret`. No se recomienda en producción.

```dart
final result = await paypal.payDirect(
  clientSecret: 'TU_CLIENT_SECRET',
  params: const PaymentParams(
    amount: '25.00',
    currencyCode: 'USD',
    description: 'Compra de producto X',
  ),
);

result.fold(
  (failure) => print('Error: ${failure.message}'),
  (success) => print('Pagado y capturado! Orden: ${success.orderId}'),
);
```

Parámetros opcionales de `PaymentParams`:

| Parámetro        | Descripción                                 |
| ---------------- | ------------------------------------------- |
| `description`    | Descripción mostrada al comprador           |
| `customId`       | Tu referencia interna                       |
| `invoiceId`      | Número de factura                           |
| `softDescriptor` | Texto en el estado de cuenta (máx 22 chars) |

---

### 4. Pago con tarjeta (con backend)

Cobra directamente una tarjeta sin que el usuario inicie sesión en PayPal. Soporta autenticación 3D Secure automáticamente.

```dart
final result = await paypal.payWithCard(
  CardPaymentRequest(
    orderId: 'ORDER_ID_DEL_BACKEND',
    card: const PaymentCard(
      number: '4111111111111111',
      expirationMonth: '12',
      expirationYear: '2028',
      securityCode: '123',
    ),
    // sca: 'SCA_ALWAYS', // Forzar 3DS (por defecto: SCA_WHEN_REQUIRED)
  ),
);

result.fold(
  (failure) => print('Error: ${failure.message} (${failure.code})'),
  (success) => print('Pagado con tarjeta! Orden: ${success.orderId}, '
      'Status: ${success.status}, 3DS: ${success.didAttemptThreeDSecure}'),
);
```

---

### 5. Pago con tarjeta (sin backend)

```dart
final result = await paypal.payWithCardDirect(
  clientSecret: 'TU_CLIENT_SECRET',
  params: const PaymentParams(
    amount: '50.00',
    currencyCode: 'USD',
    description: 'Compra con tarjeta',
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
  (failure) => print('Error: ${failure.message}'),
  (success) => print('Pagado y capturado! Orden: ${success.orderId}'),
);
```

---

### 6. Vault: Guardar cuenta PayPal

Guarda un método de pago PayPal para cobros futuros. Necesitas crear un **setup token** desde tu servidor usando la [API de Setup Tokens](https://developer.paypal.com/docs/api/payment-tokens/v3/).

```dart
final result = await paypal.vaultPaypal(
  VaultPaypalRequest(setupTokenId: 'SETUP_TOKEN_DEL_BACKEND'),
);

result.fold(
  (failure) => print('Vault error: ${failure.message}'),
  (success) => print('PayPal guardado! Token: ${success.setupTokenId}, '
      'Status: ${success.status}'),
);
```

---

### 7. Vault: Guardar tarjeta

Guarda una tarjeta para cobros futuros, con soporte de 3D Secure.

```dart
final result = await paypal.vaultCard(
  VaultCardRequest(
    setupTokenId: 'SETUP_TOKEN_DEL_BACKEND',
    card: const PaymentCard(
      number: '4111111111111111',
      expirationMonth: '12',
      expirationYear: '2028',
      securityCode: '123',
    ),
  ),
);

result.fold(
  (failure) => print('Card vault error: ${failure.message}'),
  (success) => print('Tarjeta guardada! Token: ${success.setupTokenId}'),
);
```

---

### 8. Pay Later (financiación PayPal)

Ofrece PayPal Pay Later como opción de financiación. El usuario puede pagar en cuotas.

```dart
final result = await paypal.pay(
  PaymentRequest(
    orderId: 'ORDER_ID_DEL_BACKEND',
    fundingSource: PaypalFundingSource.payLater,
  ),
);

result.fold(
  (failure) => print('Pay Later error: ${failure.message}'),
  (success) => print('Pay Later completado! Orden: ${success.orderId}'),
);
```

---

### 9. Vault PayPal sin backend

Crea el setup token, guarda la cuenta PayPal y crea el payment token — todo desde Flutter.

> **Nota:** Requiere tu `clientSecret`. No se recomienda en producción.

```dart
final result = await paypal.vaultPaypalDirect(
  clientSecret: 'TU_CLIENT_SECRET',
  customer: {'id': 'CUSTOMER_123'},
);

result.fold(
  (failure) => print('Vault error: ${failure.message}'),
  (success) => print('PayPal guardado! Payment Token: $success'),
);
```

---

### 10. Vault tarjeta sin backend

```dart
final result = await paypal.vaultCardDirect(
  clientSecret: 'TU_CLIENT_SECRET',
  card: const PaymentCard(
    number: '4111111111111111',
    expirationMonth: '12',
    expirationYear: '2028',
    securityCode: '123',
  ),
  customer: {'id': 'CUSTOMER_123'},
);

result.fold(
  (failure) => print('Card vault error: ${failure.message}'),
  (success) => print('Tarjeta guardada! Payment Token: $success'),
);
```

---

### 11. Consultar detalles de una orden

Obtén el estado y detalles de una orden creada previamente.

```dart
final result = await paypal.getOrderDetails(
  clientSecret: 'TU_CLIENT_SECRET',
  orderId: 'ORDER_ID',
);

result.fold(
  (failure) => print('Error: ${failure.message}'),
  (order) => print('Estado: ${order['status']}, '
      'Monto: ${order['purchase_units']?[0]?['amount']}'),
);
```

---

### 12. Reembolso (total o parcial)

Reembolsa un pago capturado. Si no especificas monto, se reembolsa el total.

```dart
// Reembolso total
final result = await paypal.refund(
  clientSecret: 'TU_CLIENT_SECRET',
  captureId: 'CAPTURE_ID',
);

// Reembolso parcial
final partial = await paypal.refund(
  clientSecret: 'TU_CLIENT_SECRET',
  captureId: 'CAPTURE_ID',
  amount: '5.00',
  currencyCode: 'USD',
);
```

---

## Arquitectura

```
lib/
├── flutter_paypal_payment.dart       # Exports públicos
└── src/
    ├── flutter_paypal_payment_plugin.dart  # API pública (FlutterPaypalPayment)
    ├── domain/
    │   ├── entities/                 # PaypalConfig, PaymentRequest, PaymentCard, etc.
    │   └── repositories/            # Contratos abstractos
    ├── data/
    │   ├── repositories/            # Implementación delegando a Pigeon
    │   ├── mappers/                 # Dart ↔ Pigeon message mappers
    │   └── services/                # PaypalOrderService (REST API directa)
    └── generated/                   # Código auto-generado por Pigeon

android/src/main/kotlin/
└── FlutterPaypalPaymentPlugin.kt    # Implementación nativa (PayPal SDK)
```

## Flujo de datos

```
Flutter (usuario)
    ↓
FlutterPaypalPayment          ← API pública
    ↓
PaypalRepository               ← Contrato
    ↓
PaypalRepositoryImpl           ← Mappers Dart → Pigeon
    ↓
PaypalHostApi (Pigeon)         ← Comunicación type-safe
    ↓
FlutterPaypalPaymentPlugin.kt ← PayPal SDK nativo (Android)
    ↓
PayPal (browser/3DS/SDK)
    ↓ deep link
onNewIntent → finishStart/finishApproveOrder/finishVault
    ↓
Callback → Pigeon → Dart → Either<Failure, Success>
```

## Licencia

MIT

# flutter_paypal_payment
