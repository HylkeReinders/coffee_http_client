import 'dart:async';

import '../models/request.dart';
import '../models/response.dart';
import 'adapter.dart';

/// Mock transport adapter for tests and offline development.
///
/// This adapter never touches the network. Instead, it dispatches
/// requests to registered handlers.
class CoffeeMockAdapter extends CoffeeTransportAdapter {
  final Map<_MockKey, CoffeeMockHandler> _handlers = {};
  CoffeeMockHandler? _fallback;

  /// Captured calls in the order they were received.
  final List<CoffeeMockCall> calls = [];

  CoffeeMockAdapter({CoffeeMockHandler? fallback}) : _fallback = fallback;

  /// Registers a handler for a specific method + path.
  void when(CoffeeHttpMethod method, String path, CoffeeMockHandler handler) {
    _handlers[_MockKey(method, path)] = handler;
  }

  /// Registers a GET handler.
  void whenGet(String path, CoffeeMockHandler handler) => when(CoffeeHttpMethod.get, path, handler);

  /// Registers a POST handler.
  void whenPost(String path, CoffeeMockHandler handler) => when(CoffeeHttpMethod.post, path, handler);

  /// Registers a PUT handler.
  void whenPut(String path, CoffeeMockHandler handler) => when(CoffeeHttpMethod.put, path, handler);

  /// Registers a PATCH handler.
  void whenPatch(String path, CoffeeMockHandler handler) => when(CoffeeHttpMethod.patch, path, handler);

  /// Registers a DELETE handler.
  void whenDelete(String path, CoffeeMockHandler handler) => when(CoffeeHttpMethod.delete, path, handler);

  /// Sets a fallback handler used when no specific handler matches.
  void setFallback(CoffeeMockHandler handler) {
    _fallback = handler;
  }

  /// Clears handlers and captured calls.
  void reset() {
    _handlers.clear();
    _fallback = null;
    calls.clear();
  }

  @override
  Future<CoffeeRawResponse> send(
    CoffeeRequest request, {
    required Map<String, String> headers,
  }) async {
    final copiedHeaders = Map<String, String>.from(headers);
    calls.add(CoffeeMockCall(request: request, headers: copiedHeaders));

    final handler = _handlers[_MockKey(request.method, request.path)] ?? _fallback;
    if (handler == null) {
      throw StateError(
        'No mock handler registered for ${request.method.name.toUpperCase()} ${request.path}.',
      );
    }

    return await handler(request, copiedHeaders);
  }
}

/// A captured call to the mock adapter.
class CoffeeMockCall {
  final CoffeeRequest request;
  final Map<String, String> headers;

  CoffeeMockCall({required this.request, required this.headers});
}

/// Handler signature for [CoffeeMockAdapter].
typedef CoffeeMockHandler = FutureOr<CoffeeRawResponse> Function(
  CoffeeRequest request,
  Map<String, String> headers,
);

final class _MockKey {
  final CoffeeHttpMethod method;
  final String path;

  const _MockKey(this.method, this.path);

  @override
  bool operator ==(Object other) =>
      other is _MockKey && other.method == method && other.path == path;

  @override
  int get hashCode => Object.hash(method, path);
}
