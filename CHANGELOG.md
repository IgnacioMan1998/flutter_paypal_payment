## 0.2.0

### Nuevas funcionalidades

- **Pay Later** (financiación PayPal)
  - Nuevo enum `PaypalFundingSource` con valores `paypal` y `payLater`
  - Campo `fundingSource` en `PaymentRequest` (por defecto `paypal`)
  - Soporte nativo en Kotlin con `PayPalWebCheckoutFundingSource.PAY_LATER`

- **Vault sin backend** (`vaultPaypalDirect`, `vaultCardDirect`)
  - `vaultPaypalDirect()`: Crea setup token → guarda cuenta PayPal → crea payment token
  - `vaultCardDirect()`: Crea setup token → guarda tarjeta → crea payment token
  - Todo desde Flutter sin necesidad de servidor propio

- **Consultar orden** (`getOrderDetails`)
  - Obtiene estado y detalles de una orden via GET `/v2/checkout/orders/{id}`

- **Reembolsos** (`refund`)
  - Reembolso total o parcial de un pago capturado
  - POST `/v2/payments/captures/{id}/refund`
  - Soporte para monto parcial con `amount` y `currencyCode`

- **Nuevas APIs REST en PaypalOrderService**
  - `getOrderDetails()` — GET detalles de orden
  - `refundCapture()` — Reembolso total/parcial
  - `createSetupToken()` — Crear setup token (Vault v3)
  - `createPaymentToken()` — Crear payment token desde setup token

- **PaypalOrderService exportado** para uso directo por el desarrollador

### Tests

- 50 tests unitarios (9 nuevos)
- Cobertura de Pay Later, vaultPaypalDirect, vaultCardDirect, getOrderDetails, refund

---

## 0.1.0

### Nuevas funcionalidades

- **Pago con tarjeta** (`payWithCard`, `payWithCardDirect`)
  - Cobra tarjetas directamente sin login de PayPal
  - Autenticación 3D Secure automática (`SCA_WHEN_REQUIRED`) o forzada (`SCA_ALWAYS`)
  - Soporte sin backend con `payWithCardDirect()` (crea orden + procesa tarjeta + captura)

- **Vault — Guardar métodos de pago**
  - `vaultPaypal()`: Guarda una cuenta PayPal para cobros futuros
  - `vaultCard()`: Guarda una tarjeta con soporte de 3D Secure
  - Requiere setup token creado vía PayPal Setup Tokens API v3

- **Dependencia `card-payments:2.3.0`** agregada al SDK nativo

### Arquitectura

- Nuevas entidades: `PaymentCard`, `CardPaymentRequest`, `CardPaymentResult`, `VaultPaypalRequest`, `VaultCardRequest`, `VaultResult`
- Pigeon actualizado con mensajes y métodos para tarjetas y vault
- Kotlin plugin: `CardClient` para pagos con tarjeta, vault con `PayPalWebCheckoutClient` y `CardClient`
- Sistema de `ActiveFlow` para enrutar deep links al handler correcto (`onNewIntent`)

---

## 0.0.1

### Release inicial

- **Checkout PayPal** (`pay`)
  - Abre el checkout nativo de PayPal vía browser del sistema
  - Requiere `orderId` creado desde tu backend (PayPal Orders API v2)
  - Retorna `Either<PaymentFailure, PaymentSuccess>` con `orderId` y `payerId`

- **Checkout PayPal sin backend** (`payDirect`)
  - Crea la orden, abre el checkout y captura — todo desde Flutter
  - Usa `PaypalOrderService` para llamadas REST directas (OAuth2 + Orders API)
  - Parámetros: `amount`, `currencyCode`, `description`, etc.
  - `autoCapture` opcional (por defecto `true`)

- **SDK nativo PayPal Android v2.3.0**
  - API basada en callbacks: `start(activity, request, callback)`
  - Retorno vía deep link: `finishStart(intent)`
  - Requiere Java 17, `minSdk 23`, `compileSdk 34`

- **Comunicación type-safe** con [Pigeon](https://pub.dev/packages/pigeon) v22.7.4
  - Generación automática de código Dart ↔ Kotlin
  - Mensajes tipados para configuración, requests y results

- **Arquitectura limpia**
  - Domain: entidades y contratos de repositorio
  - Data: implementación, mappers Dart↔Pigeon, servicios REST
  - `Either<Failure, Success>` con [dartz](https://pub.dev/packages/dartz)
