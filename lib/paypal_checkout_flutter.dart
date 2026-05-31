library;

// ── Core ──────────────────────────────────────────────────
export 'src/core/constants/paypal_api_constants.dart';
export 'src/core/constants/paypal_error_codes.dart';
export 'src/core/constants/paypal_error_messages.dart';
export 'src/core/enums/paypal_enums.dart';
export 'src/core/utils/paypal_utils.dart';
export 'src/core/validators/paypal_validation_rules.dart';

// ── Services ──────────────────────────────────────────────
export 'src/data/services/paypal_order_service.dart';
export 'src/data/services/paypal_subscription_service.dart';

// ── Domain entities ───────────────────────────────────────
export 'src/domain/entities/card_payment.dart';
export 'src/domain/entities/payment_card.dart';
export 'src/domain/entities/payment_params.dart';
export 'src/domain/entities/payment_request.dart';
export 'src/domain/entities/payment_result.dart';
export 'src/domain/entities/paypal_config.dart';
export 'src/domain/entities/vault.dart';
export 'src/domain/repositories/paypal_repository.dart';

// ── Plugin entry point ────────────────────────────────────
export 'src/flutter_paypal_payment_plugin.dart';

// ── Events ────────────────────────────────────────────────
export 'src/events/paypal_event_bus.dart';
export 'src/events/paypal_events.dart';

// ── Logger ────────────────────────────────────────────────
export 'src/logger/paypal_logger.dart';

// ── Analytics ────────────────────────────────────────────
export 'src/analytics/paypal_subscription_analytics.dart';

// ── Webhooks ─────────────────────────────────────────────
export 'src/webhooks/paypal_webhook_event.dart';
export 'src/webhooks/paypal_webhook_helper.dart';

// ── UI ────────────────────────────────────────────────────
export 'src/ui/paypal_card_form.dart';
export 'src/ui/paypal_card_form_theme.dart';
export 'src/ui/paypal_checkout_button.dart';
export 'src/ui/paypal_pay_later_banner.dart';
export 'src/ui/paypal_vault_button.dart';
export 'src/ui/paypal_subscription_widget.dart';
export 'src/ui/paypal_debug_overlay.dart';

// ── Platform interface ────────────────────────────────────
export 'src/platform/paypal_platform.dart';

// ── Funding eligibility ───────────────────────────────────
export 'src/funding/funding_eligibility.dart';

// ── Pay Later ─────────────────────────────────────────────
export 'src/pay_later/pay_later_offer.dart';

// ── Marketplace / Commerce Platform ──────────────────────
export 'src/marketplace/paypal_marketplace_service.dart';

// ── Web ───────────────────────────────────────────────────
export 'src/web/paypal_js_sdk_loader.dart';
export 'src/web/paypal_web_checkout.dart';
