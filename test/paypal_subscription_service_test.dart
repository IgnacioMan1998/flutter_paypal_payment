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

  PaypalSubscriptionService createService({
    required http_testing.MockClientHandler handler,
    PaypalConfig? overrideConfig,
  }) {
    return PaypalSubscriptionService(
      config: overrideConfig ?? config,
      clientSecret: 'test-client-secret',
      httpClient: http_testing.MockClient(handler),
    );
  }

  http.Response oauthSuccessResponse() => http.Response(
        jsonEncode({
          'access_token': 'test-token-123',
          'expires_in': 3600,
          'token_type': 'Bearer',
        }),
        200,
      );

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
  // Catalog Products
  // ═══════════════════════════════════════════════════════

  group('createProduct()', () {
    test('sends POST to /v1/catalogs/products and returns product data',
        () async {
      String? capturedPath;

      final service = createService(
        handler: withOAuth((request) {
          capturedPath = request.url.path;
          return http.Response(
            jsonEncode({
              'id': 'PROD-123',
              'name': 'Test Product',
              'type': 'SERVICE',
            }),
            201,
          );
        }),
      );

      final result = await service.createProduct({
        'name': 'Test Product',
        'type': 'SERVICE',
      });

      expect(result.isRight(), isTrue);
      final data =
          (result as Right<PaymentFailure, Map<String, dynamic>>).value;
      expect(data['id'], 'PROD-123');
      expect(capturedPath, PaypalApiConstants.productsPath);

      service.dispose();
    });

    test('returns Left on non-201 response', () async {
      final service = createService(
        handler: withOAuth((_) => http.Response('{"error":"bad"}', 400)),
      );

      final result = await service.createProduct({'name': 'Test'});

      expect(result.isLeft(), isTrue);
      final failure =
          (result as Left<PaymentFailure, Map<String, dynamic>>).value;
      expect(failure.code, PaypalErrorCodes.createProductError);

      service.dispose();
    });

    test('returns Left on OAuth failure', () async {
      final service = createService(
        handler: (_) async => http.Response('{"error":"auth"}', 401),
      );

      final result = await service.createProduct({'name': 'Test'});

      expect(result.isLeft(), isTrue);
      final failure =
          (result as Left<PaymentFailure, Map<String, dynamic>>).value;
      expect(failure.code, PaypalErrorCodes.authError);

      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // Billing Plans
  // ═══════════════════════════════════════════════════════

  group('createPlan()', () {
    test('sends POST to /v1/billing/plans and returns plan data', () async {
      String? capturedPath;

      final service = createService(
        handler: withOAuth((request) {
          capturedPath = request.url.path;
          return http.Response(
            jsonEncode({
              'id': 'P-123',
              'product_id': 'PROD-123',
              'name': 'Basic Plan',
              'status': 'ACTIVE',
            }),
            201,
          );
        }),
      );

      final result = await service.createPlan({
        'product_id': 'PROD-123',
        'name': 'Basic Plan',
        'billing_cycles': [],
      });

      expect(result.isRight(), isTrue);
      final data =
          (result as Right<PaymentFailure, Map<String, dynamic>>).value;
      expect(data['id'], 'P-123');
      expect(data['status'], 'ACTIVE');
      expect(capturedPath, PaypalApiConstants.plansPath);

      service.dispose();
    });

    test('returns Left on failure', () async {
      final service = createService(
        handler: withOAuth((_) => http.Response('{"error":"bad"}', 422)),
      );

      final result = await service.createPlan({'name': 'Test'});

      expect(result.isLeft(), isTrue);
      final failure =
          (result as Left<PaymentFailure, Map<String, dynamic>>).value;
      expect(failure.code, PaypalErrorCodes.createPlanError);

      service.dispose();
    });
  });

  group('getPlanDetails()', () {
    test('sends GET to /v1/billing/plans/{id} and returns data', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.method, 'GET');
          return http.Response(
            jsonEncode({
              'id': 'P-123',
              'name': 'Basic Plan',
              'status': 'ACTIVE',
            }),
            200,
          );
        }),
      );

      final result = await service.getPlanDetails('P-123');

      expect(result.isRight(), isTrue);
      final data =
          (result as Right<PaymentFailure, Map<String, dynamic>>).value;
      expect(data['name'], 'Basic Plan');

      service.dispose();
    });

    test('rejects invalid plan ID', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.getPlanDetails('INVALID ID!!');

      expect(result.isLeft(), isTrue);
      final failure =
          (result as Left<PaymentFailure, Map<String, dynamic>>).value;
      expect(failure.code, PaypalErrorCodes.validationError);

      service.dispose();
    });
  });

  group('updatePlan()', () {
    test('sends PATCH and returns Right on 204', () async {
      String? capturedMethod;

      final service = createService(
        handler: withOAuth((request) {
          capturedMethod = request.method;
          return http.Response('', 204);
        }),
      );

      final result = await service.updatePlan(
        'P-123',
        patchOperations: [
          {'op': 'replace', 'path': '/description', 'value': 'Updated'}
        ],
      );

      expect(result.isRight(), isTrue);
      expect(capturedMethod, 'PATCH');

      service.dispose();
    });

    test('returns Left on non-204 response', () async {
      final service = createService(
        handler: withOAuth((_) => http.Response('{"error":"bad"}', 400)),
      );

      final result = await service.updatePlan(
        'P-123',
        patchOperations: [
          {'op': 'replace', 'path': '/description', 'value': 'X'}
        ],
      );

      expect(result.isLeft(), isTrue);
      service.dispose();
    });
  });

  group('activatePlan() / deactivatePlan()', () {
    test('activatePlan sends POST to .../activate and returns Right on 204',
        () async {
      String? capturedPath;

      final service = createService(
        handler: withOAuth((request) {
          capturedPath = request.url.path;
          return http.Response('', 204);
        }),
      );

      final result = await service.activatePlan('P-123');

      expect(result.isRight(), isTrue);
      expect(capturedPath, contains('/activate'));

      service.dispose();
    });

    test('deactivatePlan sends POST to .../deactivate', () async {
      String? capturedPath;

      final service = createService(
        handler: withOAuth((request) {
          capturedPath = request.url.path;
          return http.Response('', 204);
        }),
      );

      final result = await service.deactivatePlan('P-123');

      expect(result.isRight(), isTrue);
      expect(capturedPath, contains('/deactivate'));

      service.dispose();
    });

    test('rejects invalid plan ID', () async {
      final service = createService(
        handler: (_) async => http.Response('', 204),
      );

      final result = await service.activatePlan('BAD ID!!');

      expect(result.isLeft(), isTrue);
      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // Subscriptions
  // ═══════════════════════════════════════════════════════

  group('createSubscription()', () {
    test('sends POST to /v1/billing/subscriptions and returns data', () async {
      String? capturedPath;

      final service = createService(
        handler: withOAuth((request) {
          capturedPath = request.url.path;
          return http.Response(
            jsonEncode({
              'id': 'I-SUB123',
              'plan_id': 'P-123',
              'status': 'APPROVAL_PENDING',
              'links': [
                {
                  'href': 'https://www.sandbox.paypal.com/webapps/billing/subscriptions?ba_token=BA-123',
                  'rel': 'approve',
                  'method': 'GET',
                },
              ],
            }),
            201,
          );
        }),
      );

      final result = await service.createSubscription({
        'plan_id': 'P-123',
        'application_context': {
          'return_url': 'https://example.com/return',
          'cancel_url': 'https://example.com/cancel',
        },
      });

      expect(result.isRight(), isTrue);
      final data =
          (result as Right<PaymentFailure, Map<String, dynamic>>).value;
      expect(data['id'], 'I-SUB123');
      expect(data['status'], 'APPROVAL_PENDING');
      expect(capturedPath, PaypalApiConstants.subscriptionsPath);

      service.dispose();
    });

    test('returns Left on failure', () async {
      final service = createService(
        handler: withOAuth((_) => http.Response('{"error":"bad"}', 400)),
      );

      final result =
          await service.createSubscription({'plan_id': 'P-123'});

      expect(result.isLeft(), isTrue);
      final failure =
          (result as Left<PaymentFailure, Map<String, dynamic>>).value;
      expect(failure.code, PaypalErrorCodes.createSubscriptionError);

      service.dispose();
    });
  });

  group('getSubscriptionDetails()', () {
    test('sends GET and returns subscription data', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.method, 'GET');
          return http.Response(
            jsonEncode({
              'id': 'I-SUB123',
              'plan_id': 'P-123',
              'status': 'ACTIVE',
              'subscriber': {
                'name': {'given_name': 'John'},
              },
            }),
            200,
          );
        }),
      );

      final result = await service.getSubscriptionDetails('I-SUB123');

      expect(result.isRight(), isTrue);
      final data =
          (result as Right<PaymentFailure, Map<String, dynamic>>).value;
      expect(data['status'], 'ACTIVE');

      service.dispose();
    });

    test('rejects invalid subscription ID', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.getSubscriptionDetails('INVALID!!');

      expect(result.isLeft(), isTrue);
      final failure =
          (result as Left<PaymentFailure, Map<String, dynamic>>).value;
      expect(failure.code, PaypalErrorCodes.validationError);

      service.dispose();
    });
  });

  group('activateSubscription()', () {
    test('sends POST to .../activate and returns Right on 204', () async {
      String? capturedPath;

      final service = createService(
        handler: withOAuth((request) {
          capturedPath = request.url.path;
          return http.Response('', 204);
        }),
      );

      final result = await service.activateSubscription('I-SUB123');

      expect(result.isRight(), isTrue);
      expect(capturedPath, contains('/activate'));

      service.dispose();
    });

    test('returns Left on failure', () async {
      final service = createService(
        handler: withOAuth((_) => http.Response('{"error":"bad"}', 422)),
      );

      final result = await service.activateSubscription('I-SUB123');

      expect(result.isLeft(), isTrue);
      final failure = (result as Left<PaymentFailure, void>).value;
      expect(failure.code, PaypalErrorCodes.subscriptionActionError);

      service.dispose();
    });
  });

  group('suspendSubscription()', () {
    test('sends POST with reason body to .../suspend', () async {
      String? capturedBody;

      final service = createService(
        handler: withOAuth((request) {
          capturedBody = request.body;
          return http.Response('', 204);
        }),
      );

      final result = await service.suspendSubscription(
        'I-SUB123',
        reason: 'Customer requested pause',
      );

      expect(result.isRight(), isTrue);
      final decoded = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(decoded['reason'], 'Customer requested pause');

      service.dispose();
    });

    test('rejects invalid subscription ID', () async {
      final service = createService(
        handler: (_) async => http.Response('', 204),
      );

      final result = await service.suspendSubscription(
        'BAD ID!!',
        reason: 'test',
      );

      expect(result.isLeft(), isTrue);
      service.dispose();
    });
  });

  group('cancelSubscription()', () {
    test('sends POST with reason body to .../cancel', () async {
      String? capturedPath;

      final service = createService(
        handler: withOAuth((request) {
          capturedPath = request.url.path;
          return http.Response('', 204);
        }),
      );

      final result = await service.cancelSubscription(
        'I-SUB123',
        reason: 'No longer needed',
      );

      expect(result.isRight(), isTrue);
      expect(capturedPath, contains('/cancel'));

      service.dispose();
    });
  });

  group('reviseSubscription()', () {
    test('sends POST to .../revise and returns revision data', () async {
      String? capturedPath;
      String? capturedBody;

      final service = createService(
        handler: withOAuth((request) {
          capturedPath = request.url.path;
          capturedBody = request.body;
          return http.Response(
            jsonEncode({
              'plan_id': 'P-NEW',
              'plan_overridden': true,
              'links': [
                {
                  'href': 'https://www.sandbox.paypal.com/webapps/billing/subscriptions/revise',
                  'rel': 'approve',
                  'method': 'GET',
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.reviseSubscription(
        'I-SUB123',
        revisionDetails: {
          'plan_id': 'P-NEW',
          'quantity': '2',
        },
      );

      expect(result.isRight(), isTrue);
      final data =
          (result as Right<PaymentFailure, Map<String, dynamic>>).value;
      expect(data['plan_id'], 'P-NEW');
      expect(capturedPath, contains('/revise'));
      final decoded = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(decoded['plan_id'], 'P-NEW');

      service.dispose();
    });

    test('returns Left on non-200 response', () async {
      final service = createService(
        handler: withOAuth((_) => http.Response('{"error":"bad"}', 422)),
      );

      final result = await service.reviseSubscription(
        'I-SUB123',
        revisionDetails: {'plan_id': 'P-NEW'},
      );

      expect(result.isLeft(), isTrue);
      service.dispose();
    });

    test('rejects invalid subscription ID', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.reviseSubscription(
        'INVALID!!',
        revisionDetails: {'plan_id': 'P-NEW'},
      );

      expect(result.isLeft(), isTrue);
      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // dispose
  // ═══════════════════════════════════════════════════════

  // ─── listProducts ───
  group('listProducts()', () {
    test('returns products list on 200', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.method, 'GET');
          expect(request.url.path, contains('/v1/catalogs/products'));
          return http.Response(
            jsonEncode({
              'products': [
                {'id': 'PROD-1', 'name': 'Product 1'}
              ],
              'total_items': 1,
            }),
            200,
          );
        }),
      );

      final result = await service.listProducts();
      expect(result.isRight(), isTrue);
      result.fold((_) {}, (data) {
        expect(data['total_items'], 1);
      });
      service.dispose();
    });

    test('passes query parameters correctly', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.url.queryParameters['page_size'], '5');
          expect(request.url.queryParameters['page'], '2');
          expect(request.url.queryParameters['total_required'], 'true');
          return http.Response(
            jsonEncode({'products': [], 'total_items': 0}),
            200,
          );
        }),
      );

      await service.listProducts(pageSize: 5, page: 2, totalRequired: true);
      service.dispose();
    });
  });

  // ─── getProductDetails ───
  group('getProductDetails()', () {
    test('returns product on 200', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.method, 'GET');
          expect(request.url.path, contains('/PROD-123'));
          return http.Response(
            jsonEncode({
              'id': 'PROD-123',
              'name': 'Test Product',
              'type': 'SERVICE',
            }),
            200,
          );
        }),
      );

      final result = await service.getProductDetails('PROD-123');
      expect(result.isRight(), isTrue);
      service.dispose();
    });

    test('rejects invalid product ID', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.getProductDetails('INVALID!!');
      expect(result.isLeft(), isTrue);
      service.dispose();
    });
  });

  // ─── updateProduct ───
  group('updateProduct()', () {
    test('returns Right on 204', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.method, 'PATCH');
          expect(request.url.path, contains('/PROD-123'));
          return http.Response('', 204);
        }),
      );

      final result = await service.updateProduct(
        'PROD-123',
        patchOperations: [
          {'op': 'replace', 'path': '/description', 'value': 'Updated'}
        ],
      );
      expect(result.isRight(), isTrue);
      service.dispose();
    });

    test('rejects invalid product ID', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.updateProduct(
        'BAD!!ID',
        patchOperations: [
          {'op': 'replace', 'path': '/description', 'value': 'x'}
        ],
      );
      expect(result.isLeft(), isTrue);
      service.dispose();
    });
  });

  // ─── listPlans ───
  group('listPlans()', () {
    test('returns plans list on 200', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.method, 'GET');
          expect(request.url.path, contains('/v1/billing/plans'));
          return http.Response(
            jsonEncode({
              'plans': [
                {'id': 'P-123', 'name': 'Basic Plan'}
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.listPlans();
      expect(result.isRight(), isTrue);
      service.dispose();
    });

    test('passes productId filter', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.url.queryParameters['product_id'], 'PROD-1');
          return http.Response(
            jsonEncode({'plans': []}),
            200,
          );
        }),
      );

      await service.listPlans(productId: 'PROD-1');
      service.dispose();
    });
  });

  // ─── updatePlanPricing ───
  group('updatePlanPricing()', () {
    test('returns Right on 204', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.method, 'POST');
          expect(request.url.path, contains('/update-pricing-schemes'));
          return http.Response('', 204);
        }),
      );

      final result = await service.updatePlanPricing(
        'P-PLAN123',
        pricingSchemes: [
          {
            'billing_cycle_sequence': 1,
            'pricing_scheme': {
              'fixed_price': {'value': '15', 'currency_code': 'USD'}
            },
          }
        ],
      );
      expect(result.isRight(), isTrue);
      service.dispose();
    });

    test('rejects invalid plan ID', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.updatePlanPricing(
        'BAD!!',
        pricingSchemes: [],
      );
      expect(result.isLeft(), isTrue);
      service.dispose();
    });
  });

  // ─── listSubscriptions ───
  group('listSubscriptions()', () {
    test('returns subscriptions list on 200', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.method, 'GET');
          expect(request.url.path, contains('/v1/billing/subscriptions'));
          return http.Response(
            jsonEncode({
              'subscriptions': [
                {'id': 'I-SUB1', 'status': 'ACTIVE'}
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.listSubscriptions();
      expect(result.isRight(), isTrue);
      service.dispose();
    });

    test('passes filter parameters', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.url.queryParameters['plan_ids'], 'P-123');
          expect(request.url.queryParameters['statuses'], 'ACTIVE');
          return http.Response(
            jsonEncode({'subscriptions': []}),
            200,
          );
        }),
      );

      await service.listSubscriptions(planIds: 'P-123', statuses: 'ACTIVE');
      service.dispose();
    });
  });

  // ─── updateSubscription ───
  group('updateSubscription()', () {
    test('returns Right on 204', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.method, 'PATCH');
          expect(request.url.path, contains('/I-SUB123'));
          return http.Response('', 204);
        }),
      );

      final result = await service.updateSubscription(
        'I-SUB123',
        patchOperations: [
          {'op': 'replace', 'path': '/custom_id', 'value': 'new-id'}
        ],
      );
      expect(result.isRight(), isTrue);
      service.dispose();
    });

    test('rejects invalid subscription ID', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.updateSubscription(
        'BAD!!',
        patchOperations: [
          {'op': 'replace', 'path': '/custom_id', 'value': 'x'}
        ],
      );
      expect(result.isLeft(), isTrue);
      service.dispose();
    });
  });

  // ─── captureSubscriptionPayment ───
  group('captureSubscriptionPayment()', () {
    test('returns Right on 202', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.method, 'POST');
          expect(request.url.path, contains('/I-SUB123/capture'));
          return http.Response('', 202);
        }),
      );

      final result = await service.captureSubscriptionPayment(
        'I-SUB123',
        captureRequest: {
          'note': 'Charging balance',
          'capture_type': 'OUTSTANDING_BALANCE',
          'amount': {'currency_code': 'USD', 'value': '100'},
        },
      );
      expect(result.isRight(), isTrue);
      service.dispose();
    });

    test('returns failure on non-202', () async {
      final service = createService(
        handler: withOAuth((_) => http.Response('{"error": "bad"}', 400)),
      );

      final result = await service.captureSubscriptionPayment(
        'I-SUB123',
        captureRequest: {
          'note': 'test',
          'capture_type': 'OUTSTANDING_BALANCE',
          'amount': {'currency_code': 'USD', 'value': '10'},
        },
      );
      expect(result.isLeft(), isTrue);
      service.dispose();
    });

    test('rejects invalid subscription ID', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.captureSubscriptionPayment(
        'BAD!!',
        captureRequest: {'note': 'test'},
      );
      expect(result.isLeft(), isTrue);
      service.dispose();
    });
  });

  // ─── listSubscriptionTransactions ───
  group('listSubscriptionTransactions()', () {
    test('returns transactions on 200', () async {
      final service = createService(
        handler: withOAuth((request) {
          expect(request.method, 'GET');
          expect(request.url.path, contains('/I-SUB123/transactions'));
          expect(request.url.queryParameters['start_time'],
              '2024-01-01T00:00:00Z');
          expect(request.url.queryParameters['end_time'],
              '2024-12-31T23:59:59Z');
          return http.Response(
            jsonEncode({
              'transactions': [
                {
                  'id': 'TXN-1',
                  'status': 'COMPLETED',
                  'amount_with_breakdown': {
                    'gross_amount': {'currency_code': 'USD', 'value': '10.00'}
                  }
                }
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.listSubscriptionTransactions(
        'I-SUB123',
        startTime: '2024-01-01T00:00:00Z',
        endTime: '2024-12-31T23:59:59Z',
      );
      expect(result.isRight(), isTrue);
      result.fold((_) {}, (data) {
        expect((data['transactions'] as List).length, 1);
      });
      service.dispose();
    });

    test('returns failure on non-200', () async {
      final service = createService(
        handler: withOAuth((_) => http.Response('{"error": "bad"}', 500)),
      );

      final result = await service.listSubscriptionTransactions(
        'I-SUB123',
        startTime: '2024-01-01T00:00:00Z',
        endTime: '2024-12-31T23:59:59Z',
      );
      expect(result.isLeft(), isTrue);
      service.dispose();
    });

    test('rejects invalid subscription ID', () async {
      final service = createService(
        handler: (_) async => http.Response('', 200),
      );

      final result = await service.listSubscriptionTransactions(
        'BAD!!',
        startTime: '2024-01-01T00:00:00Z',
        endTime: '2024-12-31T23:59:59Z',
      );
      expect(result.isLeft(), isTrue);
      service.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════
  // dispose (original)
  // ═══════════════════════════════════════════════════════

  group('dispose()', () {
    test('clears cached token', () async {
      final service = createService(
        handler: withOAuth((_) => http.Response(
              jsonEncode({'id': 'PROD-1', 'name': 'Test'}), 201)),
      );

      await service.createProduct({'name': 'Test', 'type': 'SERVICE'});

      service.dispose();
    });
  });
}
