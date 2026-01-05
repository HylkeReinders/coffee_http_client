import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_http_client/coffee_http_client.dart';

void main() {
  group('CoffeeUri', () {
    test('build() normalizes empty prefix and empty path to "/"', () {
      final uri = CoffeeUri(
        host: 'example.com',
        scheme: CoffeeHttpScheme.https,
        prefix: '',
      );

      final built = uri.build('');
      expect(built.toString(), 'https://example.com/');
    });

    test('build() normalizes prefix without leading slash', () {
      final uri = CoffeeUri(
        host: 'example.com',
        scheme: CoffeeHttpScheme.https,
        prefix: 'api/v1',
      );

      final built = uri.build('/users/me');
      expect(built.toString(), 'https://example.com/api/v1/users/me');
    });

    test('build() trims trailing slash from prefix', () {
      final uri = CoffeeUri(
        host: 'example.com',
        scheme: CoffeeHttpScheme.https,
        prefix: '/api/v1/',
      );

      final built = uri.build('/users');
      expect(built.toString(), 'https://example.com/api/v1/users');
    });

    test('build() normalizes path without leading slash', () {
      final uri = CoffeeUri(
        host: 'example.com',
        scheme: CoffeeHttpScheme.https,
        prefix: '/api',
      );

      final built = uri.build('users');
      expect(built.toString(), 'https://example.com/api/users');
    });

    test('build() attaches query parameters', () {
      final uri = CoffeeUri(
        host: 'example.com',
        scheme: CoffeeHttpScheme.https,
        prefix: '/api',
      );

      final built = uri.build('/products', query: {'page': '2', 'limit': '20'});
      expect(
        built.toString(),
        'https://example.com/api/products?page=2&limit=20',
      );
    });
  });

  group('CoffeeRequest', () {
    test('defaults are empty collections and null jsonBody', () {
      final req = CoffeeRequest(
        method: CoffeeHttpMethod.get,
        path: '/users/me',
      );

      expect(req.name, isNull);
      expect(req.tags, isEmpty);
      expect(req.query, isEmpty);
      expect(req.headers, isEmpty);
      expect(req.jsonBody, isNull);
    });

    test('stores provided fields', () {
      final req = CoffeeRequest(
        method: CoffeeHttpMethod.post,
        path: '/cart/items',
        name: 'cart.add',
        tags: {'auth'},
        query: {'dry_run': 'true'},
        headers: {'X-Debug': '1'},
        jsonBody: {'sku': 'ABC', 'quantity': 2},
      );

      expect(req.method, CoffeeHttpMethod.post);
      expect(req.path, '/cart/items');
      expect(req.name, 'cart.add');
      expect(req.tags, contains('auth'));
      expect(req.query['dry_run'], 'true');
      expect(req.headers['X-Debug'], '1');
      expect(req.jsonBody, isA<Map>());
    });

    test('convenience constructors set method and fields', () {
      final getReq = CoffeeRequest.get(
        path: '/users',
        name: 'users.list',
        tags: {'public'},
        query: {'page': '1'},
        headers: {'X': '1'},
      );

      final postReq = CoffeeRequest.post(
        path: '/users',
        jsonBody: {'name': 'Ada'},
      );

      expect(getReq.method, CoffeeHttpMethod.get);
      expect(getReq.path, '/users');
      expect(getReq.name, 'users.list');
      expect(getReq.tags, contains('public'));
      expect(getReq.query['page'], '1');
      expect(getReq.headers['X'], '1');

      expect(postReq.method, CoffeeHttpMethod.post);
      expect(postReq.path, '/users');
      expect(postReq.jsonBody, isA<Map>());
    });
  });

  group('CoffeeRawResponse', () {
    test('copyWith overrides only specified fields', () {
      final original = CoffeeRawResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"ok":true}',
        duration: const Duration(milliseconds: 10),
      );

      final updated = original.copyWith(statusCode: 201, body: '{"ok":false}');

      expect(updated.statusCode, 201);
      expect(updated.body, '{"ok":false}');
      expect(updated.headers['content-type'], 'application/json');
      expect(updated.duration, const Duration(milliseconds: 10));
    });

    test('copyWith can update duration', () {
      final original = CoffeeRawResponse(
        statusCode: 200,
        headers: const {},
        body: '',
        duration: Duration.zero,
      );

      final updated = original.copyWith(duration: const Duration(seconds: 1));
      expect(updated.duration, const Duration(seconds: 1));
    });
  });

  group('CoffeeHooks', () {
    test('handleResponse returns value that can be cast by the caller', () {
      final hooks = CoffeeHooks(
        handleResponse: (ctx) {
          // Typical: decode JSON in real app
          return <String, dynamic>{'status': ctx.response.statusCode};
        },
      );

      final ctx = CoffeeHandleResponseContext(
        request: CoffeeRequest(method: CoffeeHttpMethod.get, path: '/x'),
        response: CoffeeRawResponse(
          statusCode: 200,
          headers: const {},
          body: '{"ok":true}',
          duration: const Duration(milliseconds: 5),
        ),
      );

      final value = hooks.handleResponse!(ctx);
      expect(value, isA<Map<String, dynamic>>());
      expect((value as Map<String, dynamic>)['status'], 200);
    });

    test('onResponse and onError are optional and callable', () {
      var sawResponse = false;
      var sawError = false;

      final hooks = CoffeeHooks(
        onResponse: (ctx) {
          sawResponse = true;
          expect(ctx.request.path, '/ok');
          expect(ctx.response.statusCode, 200);
        },
        onError: (ctx) {
          sawError = true;
          expect(ctx.request.path, '/fail');
          expect(ctx.error.kind, CoffeeHttpErrorKind.network);
        },
      );

      hooks.onResponse!(
        CoffeeResponseContext(
          request: CoffeeRequest(method: CoffeeHttpMethod.get, path: '/ok'),
          response: CoffeeRawResponse(
            statusCode: 200,
            headers: const {},
            body: '',
            duration: Duration.zero,
          ),
        ),
      );

      hooks.onError!(
        CoffeeErrorContext(
          request: CoffeeRequest(method: CoffeeHttpMethod.get, path: '/fail'),
          error: CoffeeHttpError(
            kind: CoffeeHttpErrorKind.network,
            underlying: Exception('boom'),
          ),
        ),
      );

      expect(sawResponse, isTrue);
      expect(sawError, isTrue);
    });
  });

  group('CoffeeHttpError', () {
    test('stores kind and underlying exception', () {
      final ex = Exception('network down');
      final err = CoffeeHttpError(
        kind: CoffeeHttpErrorKind.network,
        underlying: ex,
      );

      expect(err.kind, CoffeeHttpErrorKind.network);
      expect(err.underlying, ex);
    });

    test('supports timeout kind', () {
      final err = CoffeeHttpError(
        kind: CoffeeHttpErrorKind.timeout,
        underlying: TimeoutException('timed out'),
      );

      expect(err.kind, CoffeeHttpErrorKind.timeout);
      expect(err.underlying, isA<TimeoutException>());
    });
  });
}
