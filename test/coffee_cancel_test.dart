import 'package:coffee_http_client/src/models/cancellation_token.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_http_client/coffee_http_client.dart';

void main() {
  group('CoffeeCancellationToken', () {
    test('starts not cancelled', () {
      final token = CoffeeCancellationToken();
      expect(token.isCancelled, isFalse);
      expect(token.reason, isNull);
    });

    test('cancel sets state and completes whenCancelled', () async {
      final token = CoffeeCancellationToken();

      final future = token.whenCancelled;

      token.cancel('user navigated away');

      expect(token.isCancelled, isTrue);
      expect(token.reason, 'user navigated away');

      await expectLater(future, completes);
    });

    test('cancel is idempotent', () async {
      final token = CoffeeCancellationToken();

      token.cancel('first');
      token.cancel('second'); // should not override or crash

      expect(token.isCancelled, isTrue);
      expect(token.reason, 'first');

      await expectLater(token.whenCancelled, completes);
    });

    test('throwIfCancelled does nothing when not cancelled', () {
      final token = CoffeeCancellationToken();
      expect(() => token.throwIfCancelled(), returnsNormally);
    });

    test('throwIfCancelled throws CoffeeRequestCancelled when cancelled', () {
      final token = CoffeeCancellationToken();
      token.cancel('stop');

      expect(() => token.throwIfCancelled(), throwsA(isA<CoffeeRequestCancelled>()));

      try {
        token.throwIfCancelled();
      } catch (e) {
        final err = e as CoffeeRequestCancelled;
        expect(err.reason, 'stop');
      }
    });
  });

  group('CoffeeHttp cancellation lifecycle', () {
    test('cancel before send -> onCancel (beforeSend), no adapter call', () async {
      final adapter = CoffeeMockAdapter();
      adapter.whenGet('/ping', (req, headers) {
        return CoffeeRawResponse(statusCode: 200, headers: const {}, body: 'ok', duration: Duration.zero);
      });

      final cancelCalls = <CoffeeCancelContext>[];
      final errorCalls = <CoffeeErrorContext>[];
      final responseCalls = <CoffeeResponseContext>[];

      final client = CoffeeHttp.create(
        CoffeeHttpConfig(
          baseUrl: CoffeeUri(host: 'example.com', scheme: CoffeeHttpScheme.https),
          hooks: CoffeeHooks(onCancel: cancelCalls.add, onError: errorCalls.add, onResponse: responseCalls.add),
        ),
        adapter: adapter,
      );

      final token = CoffeeCancellationToken()..cancel('pre-cancel');

      final req = CoffeeRequest(method: CoffeeHttpMethod.get, path: '/ping', cancellationToken: token);

      await expectLater(() => client.request(req), throwsA(isA<CoffeeRequestCancelled>()));

      expect(adapter.calls, isEmpty, reason: 'transport should not run');
      expect(errorCalls, isEmpty, reason: 'cancel is not an error');
      expect(responseCalls, isEmpty, reason: 'cancelled requests must not call onResponse');

      expect(cancelCalls.length, 1);
      expect(cancelCalls.single.phase, CoffeeCancelPhase.beforeSend);
      expect(cancelCalls.single.error.reason, 'pre-cancel');
    });

    test('cancel during inFlight -> onCancel (inFlight), adapter called once', () async {
      final adapter = CoffeeMockAdapter();

      // Handler waits a bit so we can cancel while request is "in flight".
      adapter.whenGet('/slow', (req, headers) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return CoffeeRawResponse(statusCode: 200, headers: const {}, body: 'ok', duration: Duration.zero);
      });

      final cancelCalls = <CoffeeCancelContext>[];
      final errorCalls = <CoffeeErrorContext>[];
      final responseCalls = <CoffeeResponseContext>[];

      final client = CoffeeHttp.create(
        CoffeeHttpConfig(
          baseUrl: CoffeeUri(host: 'example.com', scheme: CoffeeHttpScheme.https),
          hooks: CoffeeHooks(onCancel: cancelCalls.add, onError: errorCalls.add, onResponse: responseCalls.add),
        ),
        adapter: adapter,
      );

      final token = CoffeeCancellationToken();

      final req = CoffeeRequest(method: CoffeeHttpMethod.get, path: '/slow', cancellationToken: token);

      // Start request and cancel shortly after.
      final future = client.request(req);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      token.cancel('user left screen');

      await expectLater(() => future, throwsA(isA<CoffeeRequestCancelled>()));

      expect(adapter.calls.length, 1);
      expect(errorCalls, isEmpty, reason: 'cancel is not an error');
      expect(responseCalls, isEmpty, reason: 'cancelled requests must not call onResponse');

      expect(cancelCalls.length, 1);
      expect(cancelCalls.single.phase, anyOf(CoffeeCancelPhase.inFlight, CoffeeCancelPhase.afterSend));
      expect(cancelCalls.single.error.reason, 'user left screen');
    });

    test('cancel after response (before onResponse) -> onCancel (afterSend), no onResponse', () async {
      final adapter = CoffeeMockAdapter();

      adapter.whenGet('/fast', (req, headers) {
        req.cancellationToken?.cancel('late cancel');

        return CoffeeRawResponse(statusCode: 200, headers: const {}, body: 'ok', duration: Duration.zero);
      });

      final cancelCalls = <CoffeeCancelContext>[];
      final errorCalls = <CoffeeErrorContext>[];
      final responseCalls = <CoffeeResponseContext>[];

      final client = CoffeeHttp.create(
        CoffeeHttpConfig(
          baseUrl: CoffeeUri(host: 'example.com', scheme: CoffeeHttpScheme.https),
          hooks: CoffeeHooks(onCancel: cancelCalls.add, onError: errorCalls.add, onResponse: responseCalls.add),
        ),
        adapter: adapter,
      );

      final token = CoffeeCancellationToken();

      final req = CoffeeRequest(method: CoffeeHttpMethod.get, path: '/fast', cancellationToken: token);

      await expectLater(() => client.request(req), throwsA(isA<CoffeeRequestCancelled>()));

      expect(adapter.calls.length, 1);
      expect(errorCalls, isEmpty);
      expect(responseCalls, isEmpty);

      expect(cancelCalls.length, 1);
      expect(cancelCalls.single.phase, CoffeeCancelPhase.afterSend);
      expect(cancelCalls.single.error.reason, 'late cancel');
    });
  });
}
