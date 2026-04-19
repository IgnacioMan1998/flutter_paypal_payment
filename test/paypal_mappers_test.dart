import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';
import 'package:paypal_checkout_flutter/src/data/mappers/paypal_mappers.dart';
import 'package:paypal_checkout_flutter/src/generated/paypal_api.g.dart'
    as pigeon;

void main() {
  // ═══════════════════════════════════════════════════════
  // PaypalConfigMapper
  // ═══════════════════════════════════════════════════════

  group('PaypalConfigMapper', () {
    test('maps sandbox config correctly', () {
      final config = PaypalConfig(
        clientId: 'test-id',
        environment: PaypalEnvironment.sandbox,
        returnUrl: 'com.test://callback',
      );

      final message = config.toMessage();

      expect(message.clientId, 'test-id');
      expect(message.environment, pigeon.PaypalEnvironment.sandbox);
      expect(message.returnUrl, 'com.test://callback');
    });

    test('maps live config correctly', () {
      final config = PaypalConfig(
        clientId: 'live-id',
        environment: PaypalEnvironment.live,
      );

      final message = config.toMessage();

      expect(message.clientId, 'live-id');
      expect(message.environment, pigeon.PaypalEnvironment.live);
      expect(message.returnUrl, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════
  // PaymentRequestMapper
  // ═══════════════════════════════════════════════════════

  group('PaymentRequestMapper', () {
    test('maps PayPal funding source', () {
      const request = PaymentRequest(
        orderId: 'ORDER-1',
        fundingSource: PaypalFundingSource.paypal,
      );

      final message = request.toMessage();

      expect(message.orderId, 'ORDER-1');
      expect(message.fundingSource, pigeon.FundingSourceMessage.paypal);
    });

    test('maps Pay Later funding source', () {
      const request = PaymentRequest(
        orderId: 'ORDER-2',
        fundingSource: PaypalFundingSource.payLater,
      );

      final message = request.toMessage();

      expect(message.orderId, 'ORDER-2');
      expect(message.fundingSource, pigeon.FundingSourceMessage.payLater);
    });
  });

  // ═══════════════════════════════════════════════════════
  // PaymentCardMapper
  // ═══════════════════════════════════════════════════════

  group('PaymentCardMapper', () {
    test('maps all card fields', () {
      final card = PaymentCard(
        number: '4111111111111111',
        expirationMonth: '12',
        expirationYear: '2028',
        securityCode: '123',
        cardholderName: 'John Doe',
      );

      final message = card.toMessage();

      expect(message.number, '4111111111111111');
      expect(message.expirationMonth, '12');
      expect(message.expirationYear, '2028');
      expect(message.securityCode, '123');
      expect(message.cardholderName, 'John Doe');
    });

    test('maps card with null cardholderName', () {
      final card = PaymentCard(
        number: '4111111111111111',
        expirationMonth: '01',
        expirationYear: '2030',
        securityCode: '456',
      );

      final message = card.toMessage();

      expect(message.cardholderName, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════
  // CardPaymentRequestMapper
  // ═══════════════════════════════════════════════════════

  group('CardPaymentRequestMapper', () {
    test('maps card payment request with SCA', () {
      final card = PaymentCard(
        number: '4111111111111111',
        expirationMonth: '06',
        expirationYear: '2029',
        securityCode: '789',
      );

      final request = CardPaymentRequest(
        orderId: 'ORDER-3',
        card: card,
        sca: 'SCA_ALWAYS',
      );

      final message = request.toMessage();

      expect(message.orderId, 'ORDER-3');
      expect(message.card.number, '4111111111111111');
      expect(message.sca, 'SCA_ALWAYS');
    });

    test('maps card payment request without SCA', () {
      final card = PaymentCard(
        number: '4111111111111111',
        expirationMonth: '06',
        expirationYear: '2029',
        securityCode: '789',
      );

      final request = CardPaymentRequest(
        orderId: 'ORDER-4',
        card: card,
      );

      final message = request.toMessage();

      expect(message.sca, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════
  // VaultPaypalRequestMapper
  // ═══════════════════════════════════════════════════════

  group('VaultPaypalRequestMapper', () {
    test('maps vault PayPal request', () {
      const request = VaultPaypalRequest(setupTokenId: 'ST-100');

      final message = request.toMessage();

      expect(message.setupTokenId, 'ST-100');
    });
  });

  // ═══════════════════════════════════════════════════════
  // VaultCardRequestMapper
  // ═══════════════════════════════════════════════════════

  group('VaultCardRequestMapper', () {
    test('maps vault card request', () {
      final card = PaymentCard(
        number: '4111111111111111',
        expirationMonth: '12',
        expirationYear: '2028',
        securityCode: '123',
      );

      final request = VaultCardRequest(setupTokenId: 'ST-200', card: card);

      final message = request.toMessage();

      expect(message.setupTokenId, 'ST-200');
      expect(message.card.number, '4111111111111111');
      expect(message.card.expirationMonth, '12');
      expect(message.card.expirationYear, '2028');
      expect(message.card.securityCode, '123');
    });
  });
}
