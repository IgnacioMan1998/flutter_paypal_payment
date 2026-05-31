/// Strongly-typed models for PayPal webhook events.
///
/// Reference: https://developer.paypal.com/api/webhooks/v1/
library;

/// The resource type carried inside a PayPal webhook payload.
enum PaypalWebhookResourceType {
  checkoutOrder,
  capture,
  authorization,
  refund,
  subscription,
  billingAgreement,
  payment,
  unknown,
}

/// All PayPal webhook event types known at the time of writing.
enum PaypalWebhookEventType {
  // Orders
  checkoutOrderApproved,
  checkoutOrderCompleted,
  checkoutOrderSaved,
  checkoutOrderVoided,
  // Payments
  paymentCaptureCompleted,
  paymentCaptureDenied,
  paymentCapturePending,
  paymentCaptureRefunded,
  paymentCaptureReversed,
  paymentAuthorizationCreated,
  paymentAuthorizationVoided,
  // Subscriptions
  billingSubscriptionActivated,
  billingSubscriptionCancelled,
  billingSubscriptionCreated,
  billingSubscriptionExpired,
  billingSubscriptionPaymentFailed,
  billingSubscriptionRenewed,
  billingSubscriptionSuspended,
  billingSubscriptionUpdated,
  // Vaulting
  vaultCreditCardCreated,
  vaultCreditCardDeleted,
  // Unknown
  unknown,
}

/// A parsed PayPal webhook event.
///
/// ```dart
/// final event = PaypalWebhookEvent.fromJson(jsonBody);
/// if (event.eventType == PaypalWebhookEventType.paymentCaptureCompleted) {
///   final captureId = event.resource['id'] as String;
/// }
/// ```
class PaypalWebhookEvent {
  const PaypalWebhookEvent({
    required this.id,
    required this.eventType,
    required this.eventTypeName,
    required this.resourceType,
    required this.resource,
    required this.summary,
    required this.createTime,
    this.webhookId,
    this.transmissions,
  });

  /// Unique event ID (e.g. `"WH-XXX"`).
  final String id;

  /// Resolved event type enum value.
  final PaypalWebhookEventType eventType;

  /// Raw event type string from PayPal (e.g. `"PAYMENT.CAPTURE.COMPLETED"`).
  final String eventTypeName;

  /// The type of resource carried in [resource].
  final PaypalWebhookResourceType resourceType;

  /// The raw resource JSON object.
  final Map<String, dynamic> resource;

  /// Human-readable summary.
  final String summary;

  /// ISO 8601 creation timestamp.
  final DateTime createTime;

  /// The webhook ID this event was delivered to.
  final String? webhookId;

  /// Delivery transmission metadata.
  final List<Map<String, dynamic>>? transmissions;

  factory PaypalWebhookEvent.fromJson(Map<String, dynamic> json) {
    final eventTypeName = json['event_type'] as String? ?? '';
    final resourceTypeName =
        (json['resource_type'] as String? ?? '').toLowerCase().replaceAll('-', '_');

    return PaypalWebhookEvent(
      id: json['id'] as String? ?? '',
      eventType: _parseEventType(eventTypeName),
      eventTypeName: eventTypeName,
      resourceType: _parseResourceType(resourceTypeName),
      resource: Map<String, dynamic>.from(json['resource'] as Map? ?? {}),
      summary: json['summary'] as String? ?? '',
      createTime: DateTime.tryParse(json['create_time'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      webhookId: json['webhook_id'] as String?,
      transmissions: (json['transmissions'] as List<dynamic>?)
          ?.whereType<Map<dynamic, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_type': eventTypeName,
        'resource_type': resourceType.name,
        'resource': resource,
        'summary': summary,
        'create_time': createTime.toIso8601String(),
        if (webhookId != null) 'webhook_id': webhookId,
        if (transmissions != null) 'transmissions': transmissions,
      };

  static PaypalWebhookEventType _parseEventType(String raw) =>
      switch (raw.toUpperCase()) {
        'CHECKOUT.ORDER.APPROVED' => PaypalWebhookEventType.checkoutOrderApproved,
        'CHECKOUT.ORDER.COMPLETED' =>
          PaypalWebhookEventType.checkoutOrderCompleted,
        'CHECKOUT.ORDER.SAVED' => PaypalWebhookEventType.checkoutOrderSaved,
        'CHECKOUT.ORDER.VOIDED' => PaypalWebhookEventType.checkoutOrderVoided,
        'PAYMENT.CAPTURE.COMPLETED' =>
          PaypalWebhookEventType.paymentCaptureCompleted,
        'PAYMENT.CAPTURE.DENIED' => PaypalWebhookEventType.paymentCaptureDenied,
        'PAYMENT.CAPTURE.PENDING' =>
          PaypalWebhookEventType.paymentCapturePending,
        'PAYMENT.CAPTURE.REFUNDED' =>
          PaypalWebhookEventType.paymentCaptureRefunded,
        'PAYMENT.CAPTURE.REVERSED' =>
          PaypalWebhookEventType.paymentCaptureReversed,
        'PAYMENT.AUTHORIZATION.CREATED' =>
          PaypalWebhookEventType.paymentAuthorizationCreated,
        'PAYMENT.AUTHORIZATION.VOIDED' =>
          PaypalWebhookEventType.paymentAuthorizationVoided,
        'BILLING.SUBSCRIPTION.ACTIVATED' =>
          PaypalWebhookEventType.billingSubscriptionActivated,
        'BILLING.SUBSCRIPTION.CANCELLED' =>
          PaypalWebhookEventType.billingSubscriptionCancelled,
        'BILLING.SUBSCRIPTION.CREATED' =>
          PaypalWebhookEventType.billingSubscriptionCreated,
        'BILLING.SUBSCRIPTION.EXPIRED' =>
          PaypalWebhookEventType.billingSubscriptionExpired,
        'BILLING.SUBSCRIPTION.PAYMENT.FAILED' =>
          PaypalWebhookEventType.billingSubscriptionPaymentFailed,
        'BILLING.SUBSCRIPTION.RENEWED' =>
          PaypalWebhookEventType.billingSubscriptionRenewed,
        'BILLING.SUBSCRIPTION.SUSPENDED' =>
          PaypalWebhookEventType.billingSubscriptionSuspended,
        'BILLING.SUBSCRIPTION.UPDATED' =>
          PaypalWebhookEventType.billingSubscriptionUpdated,
        'VAULT.CREDIT-CARD.CREATED' =>
          PaypalWebhookEventType.vaultCreditCardCreated,
        'VAULT.CREDIT-CARD.DELETED' =>
          PaypalWebhookEventType.vaultCreditCardDeleted,
        _ => PaypalWebhookEventType.unknown,
      };

  static PaypalWebhookResourceType _parseResourceType(String raw) =>
      switch (raw) {
        'checkout_order' || 'order' =>
          PaypalWebhookResourceType.checkoutOrder,
        'capture' => PaypalWebhookResourceType.capture,
        'authorization' => PaypalWebhookResourceType.authorization,
        'refund' => PaypalWebhookResourceType.refund,
        'subscription' => PaypalWebhookResourceType.subscription,
        'billing_agreement' => PaypalWebhookResourceType.billingAgreement,
        'payment' => PaypalWebhookResourceType.payment,
        _ => PaypalWebhookResourceType.unknown,
      };
}
