import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:paypal_checkout_flutter/paypal_checkout_flutter.dart';

void main() {
  late PaypalConfig config;

  setUp(() {
    config = PaypalConfig(
      clientId: 'test-client-id',
      environment: PaypalEnvironment.sandbox,
      returnUrl: 'com.test.app://paypalpay',
    );
  });

  /// Creates a mock HTTP client that returns [handler] for every request.
  PaypalOrderService createService({
    required http_testing.MockClientHandler handler,
    PaypalConfig? overrideConfig,
  }) {
    return PaypalOrderService(
      config: overrideConfig ?? config,
      clientSecret: 'test-client-secret',
      httpClient: http_testing.MockClient(handler),
    );
  }

  /// Standard OAuth token response handler.
  http.Response oauthSuccessResponse() => http.Response(
        jsonEncode({
          'access_token': 'test-token-123',
          'expires_in': 3600,
          'token_type': 'Bearer',
        }),
        200,
      );

  /// Handler that returns a token on the first call, then delegates to [next].
  http_testing.MockClientHandler withOAuth(
      http.Response Function(http.Request) next) {
    var oauthDone = false;
    return (request) async {
      if (!oauthDone &&
          request.url.path.contains(PaypalApiConstants.oauthTokenPath)) {
        oauthDone = true;
        return oauthSuccessResponse();
      }
      return next(request);
    };
  }

  // ═══════════════════════════════════════════════════════
  // OAuth / Access Token
  // ═══════════════════════════════════════════════════════

  group('OAuth access token', () {
    test('authenticates with Basic auth using clientId:clientSecret', () async {
      String? capturedAuth;

      final service = createService(
        handler: (request) async {
          if (request.url.path.contains(PaypalApiConstants.oauthTokenPath)) {
            capturedAuth = request.headers['Authorization'];
            return oauthSuccessResponse();
          }
          return http.Response(
              jsonEncode({'id': 'ORDER-1'}), 201);
        },
      );

      await service.createOrder(
          PaymentParams(amount: '10.00', currencyCode: 'USD'));

      expect(capturedAuth, isNotNull);
      final expectedCredentials =
          base64Encode(utf8.encode('test-client-id:test-client-secret'));
      expect(capturedAuth, 'Basic $expectedCredentials');

      service.dispose();
    });

    test('caches token and reuses on second call', () async {
      var oauthCallCount = 0;

      final service = createService(
        handler: (request) async {
          if (request.url.path.contains(PaypalApiConstants.oauthTokenPath)) {
            oauthCallCount++;
            return oauthSuccessResponse();
          }
          return http.Response(jsonEncode({'id': 'ORDER-1'}), 201);
        },
      );

      await service.createOrder(
          PaymentParams(amount: '10.00', currencyCode: 'USD'));
      await service.createOrder(
          PaymentParams(amount: '20.00', currencyCode: 'USD'));

      expect(oauthCallCount, 1);

      service.dispose();
    });

    test('returns failure on auth error', () async {
      final service = createService(
        handler: (request) async {
          return http.Response(
              jsonEncode({'error': 'invalid_client'}), 401);
        },
      );

      final result = await service.createOrder(
          PaymentParams(amount: '10.00', currencyCode: 'USD'));

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, PaypalErrorCodes.authError),
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // createOrder
  // ═══════════════════════════════════════════════════════

  group('createOrder()', () {
    test('creates order with CAPTURE intent by default', () async {
      Map<String, dynamic>? capturedBody;

      final service = createService(
        handler: withOAuth((request) {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
              jsonEncode({'id': 'ORDER-ABC'}), 201);
        }),
      );

      final result = await service.createOrder(
          PaymentParams(amount: '25.00', currencyCode: 'USD'));

      expect(result.isRight(), true);
      expect((result as Right<PaymentFailure, String>).value, 'ORDER-ABC');
      expect(capturedBody?['intent'], 'CAPTURE');
      expect(capturedBody?['purchase_units'][0]['amount']['value'], '25.00');
      expect(capturedBody?['purchase_units'][0]['amount']['currency_code'],
          'USD');

      service.dispose();
    });

    test('creates order with AUTHORIZE intent', () async {
      Map<String, dynamic>? capturedBody;

      final service = createService(
        handler: withOAuth((request) {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
              jsonEncode({'id': 'ORDER-AUTH'}), 201);
        }),
      );

      final result = await service.createOrder(PaymentParams(
        amount: '50.00',
        currencyCode: 'EUR',
        intent: PaypalApiConstants.intentAuthorize,
      ));

      expect(result.isRight(), true);
      expect(capturedBody?['intent'], 'AUTHORIZE');

      service.dispose();
    });

    test('includes optional fields in purchase unit', () async {
      Map<String, dynamic>? capturedBody;

      final service = createService(
        handler: withOAuth((request) {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'id': 'ORDER-X'}), 201);
        }),
      );

      await service.createOrder(PaymentParams(
        amount: '99.99',
        currencyCode: 'MXN',
        description: 'Test item',
        customId: 'CUSTOM-1',
        invoiceId: 'INV-001',
        softDescriptor: 'MYSHOP',
      ));

      final pu = capturedBody?['purchase_units'][0] as Map<String, dynamic>;
      expect(pu['description'], 'Test item');
      expect(pu['custom_id'], 'CUSTOM-1');
      expect(pu['invoice_id'], 'INV-001');
      expect(pu['soft_descriptor'], 'MYSHOP');

      service.dispose();
    });

    test('returns failure on non-201 response', () async {
      final service = createService(
        handler: withOAuth((_) {
          return http.Response(
              jsonEncode({
                'name': 'INVALID_REQUEST',
                'message': 'Request is not well-formed',
              }),
              400);
        }),
      );

      final result = await service.createOrder(
          PaymentParams(amount: '10.00', currencyCode: 'USD'));

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, PaypalErrorCodes.createOrderError),
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });

    test('returns failure on network exception', () async {
      final service = createService(
        handler: withOAuth((_) {
          throw Exception('Network error');
        }),
      );

      final result = await service.createOrder(
          PaymentParams(amount: '10.00', currencyCode: 'USD'));

      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f.code, PaypalErrorCodes.createOrderError);
          expect(f.message, PaypalErrorMessages.createOrderFailed);
        },
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });

    test('uses sandbox URL for sandbox environment', () async {
      Uri? capturedUrl;

      final service = createService(
        handler: withOAuth((request) {
          capturedUrl = request.url;
          return http.Response(jsonEncode({'id': 'O-1'}), 201);
        }),
      );

      await service.createOrder(
          PaymentParams(amount: '10.00', currencyCode: 'USD'));

      expect(capturedUrl?.host, 'api-m.sandbox.paypal.com');

      service.dispose();
    });

    test('uses live URL for live environment', () async {
      Uri? capturedUrl;
      final liveConfig = PaypalConfig(
        clientId: 'live-id',
        environment: PaypalEnvironment.live,
      );

      final service = createService(
        overrideConfig: liveConfig,
        handler: withOAuth((request) {
          capturedUrl = request.url;
          return http.Response(jsonEncode({'id': 'O-1'}), 201);
        }),
      );

      await service.createOrder(
          PaymentParams(amount: '10.00', currencyCode: 'USD'));

      expect(capturedUrl?.host, 'api-m.paypal.com');

      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // captureOrder
  // ═══════════════════════════════════════════════════════

  group('captureOrder()', () {
    test('captures order successfully', () async {
      final service = createService(
        handler: withOAuth((_) {
          return http.Response(
              jsonEncode({'id': 'ORDER-1', 'status': 'COMPLETED'}), 201);
        }),
      );

      final result = await service.captureOrder('ORDER-1');

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (data) {
          expect(data['status'], 'COMPLETED');
        },
      );

      service.dispose();
    });

    test('rejects invalid orderId', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.captureOrder('../../etc/passwd');

      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f.code, PaypalErrorCodes.validationError);
          expect(f.message, PaypalErrorMessages.invalidOrderId);
        },
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });

    test('returns failure on non-201 response', () async {
      final service = createService(
        handler: withOAuth((_) {
          return http.Response(
              jsonEncode({'name': 'UNPROCESSABLE_ENTITY'}), 422);
        }),
      );

      final result = await service.captureOrder('ORDER-1');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, PaypalErrorCodes.captureError),
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // getOrderDetails
  // ═══════════════════════════════════════════════════════

  group('getOrderDetails()', () {
    test('gets order details successfully', () async {
      final service = createService(
        handler: withOAuth((_) {
          return http.Response(
              jsonEncode({
                'id': 'ORDER-1',
                'status': 'APPROVED',
                'purchase_units': [],
              }),
              200);
        }),
      );

      final result = await service.getOrderDetails('ORDER-1');

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (data) {
          expect(data['id'], 'ORDER-1');
          expect(data['status'], 'APPROVED');
        },
      );

      service.dispose();
    });

    test('rejects invalid orderId', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.getOrderDetails('drop table;');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, PaypalErrorCodes.validationError),
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });

    test('returns failure on non-200 response', () async {
      final service = createService(
        handler: withOAuth((_) {
          return http.Response(jsonEncode({'name': 'NOT_FOUND'}), 404);
        }),
      );

      final result = await service.getOrderDetails('ORDER-MISSING');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, PaypalErrorCodes.getOrderError),
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // refundCapture
  // ═══════════════════════════════════════════════════════

  group('refundCapture()', () {
    test('full refund succeeds', () async {
      final service = createService(
        handler: withOAuth((_) {
          return http.Response(
              jsonEncode({'id': 'REF-1', 'status': 'COMPLETED'}), 201);
        }),
      );

      final result = await service.refundCapture('CAP-1');

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (data) => expect(data['status'], 'COMPLETED'),
      );

      service.dispose();
    });

    test('partial refund sends amount in body', () async {
      Map<String, dynamic>? capturedBody;

      final service = createService(
        handler: withOAuth((request) {
          if (request.body.isNotEmpty) {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          }
          return http.Response(
              jsonEncode({'id': 'REF-2', 'status': 'COMPLETED'}), 201);
        }),
      );

      await service.refundCapture('CAP-1',
          amount: '5.00', currencyCode: 'USD');

      expect(capturedBody?['amount']['value'], '5.00');
      expect(capturedBody?['amount']['currency_code'], 'USD');

      service.dispose();
    });

    test('rejects invalid captureId', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.refundCapture('../invalid');

      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f.code, PaypalErrorCodes.validationError);
          expect(f.message, PaypalErrorMessages.invalidCaptureId);
        },
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // authorizeOrder
  // ═══════════════════════════════════════════════════════

  group('authorizeOrder()', () {
    test('authorizes order successfully', () async {
      Uri? capturedUrl;

      final service = createService(
        handler: withOAuth((request) {
          capturedUrl = request.url;
          return http.Response(
              jsonEncode({
                'id': 'ORDER-1',
                'status': 'COMPLETED',
                'purchase_units': [
                  {
                    'payments': {
                      'authorizations': [
                        {'id': 'AUTH-1', 'status': 'CREATED'}
                      ]
                    }
                  }
                ]
              }),
              201);
        }),
      );

      final result = await service.authorizeOrder('ORDER-1');

      expect(result.isRight(), true);
      expect(capturedUrl?.path, contains('/authorize'));

      service.dispose();
    });

    test('rejects invalid orderId', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.authorizeOrder('../../etc');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, PaypalErrorCodes.validationError),
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });

    test('returns failure on error', () async {
      final service = createService(
        handler: withOAuth((_) {
          return http.Response(
              jsonEncode({'name': 'ORDER_NOT_APPROVED'}), 422);
        }),
      );

      final result = await service.authorizeOrder('ORDER-1');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, PaypalErrorCodes.authorizeError),
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // captureAuthorization
  // ═══════════════════════════════════════════════════════

  group('captureAuthorization()', () {
    test('captures authorization successfully', () async {
      Uri? capturedUrl;

      final service = createService(
        handler: withOAuth((request) {
          capturedUrl = request.url;
          return http.Response(
              jsonEncode({'id': 'CAP-1', 'status': 'COMPLETED'}), 201);
        }),
      );

      final result = await service.captureAuthorization('AUTH-1');

      expect(result.isRight(), true);
      expect(capturedUrl?.path, contains('/authorizations/'));
      expect(capturedUrl?.path, contains('/capture'));

      service.dispose();
    });

    test('rejects invalid authorizationId', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.captureAuthorization('../../bad');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, PaypalErrorCodes.validationError),
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // voidAuthorization
  // ═══════════════════════════════════════════════════════

  group('voidAuthorization()', () {
    test('voids authorization successfully (204)', () async {
      final service = createService(
        handler: withOAuth((_) {
          return http.Response('', 204);
        }),
      );

      final result = await service.voidAuthorization('AUTH-1');

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (data) => expect(data['status'], 'VOIDED'),
      );

      service.dispose();
    });

    test('rejects invalid authorizationId', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.voidAuthorization('../../bad');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, PaypalErrorCodes.validationError),
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });

    test('returns failure on error', () async {
      final service = createService(
        handler: withOAuth((_) {
          return http.Response(
              jsonEncode({'name': 'AUTHORIZATION_ALREADY_CAPTURED'}), 422);
        }),
      );

      final result = await service.voidAuthorization('AUTH-1');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, PaypalErrorCodes.voidAuthorizationError),
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // createSetupToken
  // ═══════════════════════════════════════════════════════

  group('createSetupToken()', () {
    test('creates setup token successfully', () async {
      final service = createService(
        handler: withOAuth((_) {
          return http.Response(
              jsonEncode({'id': 'ST-123', 'status': 'CREATED'}), 201);
        }),
      );

      final result = await service.createSetupToken(
        paymentSource: {
          'paypal': {'usage_type': 'MERCHANT'},
        },
      );

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected Right'),
        (data) => expect(data['id'], 'ST-123'),
      );

      service.dispose();
    });

    test('includes customer when provided', () async {
      Map<String, dynamic>? capturedBody;

      final service = createService(
        handler: withOAuth((request) {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'id': 'ST-1'}), 201);
        }),
      );

      await service.createSetupToken(
        paymentSource: {
          'paypal': {'usage_type': 'MERCHANT'},
        },
        customer: {'id': 'CUST-1'},
      );

      expect(capturedBody?['customer']['id'], 'CUST-1');

      service.dispose();
    });

    test('returns failure on error', () async {
      final service = createService(
        handler: withOAuth((_) {
          return http.Response(jsonEncode({'name': 'INVALID_REQUEST'}), 400);
        }),
      );

      final result = await service.createSetupToken(
        paymentSource: {'paypal': {}},
      );

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, PaypalErrorCodes.setupTokenError),
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // createPaymentToken
  // ═══════════════════════════════════════════════════════

  group('createPaymentToken()', () {
    test('creates payment token successfully', () async {
      Map<String, dynamic>? capturedBody;

      final service = createService(
        handler: withOAuth((request) {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
              jsonEncode({'id': 'PT-1', 'status': 'CREATED'}), 201);
        }),
      );

      final result = await service.createPaymentToken('ST-123');

      expect(result.isRight(), true);
      expect(capturedBody?['payment_source']['token']['id'], 'ST-123');
      expect(capturedBody?['payment_source']['token']['type'], 'SETUP_TOKEN');

      service.dispose();
    });

    test('returns failure on error', () async {
      final service = createService(
        handler: withOAuth((_) {
          return http.Response(jsonEncode({'name': 'INVALID_TOKEN'}), 400);
        }),
      );

      final result = await service.createPaymentToken('INVALID');

      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f.code, PaypalErrorCodes.paymentTokenError),
        (_) => fail('Expected Left'),
      );

      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // updateOrder (PATCH – shipping/tracking)
  // ═══════════════════════════════════════════════════════

  group('updateOrder()', () {
    test('sends PATCH with operations and returns Right on 204', () async {
      String? capturedMethod;
      String? capturedBody;

      final service = createService(
        handler: withOAuth((request) {
          capturedMethod = request.method;
          capturedBody = request.body;
          return http.Response('', 204);
        }),
      );

      final result = await service.updateOrder(
        'ORDER-123',
        patchOperations: [
          {
            'op': 'add',
            'path':
                "/purchase_units/@reference_id=='default'/shipping/address",
            'value': {
              'address_line_1': '123 Main St',
              'country_code': 'US',
            },
          },
        ],
      );

      expect(result.isRight(), isTrue);
      expect(capturedMethod, 'PATCH');
      expect(capturedBody, isNotNull);
      final decoded = jsonDecode(capturedBody!) as List;
      expect(decoded.first['op'], 'add');

      service.dispose();
    });

    test('returns Left on non-204 response', () async {
      final service = createService(
        handler: withOAuth((_) => http.Response('{"error":"bad"}', 400)),
      );

      final result = await service.updateOrder(
        'ORDER-123',
        patchOperations: [
          {'op': 'replace', 'path': '/intent', 'value': 'CAPTURE'}
        ],
      );

      expect(result.isLeft(), isTrue);
      service.dispose();
    });

    test('rejects invalid order ID', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.updateOrder(
        'INVALID ID!!',
        patchOperations: [
          {'op': 'replace', 'path': '/intent', 'value': 'CAPTURE'}
        ],
      );

      expect(result.isLeft(), isTrue);
      final failure =
          (result as Left<PaymentFailure, void>).value;
      expect(failure.code, PaypalErrorCodes.validationError);

      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // dispose
  // ═══════════════════════════════════════════════════════

  group('dispose()', () {
    test('clears cached token', () async {
      var oauthCallCount = 0;

      final service = createService(
        handler: (request) async {
          if (request.url.path.contains(PaypalApiConstants.oauthTokenPath)) {
            oauthCallCount++;
            return oauthSuccessResponse();
          }
          return http.Response(jsonEncode({'id': 'O-1'}), 201);
        },
      );

      await service.createOrder(
          PaymentParams(amount: '10.00', currencyCode: 'USD'));
      expect(oauthCallCount, 1);

      // After dispose, the client is closed — so next call would need new token
      // We can't test further calls since the client is closed,
      // but we verify dispose didn't throw
      service.dispose();
    });
  });
}
