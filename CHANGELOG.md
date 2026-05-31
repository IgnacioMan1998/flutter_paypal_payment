## 0.1.1

- **New**: Federated plugin architecture — `PaypalPlatform` abstract interface (`plugin_platform_interface`) for custom platform implementations
- **New**: Web platform support — `PaypalWebCheckout` (REST redirect flow) and `PaypalJsSdkLoader` (lazy JS SDK loading for Flutter Web)
- **New**: Funding Eligibility API — `PaypalFundingEligibility.check()` / `FlutterPaypalPayment.checkFundingEligibility()` with TTL caching and `PaypalFundingSource` enum
- **New**: Pay Later Offer Service — `PayLaterOfferService.getOffer()` returns structured `PayLaterOffer` with `summary`, `formattedMonthly`, `disclosure`
- **New**: Marketplace / Commerce Platform — `PaypalMarketplaceService` for partner referrals (`createPartnerReferral`), seller onboarding status (`getSellerStatus`), marketplace orders (`createMarketplaceOrder`, `captureForMerchant`)
- **New**: `PaypalSubscriptionWidget` — drop-in widget with status badge and cancel/suspend/activate action buttons
- **New**: `PaypalDebugOverlay` + `PaypalDebugController` — floating debug panel (auto-hidden in release builds) for recording SDK events and errors
- **New**: `PaypalLogLevel.trace` — ultra-verbose log level below `debug` for raw HTTP tracing
- **New**: Four new event bus streams — `cardPaymentStarted`, `vaultStarted`, `refundCompleted`, `refundFailed`
- **New**: Plugin now emits `cardPaymentStarted` / `vaultStarted` events before native calls, and `refundCompleted` / `refundFailed` after `refund()`
- **New**: Revenue segmentation analytics — `PaypalSubscriptionAnalytics.revenueByPlan()`, `revenueByMonth()`, `revenueTrend()` with `MonthlyRevenueTrend` model
- **Fix**: `PaypalWebhookResourceType` enum values renamed to lowerCamelCase (`checkoutOrder`, `billingAgreement`)
- **Docs**: Full v0.3.0 README section with migration guide from v0.2.x
- **Tests**: 319 tests passing (up from 256)

## 0.1.0

- **New**: `PaypalCardFormTheme` — fully customizable theme class for `PaypalCardForm` with 4 built-in presets: `PaypalCardFormTheme.paypal` (default), `.dark`, `.aurora`, `.gold`
- **New**: `PaypalCardForm` accepts an optional `theme` parameter; all colors, radii and gradients are now driven by the theme — no more hardcoded values
- **New**: Animated 3D flip card preview inside `PaypalCardForm` — shows card number, holder name and expiry on the front; flips to back to reveal CVV position when the CVV field is focused
- **New**: Card network badge displayed on the preview card face (Visa, Mastercard, Amex, Discover) in addition to the existing inline field icon
- **New**: Full runnable example app (`example/`) covering every plugin flow: card form demo, 4-theme comparison, card payment, direct card payment, PayPal checkout, direct PayPal checkout, vault card, vault PayPal
- **Docs**: Confirmed PayPal Android SDK `Card.cardholderName` is **optional** — `requireCardholderName` defaults to `false` in `PaypalCardForm` matching the API contract
- **Docs**: `CardPaymentRequest.sca` maps directly to `SCA_WHEN_REQUIRED` (default — 3DS only when bank requires) and `SCA_ALWAYS` (always trigger 3DS/dynamic-verification challenge)

## 0.0.9

- **New**: `PaypalConfig.httpTimeout` — configurable HTTP timeout for all REST API calls (default 30 s)
- **New**: `PaypalConfig.debugMode` — verbose request/response logging via `dart:developer` (disable in production)
- **New**: `PaypalCardForm.onError` callback — surfaces submission errors to the parent widget
- **New**: `PaypalCardForm.requireBillingPostalCode` — optional billing ZIP field
- **New**: Accessibility — all `PaypalCardForm` fields wrapped in `Semantics`; stable `Key` identifiers for every input
- **New**: Error code reference table added to README `## Error Handling` section
- **Redesign**: `PaypalCardForm` removes animated 3D card preview — replaced with clean flat inputs; card number field shows detected network badge inline (Visa, Mastercard, Amex, Discover); PayPal header uses simple two-tone wordmark
- **Tests**: 23 widget tests for `PaypalCardForm` (rendering, validation, card-type detection, formatters)
- **Tests**: Extended direct-pay (`payDirect`, `payWithCardDirect`) test groups

## 0.0.8

- **Redesign**: `PaypalCardForm` reskinned to PayPal light paysheet aesthetic — white background, `#001C64` navy typography, `#F5F7FA` input fields, `#003087` CTA button, drag handle, centered PayPal wordmark, amount display, "Payment method rights" link, and section header "Add debit or credit card"

## 0.0.7

- **Fix**: `returnUrl` validator now accepts underscores in scheme (e.g. `com.startup_kjaia://paypalpay`)

## 0.0.6

- **New**: `PaypalCardForm` widget — PayPal-styled card payment UI with animated 3D card preview, automatic network detection (Visa, Mastercard, Amex, Discover), dark navy PayPal aesthetic, and "Secured by PayPal" footer
- **New**: `PaypalCardForm` accepts optional `amount` and `currency` params to display order total in header
- **New**: Card preview flips to show CVV position when CVV field is focused

## 0.0.5

- **Fix iOS**: Updated callback signatures to use `Result<T, CoreSDKError>` pattern (iOS SDK v2.0.1 API)
- **Fix iOS**: Changed `PayPalWebCheckoutFundingSource.payLater` to `.paylater`
- **Fix iOS**: Removed `CorePayments.` prefix — types are available directly via `import PayPal`
- **Fix Android**: Added required `returnUrl` parameter to `CardRequest`
- **Fix Android**: Updated `PayPalWebCheckoutFinishVaultResult.Success` to use `approvalSessionId`

## 0.0.4

- **Fix iOS build**: Changed `import CorePayments`, `import CardPayments`, `import PayPalWebPayments` to `import PayPal` — CocoaPods compiles all subspecs into a single module

## 0.0.3

- Moved `PaypalEnvironment` and `PaypalFundingSource` enums to `core/enums/paypal_enums.dart`
- Shortened package description for pub.dev compliance
- Added Ko-fi support link to README
- Added `.github/FUNDING.yml` for GitHub Sponsors button
- Made repository public for pub.dev score

## 0.0.2

### New: Orders, Authorization, Subscriptions & Complete Catalog/Plans API

- **Orders API enhancements**
  - `authorizeOrder()` — Authorize an order (hold funds)
  - `captureAuthorization()` — Capture a previously authorized payment
  - `voidAuthorization()` — Void an authorization
  - `updateOrder()` — PATCH operations on orders (shipping/tracking)

- **Catalog Products API** (4/4 endpoints)
  - `createProduct()` — Create a catalog product
  - `listProducts()` — List all products with pagination
  - `getProductDetails()` — Get a specific product's details
  - `updateProduct()` — Update product via PATCH operations

- **Billing Plans API** (7/7 endpoints)
  - `createPlan()` — Create a billing plan
  - `listPlans()` — List plans with optional product filter
  - `getPlanDetails()` — Get plan details
  - `updatePlanPricing()` — Update pricing schemes for a plan
  - Plan lifecycle via service: `updatePlan()`, `activatePlan()`, `deactivatePlan()`

- **Subscriptions API** (10/10 endpoints)
  - `createSubscription()` — Create a subscription
  - `getSubscriptionDetails()` — Get subscription details
  - `listSubscriptions()` — List subscriptions with filters (plan, status, dates)
  - `updateSubscription()` — Update subscription via PATCH operations
  - `activateSubscription()` / `suspendSubscription()` / `cancelSubscription()`
  - `reviseSubscription()` — Change subscription plan
  - `captureSubscriptionPayment()` — Capture outstanding balance
  - `listSubscriptionTransactions()` — List transactions for a subscription

- **PaypalSubscriptionService** — Direct REST client for subscriptions

### Improvements

- Comprehensive README with 21 usage examples
- Extended example app with subscription flows
- 177 unit tests
- Better pub.dev topics for discoverability

## 0.0.1

### Funcionalidades

- **Checkout PayPal** (`pay`)
  - Abre el checkout nativo de PayPal vía browser del sistema
  - Requiere `orderId` creado desde tu backend (PayPal Orders API v2)
  - Retorna `Either<PaymentFailure, PaymentSuccess>` con `orderId` y `payerId`

- **Checkout PayPal sin backend** (`payDirect`)
  - Crea la orden, abre el checkout y captura — todo desde Flutter
  - Usa `PaypalOrderService` para llamadas REST directas (OAuth2 + Orders API)
  - Parámetros: `amount`, `currencyCode`, `description`, etc.
  - `autoCapture` opcional (por defecto `true`)

- **Pay Later** (financiación PayPal)
  - Enum `PaypalFundingSource` con valores `paypal` y `payLater`
  - Campo `fundingSource` en `PaymentRequest` (por defecto `paypal`)
  - Soporte nativo en Kotlin con `PayPalWebCheckoutFundingSource.PAY_LATER`

- **Pago con tarjeta** (`payWithCard`, `payWithCardDirect`)
  - Cobra tarjetas directamente sin login de PayPal
  - Autenticación 3D Secure automática (`SCA_WHEN_REQUIRED`) o forzada (`SCA_ALWAYS`)
  - Soporte sin backend con `payWithCardDirect()` (crea orden + procesa tarjeta + captura)

- **Vault — Guardar métodos de pago**
  - `vaultPaypal()`: Guarda una cuenta PayPal para cobros futuros
  - `vaultCard()`: Guarda una tarjeta con soporte de 3D Secure
  - Requiere setup token creado vía PayPal Setup Tokens API v3

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

- **APIs REST en PaypalOrderService**
  - `createOrder()` — Crear orden
  - `captureOrder()` — Capturar orden
  - `getOrderDetails()` — GET detalles de orden
  - `refundCapture()` — Reembolso total/parcial
  - `createSetupToken()` — Crear setup token (Vault v3)
  - `createPaymentToken()` — Crear payment token desde setup token
  - `PaypalOrderService` exportado para uso directo por el desarrollador

### SDK nativo

- **PayPal Android SDK v2.3.0**
  - API basada en callbacks: `start(activity, request, callback)`
  - Retorno vía deep link: `finishStart(intent)`
  - Requiere Java 17, `minSdk 23`, `compileSdk 34`
  - Dependencias: `paypal-web-payments`, `card-payments`, `payment-buttons`

- **Comunicación type-safe** con [Pigeon](https://pub.dev/packages/pigeon) v22.7.4
  - Generación automática de código Dart ↔ Kotlin
  - Mensajes tipados para configuración, requests y results

### Arquitectura

- Domain: entidades y contratos de repositorio
- Data: implementación, mappers Dart↔Pigeon, servicios REST
- `Either<Failure, Success>` con [dartz](https://pub.dev/packages/dartz)
- Entidades: `PaypalConfig`, `PaymentRequest`, `PaymentCard`, `CardPaymentRequest`, `CardPaymentResult`, `VaultPaypalRequest`, `VaultCardRequest`, `VaultResult`, `PaymentParams`
- Kotlin plugin: `CardClient` para pagos con tarjeta, vault con `PayPalWebCheckoutClient` y `CardClient`
- Sistema de `ActiveFlow` para enrutar deep links al handler correcto (`onNewIntent`)

### Seguridad

- **Mensajes de error sanitizados**: No se exponen cuerpos crudos de respuestas PayPal. Solo se extraen `name`, `message` y `debug_id`
- **Cache de access tokens**: Se reutiliza el token OAuth2 hasta su expiración (con margen de 60s)
- **Validación de entrada** en entidades:
  - `PaymentParams`: Valida formato de `amount` (decimal), `currencyCode` (ISO 4217 3 letras), `softDescriptor` (máx 22 chars)
  - `PaymentCard`: Valida número con Luhn check, mes 01-12, año 4 dígitos, CVV 3-4 dígitos
  - `PaypalConfig`: Valida `clientId` no vacío, `returnUrl` con formato de deep link válido
- **Protección contra path injection**: IDs validados contra `^[A-Za-z0-9_-]+$` y codificados con `Uri.encodeComponent()`
- **Limpieza de tokens en dispose()**: Se borran token cacheado y fecha de expiración al cerrar el servicio

### Documentación

- README con guía de integración (variable global, GetIt, Riverpod)
- Ejemplos completos de todos los flujos
- Tabla de funcionalidades con requisitos de backend

### Tests

- 61 tests unitarios
- Cobertura de todos los flujos: checkout, tarjetas, vault, Pay Later, reembolsos
- Tests de validación de entrada: amount, currencyCode, card number (Luhn), CVV, returnUrl
