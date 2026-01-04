import 'dart:async';

import 'package:coffee_http_client/src/adapters/adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_http_client/coffee_http_client.dart';

void main() {
  group('CoffeeHttp (with injected adapter)', () {
    test('request() merges headers in correct order', () async {
      final adapter = _CapturingAdapter(
        response: CoffeeRawResponse(statusCode: 200, headers: const {}, body: 'ok', duration: Duration.zero),
      );

      final client = CoffeeHttp.create(
        CoffeeHttpConfig(
          baseUrl: CoffeeUri(host: 'example.com', scheme: CoffeeHttpScheme.https),
          defaultHeaders: const {'A': 'default', 'X': 'default'},
          headersBuilder: (req) async => {'A': 'builder', 'B': 'builder'},
        ),
        adapter: adapter,
      );

      final req = CoffeeRequest(method: CoffeeHttpMethod.get, path: '/x', headers: const {'A': 'request', 'C': 'request'});

      await client.request(req);

      // precedence: default < builder < request
      expect(adapter.lastHeaders, isNotNull);
      expect(adapter.lastHeaders!['X'], 'default');
      expect(adapter.lastHeaders!['B'], 'builder');
      expect(adapter.lastHeaders!['C'], 'request');
      expect(adapter.lastHeaders!['A'], 'request'); // request wins
    });

    test('request() calls onResponse with timed response', () async {
      CoffeeResponseContext? seen;

      final adapter = _FixedAdapter(CoffeeRawResponse(statusCode: 201, headers: const {'h': '1'}, body: 'hello', duration: Duration.zero));

      final client = CoffeeHttp.create(
        CoffeeHttpConfig(
          baseUrl: CoffeeUri(host: 'example.com', scheme: CoffeeHttpScheme.https),
          hooks: CoffeeHooks(onResponse: (ctx) => seen = ctx),
        ),
        adapter: adapter,
      );

      final res = await client.get('/ping');

      expect(res.statusCode, 201);
      expect(seen, isNotNull);
      expect(seen!.request.path, '/ping');
      expect(seen!.response.statusCode, 201);
      expect(seen!.response.duration.inMicroseconds, greaterThan(0));
    });

    test('request() maps TimeoutException to CoffeeHttpErrorKind.timeout and calls onError', () async {
      CoffeeErrorContext? seen;

      final adapter = _ThrowingAdapter(() => throw TimeoutException('timed out'));

      final client = CoffeeHttp.create(
        CoffeeHttpConfig(
          baseUrl: CoffeeUri(host: 'example.com', scheme: CoffeeHttpScheme.https),
          hooks: CoffeeHooks(onError: (ctx) => seen = ctx),
        ),
        adapter: adapter,
      );

      try {
        await client.get('/timeout');
        fail('Expected CoffeeHttpError');
      } on CoffeeHttpError catch (e) {
        expect(e.kind, CoffeeHttpErrorKind.timeout);
      }

      expect(seen, isNotNull);
      expect(seen!.request.path, '/timeout');
      expect(seen!.error.kind, CoffeeHttpErrorKind.timeout);
    });

    test('request() maps other exceptions to CoffeeHttpErrorKind.network and calls onError', () async {
      CoffeeErrorContext? seen;

      final adapter = _ThrowingAdapter(() => throw Exception('no internet'));

      final client = CoffeeHttp.create(
        CoffeeHttpConfig(
          baseUrl: CoffeeUri(host: 'example.com', scheme: CoffeeHttpScheme.https),
          hooks: CoffeeHooks(onError: (ctx) => seen = ctx),
        ),
        adapter: adapter,
      );

      try {
        await client.get('/network');
        fail('Expected CoffeeHttpError');
      } on CoffeeHttpError catch (e) {
        expect(e.kind, CoffeeHttpErrorKind.network);
      }

      expect(seen, isNotNull);
      expect(seen!.request.path, '/network');
      expect(seen!.error.kind, CoffeeHttpErrorKind.network);
    });

    test('get() builds a GET CoffeeRequest correctly', () async {
      final adapter = _CapturingAdapter(
        response: CoffeeRawResponse(statusCode: 200, headers: const {}, body: 'ok', duration: Duration.zero),
      );

      final client = CoffeeHttp.create(
        CoffeeHttpConfig(
          baseUrl: CoffeeUri(host: 'example.com', scheme: CoffeeHttpScheme.https),
        ),
        adapter: adapter,
      );

      await client.get('/users/me', name: 'user.me', tags: {'auth'}, query: {'x': '1'}, headers: {'H': '1'});

      expect(adapter.lastRequest, isNotNull);
      expect(adapter.lastRequest!.method, CoffeeHttpMethod.get);
      expect(adapter.lastRequest!.path, '/users/me');
      expect(adapter.lastRequest!.name, 'user.me');
      expect(adapter.lastRequest!.tags, contains('auth'));
      expect(adapter.lastRequest!.query['x'], '1');
      expect(adapter.lastRequest!.headers['H'], '1');
    });

    test('getHandled<T>() uses handleResponse and returns typed result', () async {
      final adapter = _FixedAdapter(CoffeeRawResponse(statusCode: 200, headers: const {}, body: '{"ok":true}', duration: Duration.zero));

      final client = CoffeeHttp.create(
        CoffeeHttpConfig(
          baseUrl: CoffeeUri(host: 'example.com', scheme: CoffeeHttpScheme.https),
          hooks: CoffeeHooks(handleResponse: (ctx) => <String, dynamic>{'status': ctx.response.statusCode}),
        ),
        adapter: adapter,
      );

      final map = await client.getHandled<Map<String, dynamic>>('/x');
      expect(map['status'], 200);
    });

    test('getHandled<T>() throws StateError when handleResponse is not configured', () async {
      final adapter = _FixedAdapter(CoffeeRawResponse(statusCode: 200, headers: const {}, body: 'ok', duration: Duration.zero));

      final client = CoffeeHttp.create(
        CoffeeHttpConfig(
          baseUrl: CoffeeUri(host: 'example.com', scheme: CoffeeHttpScheme.https),
        ),
        adapter: adapter,
      );

      expect(() => client.getHandled<Map<String, dynamic>>('/x'), throwsA(isA<StateError>()));
    });
  });
}

/// Always returns a fixed response.
class _FixedAdapter extends CoffeeTransportAdapter {
  final CoffeeRawResponse _response;

  _FixedAdapter(this._response);

  @override
  Future<CoffeeRawResponse> send(CoffeeRequest request, {required Map<String, String> headers}) async {
    return _response;
  }
}

/// Captures request + headers for assertions.
class _CapturingAdapter extends CoffeeTransportAdapter {
  CoffeeRequest? lastRequest;
  Map<String, String>? lastHeaders;

  final CoffeeRawResponse response;

  _CapturingAdapter({required this.response});

  @override
  Future<CoffeeRawResponse> send(CoffeeRequest request, {required Map<String, String> headers}) async {
    lastRequest = request;
    lastHeaders = Map<String, String>.from(headers);
    return response;
  }
}

/// Executes a function that throws.
class _ThrowingAdapter extends CoffeeTransportAdapter {
  final void Function() _thrower;

  _ThrowingAdapter(this._thrower);

  @override
  Future<CoffeeRawResponse> send(CoffeeRequest request, {required Map<String, String> headers}) async {
    _thrower();
    // unreachable
    return CoffeeRawResponse(statusCode: 500, headers: const {}, body: '', duration: Duration.zero);
  }
}
