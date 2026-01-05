import 'package:coffee_http_client/coffee_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoffeeMockAdapter', () {
    test('dispatches to registered handler and records call', () async {
      final adapter = CoffeeMockAdapter();
      adapter.whenGet(
        '/ping',
        (request, headers) async => CoffeeRawResponse(
          statusCode: 200,
          headers: const {'h': '1'},
          body: 'pong',
          duration: Duration.zero,
        ),
      );

      final client = CoffeeHttp.create(
        CoffeeHttpConfig(
          baseUrl: CoffeeUri(
            host: 'example.com',
            scheme: CoffeeHttpScheme.https,
          ),
        ),
        adapter: adapter,
      );

      final response = await client.get('/ping');

      expect(response.statusCode, 200);
      expect(response.body, 'pong');
      expect(adapter.calls, hasLength(1));
      expect(adapter.calls.first.request.path, '/ping');
    });

    test('throws when no handler is registered', () async {
      final adapter = CoffeeMockAdapter();
      final client = CoffeeHttp.create(
        CoffeeHttpConfig(
          baseUrl: CoffeeUri(
            host: 'example.com',
            scheme: CoffeeHttpScheme.https,
          ),
        ),
        adapter: adapter,
      );

      await expectLater(
        () => client.get('/missing'),
        throwsA(
          isA<CoffeeHttpError>().having(
            (e) => e.underlying,
            'underlying',
            isA<StateError>(),
          ),
        ),
      );
    });

    test('uses fallback when provided', () async {
      final adapter = CoffeeMockAdapter(
        fallback: (request, headers) => CoffeeRawResponse(
          statusCode: 404,
          headers: const {},
          body: 'missing',
          duration: Duration.zero,
        ),
      );

      final client = CoffeeHttp.create(
        CoffeeHttpConfig(
          baseUrl: CoffeeUri(
            host: 'example.com',
            scheme: CoffeeHttpScheme.https,
          ),
        ),
        adapter: adapter,
      );

      final response = await client.get('/unknown');
      expect(response.statusCode, 404);
      expect(response.body, 'missing');
    });
  });
}
