import '../domain/entities/card_payment.dart';
import '../domain/entities/payment_result.dart';
import '../domain/entities/vault.dart';

// ═══════════════════════════════════════════════════════════
// Checkout events
// ═══════════════════════════════════════════════════════════

/// Emitted immediately before the native PayPal checkout flow is launched.
class PaypalCheckoutStartedEvent {
  const PaypalCheckoutStartedEvent(this.orderId);
  final String orderId;
}

/// Emitted when the buyer approves the payment and the SDK returns success.
class PaypalCheckoutCompletedEvent {
  const PaypalCheckoutCompletedEvent(this.result);
  final PaymentSuccess result;
}

/// Emitted when the buyer cancels or dismisses the checkout flow.
class PaypalCheckoutCancelledEvent {
  const PaypalCheckoutCancelledEvent(this.orderId);
  final String orderId;
}

/// Emitted when the payment attempt fails for any reason.
class PaypalCheckoutFailedEvent {
  const PaypalCheckoutFailedEvent(this.failure);
  final PaymentFailure failure;
}

// ═══════════════════════════════════════════════════════════
// Card checkout events
// ═══════════════════════════════════════════════════════════

/// Emitted when a card payment is approved (including 3DS).
class PaypalCardCheckoutCompletedEvent {
  const PaypalCardCheckoutCompletedEvent(this.result);
  final CardPaymentSuccess result;
}

/// Emitted when a card payment fails.
class PaypalCardCheckoutFailedEvent {
  const PaypalCardCheckoutFailedEvent(this.failure);
  final CardPaymentFailure failure;
}

// ═══════════════════════════════════════════════════════════
// Vault events
// ═══════════════════════════════════════════════════════════

/// Emitted when a PayPal account or card is successfully vaulted.
class PaypalVaultCompletedEvent {
  const PaypalVaultCompletedEvent(this.result);
  final VaultSuccess result;
}

/// Emitted when a vault operation fails.
class PaypalVaultFailedEvent {
  const PaypalVaultFailedEvent(this.failure);
  final VaultFailure failure;
}

// ═══════════════════════════════════════════════════════════
// Subscription events
// ═══════════════════════════════════════════════════════════

/// Emitted when a new subscription is created via [FlutterPaypalPayment.createSubscription].
class PaypalSubscriptionCreatedEvent {
  const PaypalSubscriptionCreatedEvent({
    required this.subscriptionId,
    required this.data,
  });
  final String subscriptionId;
  final Map<String, dynamic> data;
}

/// Emitted when a subscription is cancelled via [FlutterPaypalPayment.cancelSubscription].
class PaypalSubscriptionCancelledEvent {
  const PaypalSubscriptionCancelledEvent(this.subscriptionId);
  final String subscriptionId;
}

/// Emitted when a subscription is suspended.
class PaypalSubscriptionSuspendedEvent {
  const PaypalSubscriptionSuspendedEvent(this.subscriptionId);
  final String subscriptionId;
}

/// Emitted when a suspended subscription is reactivated.
class PaypalSubscriptionActivatedEvent {
  const PaypalSubscriptionActivatedEvent(this.subscriptionId);
  final String subscriptionId;
}

// ═══════════════════════════════════════════════════════════
// Refund events
// ═══════════════════════════════════════════════════════════

/// Emitted when a refund is successfully processed.
class PaypalRefundCompletedEvent {
  const PaypalRefundCompletedEvent({
    required this.captureId,
    required this.refundId,
    this.amount,
    this.currencyCode,
  });
  final String captureId;
  final String refundId;
  final String? amount;
  final String? currencyCode;
}

/// Emitted when a refund attempt fails.
class PaypalRefundFailedEvent {
  const PaypalRefundFailedEvent({
    required this.captureId,
    required this.failure,
  });
  final String captureId;
  final PaymentFailure failure;
}

// ═══════════════════════════════════════════════════════════
// Card payment started event
// ═══════════════════════════════════════════════════════════

/// Emitted just before a card payment is submitted to the SDK.
class PaypalCardPaymentStartedEvent {
  const PaypalCardPaymentStartedEvent(this.orderId);
  final String orderId;
}

// ═══════════════════════════════════════════════════════════
// Vault started event
// ═══════════════════════════════════════════════════════════

/// Emitted just before a vault (save payment method) operation begins.
class PaypalVaultStartedEvent {
  const PaypalVaultStartedEvent(this.setupTokenId);
  final String setupTokenId;
}
