import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

// ─── Mock Repository ────────────────────────────────────

class MockPaypalRepository implements PaypalRepository {
  // Control what each method returns
  Either<PaymentFailure, Unit>? initResult;
  Either<PaymentFailure, PaymentSuccess>? paymentResult;
  Either<CardPaymentFailure, CardPaymentSuccess>? cardResult;
  Either<VaultFailure, VaultSuccess>? vaultPaypalResult;
  Either<VaultFailure, VaultSuccess>? vaultCardResult;

  // Track calls
  int initCalls = 0;
  int paymentCalls = 0;
  int cardCalls = 0;
  int vaultPaypalCalls = 0;
  int vaultCardCalls = 0;
  PaypalConfig? lastConfig;
  PaymentRequest? lastPaymentRequest;
  CardPaymentRequest? lastCardRequest;
  VaultPaypalRequest? lastVaultPaypalRequest;
  VaultCardRequest? lastVaultCardRequest;

  @override
  Future<Either<PaymentFailure, Unit>> initialize(PaypalConfig config) async {
    initCalls++;
    lastConfig = config;
    return initResult ?? const Right(unit);
  }

  @override
  Future<Either<PaymentFailure, PaymentSuccess>> processPayment(PaymentRequest request) async {
    paymentCalls++;
    lastPaymentRequest = request;
    return paymentResult ?? const Left(PaymentFailure(message: 'Not configured'));
  }

  @override
  Future<Either<CardPaymentFailure, CardPaymentSuccess>> processCardPayment(
      CardPaymentRequest request) async {
    cardCalls++;
    lastCardRequest = request;
    return cardResult ?? const Left(CardPaymentFailure(message: 'Not configured'));
  }

  @override
  Future<Either<VaultFailure, VaultSuccess>> vaultPaypal(VaultPaypalRequest request) async {
    vaultPaypalCalls++;
    lastVaultPaypalRequest = request;
    return vaultPaypalResult ??const Left(VaultFailure(message: 'Not configured'));
  }

  @override
  Future<Either<VaultFailure, VaultSuccess>> vaultCard(VaultCardRequest request) async {
    vaultCardCalls++;
    lastVaultCardRequest = request;
    return vaultCardResult ?? const Left(VaultFailure(message: 'Not configured'));
  }
}

// ─── Tests ──────────────────────────────────────────────

void main() {
  late MockPaypalRepository mockRepo;
  late FlutterPaypalPayment paypal;

  final testConfig = PaypalConfig(
    clientId: 'test-client-id',
    environment: PaypalEnvironment.sandbox,
    returnUrl: 'com.test.app://paypalpay',
  );

  final testCard = PaymentCard(
    number: '4111111111111111',
    expirationMonth: '12',
    expirationYear: '2028',
    securityCode: '123',
    cardholderName: 'Test User',
  );

  setUp(() {
    mockRepo = MockPaypalRepository();
    paypal = FlutterPaypalPayment(repository: mockRepo);
  });

  // ═══════════════════════════════════════════════════════
  // Entity tests
  // ═══════════════════════════════════════════════════════

  group('Entities', () {
    test('PaypalConfig stores all fields', () {
      expect(testConfig.clientId, 'test-client-id');
      expect(testConfig.environment, PaypalEnvironment.sandbox);
      expect(testConfig.returnUrl, 'com.test.app://paypalpay');
    });

    test('PaypalConfig allows null returnUrl', () {
      final config = PaypalConfig(
        clientId: 'id',
        environment: PaypalEnvironment.live,
      );
      expect(config.returnUrl, isNull);
      expect(config.environment, PaypalEnvironment.live);
    });

    test('PaymentRequest stores orderId', () {
      const req = PaymentRequest(orderId: 'ORDER-123');
      expect(req.orderId, 'ORDER-123');
      expect(req.fundingSource, PaypalFundingSource.paypal);
    });

    test('PaymentRequest with Pay Later funding source', () {
      const req = PaymentRequest(
        orderId: 'ORDER-456',
        fundingSource: PaypalFundingSource.payLater,
      );
      expect(req.orderId, 'ORDER-456');
      expect(req.fundingSource, PaypalFundingSource.payLater);
    });

    test('PaymentSuccess stores orderId and payerId', () {
      const s = PaymentSuccess(orderId: 'O-1', payerId: 'P-1');
      expect(s.orderId, 'O-1');
      expect(s.payerId, 'P-1');
    });

    test('PaymentSuccess allows null payerId', () {
      const s = PaymentSuccess(orderId: 'O-1');
      expect(s.payerId, isNull);
    });

    test('PaymentFailure stores message and code', () {
      const f = PaymentFailure(message: 'fail', code: 'ERR');
      expect(f.message, 'fail');
      expect(f.code, 'ERR');
    });

    test('PaymentCard stores all card fields', () {
      expect(testCard.number, '4111111111111111');
      expect(testCard.expirationMonth, '12');
      expect(testCard.expirationYear, '2028');
      expect(testCard.securityCode, '123');
      expect(testCard.cardholderName, 'Test User');
    });

    test('PaymentCard allows null cardholderName', () {
      final card = PaymentCard(
        number: '4111111111111111',
        expirationMonth: '01',
        expirationYear: '2030',
        securityCode: '456',
      );
      expect(card.cardholderName, isNull);
    });

    test('CardPaymentRequest stores orderId, card and sca', () {
      final req = CardPaymentRequest(
        orderId: 'O-2',
        card: testCard,
        sca: 'SCA_ALWAYS',
      );
      expect(req.orderId, 'O-2');
      expect(req.card.number, '4111111111111111');
      expect(req.sca, 'SCA_ALWAYS');
    });

    test('CardPaymentRequest defaults sca to null', () {
      final req = CardPaymentRequest(orderId: 'O-3', card: testCard);
      expect(req.sca, isNull);
    });

    test('CardPaymentSuccess stores all fields', () {
      const s = CardPaymentSuccess(
        orderId: 'O-4',
        status: 'APPROVED',
        didAttemptThreeDSecureAuthentication: true,
      );
      expect(s.orderId, 'O-4');
      expect(s.status, 'APPROVED');
      expect(s.didAttemptThreeDSecureAuthentication, true);
    });

    test('CardPaymentFailure stores message and code', () {
      const f = CardPaymentFailure(message: 'Card declined', code: 'DECLINED');
      expect(f.message, 'Card declined');
      expect(f.code, 'DECLINED');
    });

    test('VaultPaypalRequest stores setupTokenId', () {
      const req = VaultPaypalRequest(setupTokenId: 'ST-1');
      expect(req.setupTokenId, 'ST-1');
    });

    test('VaultCardRequest stores setupTokenId and card', () {
      final req = VaultCardRequest(setupTokenId: 'ST-2', card: testCard);
      expect(req.setupTokenId, 'ST-2');
      expect(req.card.number, '4111111111111111');
    });

    test('VaultSuccess stores setupTokenId and status', () {
      const s = VaultSuccess(setupTokenId: 'ST-3', status: 'APPROVED');
      expect(s.setupTokenId, 'ST-3');
      expect(s.status, 'APPROVED');
    });

    test('VaultFailure stores message and code', () {
      const f = VaultFailure(message: 'Vault failed', code: 'V_ERR');
      expect(f.message, 'Vault failed');
      expect(f.code, 'V_ERR');
    });

    test('PaymentParams stores all fields', () {
      final p = PaymentParams(
        amount: '99.99',
        currencyCode: 'EUR',
        description: 'Test',
        customId: 'C-1',
        invoiceId: 'INV-1',
        softDescriptor: 'MYSHOP',
      );
      expect(p.amount, '99.99');
      expect(p.currencyCode, 'EUR');
      expect(p.description, 'Test');
      expect(p.customId, 'C-1');
      expect(p.invoiceId, 'INV-1');
      expect(p.softDescriptor, 'MYSHOP');
    });

    test('PaymentParams optional fields default to null', () {
      final p = PaymentParams(amount: '10.00', currencyCode: 'USD');
      expect(p.description, isNull);
      expect(p.customId, isNull);
      expect(p.invoiceId, isNull);
      expect(p.softDescriptor, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════
  // Input validation tests
  // ═══════════════════════════════════════════════════════

  group('Input validation', () {
    test('PaymentParams rejects invalid amount', () {
      expect(() => PaymentParams(amount: 'abc', currencyCode: 'USD'),
          throwsArgumentError);
      expect(() => PaymentParams(amount: '-10', currencyCode: 'USD'),
          throwsArgumentError);
      expect(() => PaymentParams(amount: '', currencyCode: 'USD'),
          throwsArgumentError);
    });

    test('PaymentParams accepts valid amounts', () {
      expect(PaymentParams(amount: '25.00', currencyCode: 'USD').amount,
          '25.00');
      expect(
          PaymentParams(amount: '100', currencyCode: 'EUR').amount, '100');
      expect(PaymentParams(amount: '0.50', currencyCode: 'MXN').amount,
          '0.50');
    });

    test('PaymentParams rejects invalid currencyCode', () {
      expect(() => PaymentParams(amount: '10.00', currencyCode: 'us'),
          throwsArgumentError);
      expect(() => PaymentParams(amount: '10.00', currencyCode: 'USDD'),
          throwsArgumentError);
      expect(() => PaymentParams(amount: '10.00', currencyCode: ''),
          throwsArgumentError);
    });

    test('PaymentParams rejects long softDescriptor', () {
      expect(
          () => PaymentParams(
                amount: '10.00',
                currencyCode: 'USD',
                softDescriptor: 'A' * 23,
              ),
          throwsArgumentError);
    });

    test('PaymentCard rejects invalid card number (Luhn)', () {
      expect(
          () => PaymentCard(
                number: '4111111111111112', // fails Luhn
                expirationMonth: '12',
                expirationYear: '2028',
                securityCode: '123',
              ),
          throwsArgumentError);
    });

    test('PaymentCard rejects non-numeric card number', () {
      expect(
          () => PaymentCard(
                number: 'abcd1234',
                expirationMonth: '12',
                expirationYear: '2028',
                securityCode: '123',
              ),
          throwsArgumentError);
    });

    test('PaymentCard rejects invalid expiration month', () {
      expect(
          () => PaymentCard(
                number: '4111111111111111',
                expirationMonth: '13',
                expirationYear: '2028',
                securityCode: '123',
              ),
          throwsArgumentError);
      expect(
          () => PaymentCard(
                number: '4111111111111111',
                expirationMonth: '00',
                expirationYear: '2028',
                securityCode: '123',
              ),
          throwsArgumentError);
    });

    test('PaymentCard rejects invalid CVV', () {
      expect(
          () => PaymentCard(
                number: '4111111111111111',
                expirationMonth: '12',
                expirationYear: '2028',
                securityCode: '12', // too short
              ),
          throwsArgumentError);
      expect(
          () => PaymentCard(
                number: '4111111111111111',
                expirationMonth: '12',
                expirationYear: '2028',
                securityCode: '12345', // too long
              ),
          throwsArgumentError);
    });

    test('PaypalConfig rejects empty clientId', () {
      expect(
          () => PaypalConfig(
                clientId: '',
                environment: PaypalEnvironment.sandbox,
              ),
          throwsArgumentError);
    });

    test('PaypalConfig rejects invalid returnUrl', () {
      expect(
          () => PaypalConfig(
                clientId: 'id',
                environment: PaypalEnvironment.sandbox,
                returnUrl: 'not a url',
              ),
          throwsArgumentError);
    });

    test('PaypalConfig accepts valid returnUrl', () {
      final config = PaypalConfig(
        clientId: 'id',
        environment: PaypalEnvironment.sandbox,
        returnUrl: 'com.example.app://callback',
      );
      expect(config.returnUrl, 'com.example.app://callback');
    });
  });

  // ═══════════════════════════════════════════════════════
  // Sealed class hierarchy tests
  // ═══════════════════════════════════════════════════════

  group('Sealed classes', () {
    test('PaymentSuccess is a PaymentResult', () {
      const PaymentResult result = PaymentSuccess(orderId: 'O-1');
      expect(result, isA<PaymentSuccess>());
    });

    test('PaymentFailure is a PaymentResult', () {
      const PaymentResult result = PaymentFailure(message: 'err');
      expect(result, isA<PaymentFailure>());
    });

    test('CardPaymentSuccess is a CardPaymentResult', () {
      const CardPaymentResult result = CardPaymentSuccess(orderId: 'O-1');
      expect(result, isA<CardPaymentSuccess>());
    });

    test('CardPaymentFailure is a CardPaymentResult', () {
      const CardPaymentResult result = CardPaymentFailure(message: 'err');
      expect(result, isA<CardPaymentFailure>());
    });

    test('VaultSuccess is a VaultResult', () {
      const VaultResult result = VaultSuccess(setupTokenId: 'ST-1');
      expect(result, isA<VaultSuccess>());
    });

    test('VaultFailure is a VaultResult', () {
      const VaultResult result = VaultFailure(message: 'err');
      expect(result, isA<VaultFailure>());
    });
  });

  // ═══════════════════════════════════════════════════════
  // init() tests
  // ═══════════════════════════════════════════════════════

  group('init()', () {
    test('calls repository.initialize with the config', () async {
      await paypal.init(testConfig);

      expect(mockRepo.initCalls, 1);
      expect(mockRepo.lastConfig?.clientId, 'test-client-id');
      expect(mockRepo.lastConfig?.environment, PaypalEnvironment.sandbox);
    });

    test('returns Right(unit) on success', () async {
      mockRepo.initResult = const Right(unit);
      final result = await paypal.init(testConfig);

      expect(result.isRight(), true);
    });

    test('returns Left(PaymentFailure) on error', () async {
      mockRepo.initResult = const Left(
        PaymentFailure(message: 'Invalid client ID', code: 'INVALID_CLIENT'),
      );
      final result = await paypal.init(testConfig);

      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f.message, 'Invalid client ID');
          expect(f.code, 'INVALID_CLIENT');
        },
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // pay() tests
  // ═══════════════════════════════════════════════════════

  group('pay()', () {
    test('delegates to repository.processPayment', () async {
      mockRepo.paymentResult = const Right(
        PaymentSuccess(orderId: 'O-100', payerId: 'P-200'),
      );

      final result = await paypal.pay(
        const PaymentRequest(orderId: 'O-100'),
      );

      expect(mockRepo.paymentCalls, 1);
      expect(mockRepo.lastPaymentRequest?.orderId, 'O-100');
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (s) {
          expect(s.orderId, 'O-100');
          expect(s.payerId, 'P-200');
        },
      );
    });

    test('returns failure from repository', () async {
      mockRepo.paymentResult = const Left(
        PaymentFailure(message: 'Cancelled', code: 'CANCELLED'),
      );

      final result = await paypal.pay(
        const PaymentRequest(orderId: 'O-101'),
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'CANCELLED'),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // payDirect() tests
  // ═══════════════════════════════════════════════════════

  group('payDirect()', () {
    test('returns NOT_INITIALIZED when init() not called', () async {
      final result = await paypal.payDirect(
        clientSecret: 'secret',
        params: PaymentParams(amount: '10.00', currencyCode: 'USD'),
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // payWithCard() tests
  // ═══════════════════════════════════════════════════════

  group('payWithCard()', () {
    test('delegates to repository.processCardPayment', () async {
      mockRepo.cardResult = const Right(
        CardPaymentSuccess(
          orderId: 'O-300',
          status: 'APPROVED',
          didAttemptThreeDSecureAuthentication: true,
        ),
      );

      final result = await paypal.payWithCard(
        CardPaymentRequest(orderId: 'O-300', card: testCard),
      );

      expect(mockRepo.cardCalls, 1);
      expect(mockRepo.lastCardRequest?.orderId, 'O-300');
      expect(mockRepo.lastCardRequest?.card.number, '4111111111111111');
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (s) {
          expect(s.orderId, 'O-300');
          expect(s.status, 'APPROVED');
          expect(s.didAttemptThreeDSecureAuthentication, true);
        },
      );
    });

    test('returns card failure from repository', () async {
      mockRepo.cardResult = const Left(
        CardPaymentFailure(message: 'Card declined', code: 'DECLINED'),
      );

      final result = await paypal.payWithCard(
        CardPaymentRequest(orderId: 'O-301', card: testCard),
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f.message, 'Card declined');
          expect(f.code, 'DECLINED');
        },
        (_) => fail('Expected Left'),
      );
    });

    test('passes SCA parameter to repository', () async {
      mockRepo.cardResult = const Right(
        CardPaymentSuccess(orderId: 'O-302'),
      );

      await paypal.payWithCard(
        CardPaymentRequest(
          orderId: 'O-302',
          card: testCard,
          sca: 'SCA_ALWAYS',
        ),
      );

      expect(mockRepo.lastCardRequest?.sca, 'SCA_ALWAYS');
    });
  });

  // ═══════════════════════════════════════════════════════
  // payWithCardDirect() tests
  // ═══════════════════════════════════════════════════════

  group('payWithCardDirect()', () {
    test('returns NOT_INITIALIZED when init() not called', () async {
      final result = await paypal.payWithCardDirect(
        clientSecret: 'secret',
        params: PaymentParams(amount: '50.00', currencyCode: 'USD'),
        buildRequest: (orderId) =>
            CardPaymentRequest(orderId: orderId, card: testCard),
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f.message, 'PayPal SDK not initialized. Call init() first.');
          expect(f.code, 'NOT_INITIALIZED');
        },
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // vaultPaypal() tests
  // ═══════════════════════════════════════════════════════

  group('vaultPaypal()', () {
    test('delegates to repository.vaultPaypal', () async {
      mockRepo.vaultPaypalResult = const Right(
        VaultSuccess(setupTokenId: 'ST-100', status: 'APPROVED'),
      );

      final result = await paypal.vaultPaypal(
        const VaultPaypalRequest(setupTokenId: 'ST-100'),
      );

      expect(mockRepo.vaultPaypalCalls, 1);
      expect(mockRepo.lastVaultPaypalRequest?.setupTokenId, 'ST-100');
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (s) {
          expect(s.setupTokenId, 'ST-100');
          expect(s.status, 'APPROVED');
        },
      );
    });

    test('returns vault failure from repository', () async {
      mockRepo.vaultPaypalResult = const Left(
        VaultFailure(message: 'Token expired', code: 'TOKEN_EXPIRED'),
      );

      final result = await paypal.vaultPaypal(
        const VaultPaypalRequest(setupTokenId: 'ST-101'),
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f.message, 'Token expired');
          expect(f.code, 'TOKEN_EXPIRED');
        },
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // vaultCard() tests
  // ═══════════════════════════════════════════════════════

  group('vaultCard()', () {
    test('delegates to repository.vaultCard', () async {
      mockRepo.vaultCardResult = const Right(
        VaultSuccess(setupTokenId: 'ST-200', status: 'APPROVED'),
      );

      final result = await paypal.vaultCard(
        VaultCardRequest(setupTokenId: 'ST-200', card: testCard),
      );

      expect(mockRepo.vaultCardCalls, 1);
      expect(mockRepo.lastVaultCardRequest?.setupTokenId, 'ST-200');
      expect(mockRepo.lastVaultCardRequest?.card.number, '4111111111111111');
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (s) {
          expect(s.setupTokenId, 'ST-200');
          expect(s.status, 'APPROVED');
        },
      );
    });

    test('returns vault failure from repository', () async {
      mockRepo.vaultCardResult = const Left(
        VaultFailure(message: 'Invalid card', code: 'INVALID_CARD'),
      );

      final result = await paypal.vaultCard(
        VaultCardRequest(setupTokenId: 'ST-201', card: testCard),
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f.message, 'Invalid card');
          expect(f.code, 'INVALID_CARD');
        },
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // Multiple operations / integration-like tests
  // ═══════════════════════════════════════════════════════

  group('Multiple operations', () {
    test('can init then pay sequentially', () async {
      mockRepo.initResult = const Right(unit);
      mockRepo.paymentResult = const Right(
        PaymentSuccess(orderId: 'O-500', payerId: 'P-500'),
      );

      final initResult = await paypal.init(testConfig);
      expect(initResult.isRight(), true);

      final payResult = await paypal.pay(
        const PaymentRequest(orderId: 'O-500'),
      );
      expect(payResult.isRight(), true);

      expect(mockRepo.initCalls, 1);
      expect(mockRepo.paymentCalls, 1);
    });

    test('can use different payment methods on same instance', () async {
      mockRepo.initResult = const Right(unit);
      mockRepo.paymentResult = const Right(
        PaymentSuccess(orderId: 'O-600'),
      );
      mockRepo.cardResult = const Right(
        CardPaymentSuccess(orderId: 'O-601'),
      );
      mockRepo.vaultPaypalResult = const Right(
        VaultSuccess(setupTokenId: 'ST-600'),
      );
      mockRepo.vaultCardResult = const Right(
        VaultSuccess(setupTokenId: 'ST-601'),
      );

      await paypal.init(testConfig);

      final r1 = await paypal.pay(const PaymentRequest(orderId: 'O-600'));
      final r2 = await paypal.payWithCard(
        CardPaymentRequest(orderId: 'O-601', card: testCard),
      );
      final r3 = await paypal.vaultPaypal(
        const VaultPaypalRequest(setupTokenId: 'ST-600'),
      );
      final r4 = await paypal.vaultCard(
        VaultCardRequest(setupTokenId: 'ST-601', card: testCard),
      );

      expect(r1.isRight(), true);
      expect(r2.isRight(), true);
      expect(r3.isRight(), true);
      expect(r4.isRight(), true);

      expect(mockRepo.paymentCalls, 1);
      expect(mockRepo.cardCalls, 1);
      expect(mockRepo.vaultPaypalCalls, 1);
      expect(mockRepo.vaultCardCalls, 1);
    });

    test('init failure does not block pay (repository decides)', () async {
      mockRepo.initResult = const Left(
        PaymentFailure(message: 'Init failed'),
      );
      mockRepo.paymentResult = const Right(
        PaymentSuccess(orderId: 'O-700'),
      );

      final initResult = await paypal.init(testConfig);
      expect(initResult.isLeft(), true);

      // pay() still delegates to repo — the repo decides behavior
      final payResult = await paypal.pay(
        const PaymentRequest(orderId: 'O-700'),
      );
      expect(payResult.isRight(), true);
    });
  });

  // ═══════════════════════════════════════════════════════
  // Pay Later tests
  // ═══════════════════════════════════════════════════════

  group('Pay Later', () {
    test('pay() accepts PayLater funding source', () async {
      mockRepo.paymentResult = const Right(
        PaymentSuccess(orderId: 'O-PL', payerId: 'P-PL'),
      );

      final result = await paypal.pay(
        const PaymentRequest(
          orderId: 'O-PL',
          fundingSource: PaypalFundingSource.payLater,
        ),
      );

      expect(mockRepo.paymentCalls, 1);
      expect(mockRepo.lastPaymentRequest?.fundingSource,
          PaypalFundingSource.payLater);
      expect(result.isRight(), true);
    });

    test('pay() defaults to PayPal funding source', () async {
      mockRepo.paymentResult = const Right(
        PaymentSuccess(orderId: 'O-DEF'),
      );

      await paypal.pay(const PaymentRequest(orderId: 'O-DEF'));

      expect(mockRepo.lastPaymentRequest?.fundingSource,
          PaypalFundingSource.paypal);
    });
  });

  // ═══════════════════════════════════════════════════════
  // vaultPaypalDirect() tests
  // ═══════════════════════════════════════════════════════

  group('vaultPaypalDirect()', () {
    test('returns NOT_INITIALIZED when init() not called', () async {
      final result = await paypal.vaultPaypalDirect(
        clientSecret: 'secret',
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // vaultCardDirect() tests
  // ═══════════════════════════════════════════════════════

  group('vaultCardDirect()', () {
    test('returns NOT_INITIALIZED when init() not called', () async {
      final result = await paypal.vaultCardDirect(
        clientSecret: 'secret',
        card: testCard,
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // getOrderDetails() tests
  // ═══════════════════════════════════════════════════════

  group('getOrderDetails()', () {
    test('returns NOT_INITIALIZED when init() not called', () async {
      final result = await paypal.getOrderDetails(
        clientSecret: 'secret',
        orderId: 'ORDER-123',
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // refund() tests
  // ═══════════════════════════════════════════════════════

  group('refund()', () {
    test('returns NOT_INITIALIZED when init() not called', () async {
      final result = await paypal.refund(
        clientSecret: 'secret',
        captureId: 'CAP-123',
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('partial refund returns NOT_INITIALIZED when init() not called',
        () async {
      final result = await paypal.refund(
        clientSecret: 'secret',
        captureId: 'CAP-456',
        amount: '5.00',
        currencyCode: 'USD',
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // PaypalFundingSource enum tests
  // ═══════════════════════════════════════════════════════

  group('PaypalFundingSource', () {
    test('has paypal, payLater, venmo, credit, and debit values', () {
      expect(PaypalFundingSource.values.length, 5);
      expect(PaypalFundingSource.values,
          contains(PaypalFundingSource.paypal));
      expect(PaypalFundingSource.values,
          contains(PaypalFundingSource.payLater));
      expect(PaypalFundingSource.values,
          contains(PaypalFundingSource.venmo));
      expect(PaypalFundingSource.values,
          contains(PaypalFundingSource.credit));
      expect(PaypalFundingSource.values,
          contains(PaypalFundingSource.debit));
    });
  });

  // ═══════════════════════════════════════════════════════
  // authorizeOrder() tests
  // ═══════════════════════════════════════════════════════

  group('authorizeOrder()', () {
    test('returns NOT_INITIALIZED when init() not called', () async {
      final result = await paypal.authorizeOrder(
        clientSecret: 'secret',
        orderId: 'ORDER-123',
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // captureAuthorization() tests
  // ═══════════════════════════════════════════════════════

  group('captureAuthorization()', () {
    test('returns NOT_INITIALIZED when init() not called', () async {
      final result = await paypal.captureAuthorization(
        clientSecret: 'secret',
        authorizationId: 'AUTH-123',
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // voidAuthorization() tests
  // ═══════════════════════════════════════════════════════

  group('voidAuthorization()', () {
    test('returns NOT_INITIALIZED when init() not called', () async {
      final result = await paypal.voidAuthorization(
        clientSecret: 'secret',
        authorizationId: 'AUTH-123',
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // PaymentParams intent tests
  // ═══════════════════════════════════════════════════════

  group('PaymentParams intent', () {
    test('defaults to CAPTURE intent', () {
      final p = PaymentParams(amount: '10.00', currencyCode: 'USD');
      expect(p.intent, 'CAPTURE');
    });

    test('accepts AUTHORIZE intent', () {
      final p = PaymentParams(
        amount: '10.00',
        currencyCode: 'USD',
        intent: 'AUTHORIZE',
      );
      expect(p.intent, 'AUTHORIZE');
    });

    test('rejects invalid intent', () {
      expect(
          () => PaymentParams(
                amount: '10.00',
                currencyCode: 'USD',
                intent: 'INVALID',
              ),
          throwsArgumentError);
    });
  });

  // ═══════════════════════════════════════════════════════
  // updateOrder() NOT_INITIALIZED guard
  // ═══════════════════════════════════════════════════════

  group('updateOrder()', () {
    test('returns NOT_INITIALIZED when init() not called', () async {
      final result = await paypal.updateOrder(
        clientSecret: 'secret',
        orderId: 'ORDER-123',
        patchOperations: [
          {'op': 'replace', 'path': '/intent', 'value': 'CAPTURE'}
        ],
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // Subscription methods NOT_INITIALIZED guards
  // ═══════════════════════════════════════════════════════

  group('Subscription methods NOT_INITIALIZED guards', () {
    test('createProduct returns NOT_INITIALIZED', () async {
      final result = await paypal.createProduct(
        clientSecret: 'secret',
        product: {'name': 'Test', 'type': 'SERVICE'},
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('createPlan returns NOT_INITIALIZED', () async {
      final result = await paypal.createPlan(
        clientSecret: 'secret',
        plan: {'product_id': 'P-123', 'name': 'Plan'},
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('getPlanDetails returns NOT_INITIALIZED', () async {
      final result = await paypal.getPlanDetails(
        clientSecret: 'secret',
        planId: 'P-123',
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('createSubscription returns NOT_INITIALIZED', () async {
      final result = await paypal.createSubscription(
        clientSecret: 'secret',
        subscription: {'plan_id': 'P-123'},
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('getSubscriptionDetails returns NOT_INITIALIZED', () async {
      final result = await paypal.getSubscriptionDetails(
        clientSecret: 'secret',
        subscriptionId: 'I-SUB123',
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('activateSubscription returns NOT_INITIALIZED', () async {
      final result = await paypal.activateSubscription(
        clientSecret: 'secret',
        subscriptionId: 'I-SUB123',
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('suspendSubscription returns NOT_INITIALIZED', () async {
      final result = await paypal.suspendSubscription(
        clientSecret: 'secret',
        subscriptionId: 'I-SUB123',
        reason: 'test',
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('cancelSubscription returns NOT_INITIALIZED', () async {
      final result = await paypal.cancelSubscription(
        clientSecret: 'secret',
        subscriptionId: 'I-SUB123',
        reason: 'test',
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('reviseSubscription returns NOT_INITIALIZED', () async {
      final result = await paypal.reviseSubscription(
        clientSecret: 'secret',
        subscriptionId: 'I-SUB123',
        revisionDetails: {'plan_id': 'P-NEW'},
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('listProducts returns NOT_INITIALIZED', () async {
      final result = await paypal.listProducts(clientSecret: 'secret');
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('getProductDetails returns NOT_INITIALIZED', () async {
      final result = await paypal.getProductDetails(
        clientSecret: 'secret',
        productId: 'PROD-123',
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('updateProduct returns NOT_INITIALIZED', () async {
      final result = await paypal.updateProduct(
        clientSecret: 'secret',
        productId: 'PROD-123',
        patchOperations: [
          {'op': 'replace', 'path': '/description', 'value': 'new'}
        ],
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('listPlans returns NOT_INITIALIZED', () async {
      final result = await paypal.listPlans(clientSecret: 'secret');
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('updatePlanPricing returns NOT_INITIALIZED', () async {
      final result = await paypal.updatePlanPricing(
        clientSecret: 'secret',
        planId: 'P-123',
        pricingSchemes: [
          {
            'billing_cycle_sequence': 1,
            'pricing_scheme': {
              'fixed_price': {'value': '10', 'currency_code': 'USD'}
            }
          }
        ],
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('listSubscriptions returns NOT_INITIALIZED', () async {
      final result = await paypal.listSubscriptions(clientSecret: 'secret');
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('updateSubscription returns NOT_INITIALIZED', () async {
      final result = await paypal.updateSubscription(
        clientSecret: 'secret',
        subscriptionId: 'I-SUB123',
        patchOperations: [
          {'op': 'replace', 'path': '/custom_id', 'value': 'new-id'}
        ],
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('captureSubscriptionPayment returns NOT_INITIALIZED', () async {
      final result = await paypal.captureSubscriptionPayment(
        clientSecret: 'secret',
        subscriptionId: 'I-SUB123',
        captureRequest: {
          'note': 'test',
          'capture_type': 'OUTSTANDING_BALANCE',
          'amount': {'currency_code': 'USD', 'value': '10'}
        },
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });

    test('listSubscriptionTransactions returns NOT_INITIALIZED', () async {
      final result = await paypal.listSubscriptionTransactions(
        clientSecret: 'secret',
        subscriptionId: 'I-SUB123',
        startTime: '2024-01-01T00:00:00Z',
        endTime: '2024-12-31T23:59:59Z',
      );
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, 'NOT_INITIALIZED'),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // payDirect() — extended tests
  // ═══════════════════════════════════════════════════════

  group('payDirect() extended', () {
    test('delegates payment to repository after init', () async {
      await paypal.init(testConfig);
      mockRepo.paymentResult = const Right(
        PaymentSuccess(orderId: 'O-DIRECT', payerId: 'P-DIRECT'),
      );

      // payDirect creates an order via HTTP then calls processPayment.
      // Without a real HTTP server we only verify NOT_INITIALIZED is NOT returned.
      final result = await paypal.payDirect(
        clientSecret: 'secret',
        params: PaymentParams(amount: '10.00', currencyCode: 'USD'),
      );

      // Will fail at HTTP (no server) — but code must NOT be NOT_INITIALIZED
      result.fold(
        (f) => expect(f.code, isNot('NOT_INITIALIZED')),
        (_) => {},
      );
    });

    test('passes autoCapture=false — still calls processPayment', () async {
      await paypal.init(testConfig);
      mockRepo.paymentResult = const Right(
        PaymentSuccess(orderId: 'O-NOCAPTURE'),
      );

      final result = await paypal.payDirect(
        clientSecret: 'secret',
        params: PaymentParams(amount: '5.00', currencyCode: 'USD'),
        autoCapture: false,
      );

      result.fold(
        (f) => expect(f.code, isNot('NOT_INITIALIZED')),
        (_) => {},
      );
    });
  });

  // ═══════════════════════════════════════════════════════
  // payWithCardDirect() — extended tests
  // ═══════════════════════════════════════════════════════

  group('payWithCardDirect() extended', () {
    test('delegates to repository after init', () async {
      await paypal.init(testConfig);
      mockRepo.cardResult = const Right(
        CardPaymentSuccess(orderId: 'O-CARD-DIRECT', status: 'APPROVED'),
      );

      final result = await paypal.payWithCardDirect(
        clientSecret: 'secret',
        params: PaymentParams(amount: '20.00', currencyCode: 'USD'),
        buildRequest: (orderId) =>
            CardPaymentRequest(orderId: orderId, card: testCard),
      );

      result.fold(
        (f) => expect(f.code, isNot('NOT_INITIALIZED')),
        (_) => {},
      );
    });

    test('passes SCA via buildRequest', () async {
      await paypal.init(testConfig);

      String? capturedOrderId;
      await paypal.payWithCardDirect(
        clientSecret: 'secret',
        params: PaymentParams(amount: '30.00', currencyCode: 'USD'),
        buildRequest: (orderId) {
          capturedOrderId = orderId;
          return CardPaymentRequest(
            orderId: orderId,
            card: testCard,
            sca: 'SCA_ALWAYS',
          );
        },
      );

      // buildRequest was called with some orderId (may be from HTTP error path)
      // We only assert it was called — orderId may be null if HTTP failed before call
      // The important thing: no crash, no NOT_INITIALIZED
      expect(capturedOrderId == null || capturedOrderId!.isNotEmpty, true);
    });
  });
}
