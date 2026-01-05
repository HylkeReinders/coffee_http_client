import 'dart:async';

import 'package:http/http.dart' as http;

import '/src/adapters/adapter.dart';
import '/src/adapters/http_adapter.dart';
import '/src/models/request.dart';
import '/src/models/response.dart';
import 'models/config.dart';
import 'error.dart';
import 'models/hooks.dart';

/// Core HTTP client for `coffee_http`.
///
/// `CoffeeHttp` is a **thin, opinionated HTTP client** designed to:
/// - provide a stable request lifecycle
/// - separate transport from semantics
/// - centralize configuration and defaults
/// - allow application-defined response handling
///
/// It intentionally avoids:
/// - implicit retries
/// - hidden magic
/// - framework-style abstractions
/// - forced response models
///
/// The client exposes two usage styles:
/// 1) **Raw requests** (`get`, `post`, `request`)
/// 2) **Handled requests** (`getHandled<T>`, `postHandled<T>`)
///
/// Raw requests always return [CoffeeRawResponse].
/// Handled requests delegate semantics to the `handleResponse` hook.
///
/// This design keeps transport predictable and semantics explicit.
final class CoffeeHttp {
  const CoffeeHttp._(this._config, this._adapter);

  static CoffeeHttp? _instance;
  static bool _configured = false;

  /// Returns the globally configured [CoffeeHttp] instance.
  ///
  /// Throws a [StateError] if `configure()` has not been called.
  static CoffeeHttp get instance {
    if (_instance == null) {
      throw StateError(
        "CoffeeHttp is not configured. "
        "Call CoffeeHttp.configure() before using it.",
      );
    }

    return _instance!;
  }

  /// Configures the global [CoffeeHttp] instance.
  ///
  /// This method may only be called once.
  /// Calling it multiple times is considered a programmer error.
  ///
  /// Use this in application startup code.
  static void configure(CoffeeHttpConfig config) {
    if (_configured) {
      throw StateError("CoffeeHttp.configure() may only be called once.");
    }

    _instance = CoffeeHttp._(config, HttpPackageAdapter(config));

    _configured = true;
  }

  /// Creates an isolated [CoffeeHttp] instance.
  ///
  /// This does **not** affect the global singleton.
  /// Useful for:
  /// - testing
  /// - background isolates
  /// - multiple API clients
  static CoffeeHttp create(CoffeeHttpConfig config, {CoffeeTransportAdapter? adapter}) {
    return CoffeeHttp._(config, adapter ?? HttpPackageAdapter(config));
  }

  /// Executes a fully constructed [CoffeeRequest].
  ///
  /// This is the lowest-level public entry point.
  /// It performs the full request lifecycle:
  ///
  /// 1. Merge headers
  /// 2. Execute HTTP transport
  /// 3. Measure duration
  /// 4. Call `onResponse` hook
  /// 5. Return raw response
  ///
  /// Transport-level failures result in a thrown [CoffeeHttpError]
  /// and trigger the `onError` hook.
  Future<CoffeeRawResponse> request(CoffeeRequest request) async {
    final stopwatch = Stopwatch()..start();

    final headers = await _mergeHeaders(request);

    CoffeeRawResponse response;

    try {
      response = await _adapter.send(request, headers: headers);
    } catch (exception) {
      final error = _toCoffeeError(exception);
      _config.hooks.onError?.call(CoffeeErrorContext(request: request, error: error));
      throw error;
    }

    stopwatch.stop();
    final duration = stopwatch.elapsed;
    final timedResponse = response.copyWith(duration: duration);

    _config.hooks.onResponse?.call(CoffeeResponseContext(request: request, response: timedResponse));

    return timedResponse;
  }

  final CoffeeHttpConfig _config;
  final CoffeeTransportAdapter _adapter;

  /// Convenience GET request.
  ///
  /// Creates a [CoffeeRequest] and delegates to [request].
  Future<CoffeeRawResponse> get(
    String path, {
    String? name,
    Set<String> tags = const {},
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    return request(
      CoffeeRequest(
        method: CoffeeHttpMethod.get,
        path: path,
        name: name,
        tags: tags,
        query: query ?? const {},
        headers: headers ?? const {},
      ),
    );
  }

  /// Convenience POST request.
  ///
  /// Creates a [CoffeeRequest] and delegates to [request].
  Future<CoffeeRawResponse> post(
    String path, {
    String? name,
    Set<String> tags = const {},
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? jsonBody,
  }) async {
    return request(
      CoffeeRequest(
        method: CoffeeHttpMethod.post,
        path: path,
        name: name,
        tags: tags,
        query: query ?? const {},
        headers: headers ?? const {},
        jsonBody: jsonBody,
      ),
    );
  }

  /// Executes a GET request and applies the `handleResponse` hook.
  ///
  /// This method provides typed semantics while keeping transport behavior explicit.
  ///
  /// Throws a [StateError] if `handleResponse` is not configured.
  Future<T> getHandled<T>(
    String path, {
    String? name,
    Set<String> tags = const {},
    Map<String, String>? query,
    Map<String, String>? headers,
    int? forceStatusCode,
  }) async {
    final req = CoffeeRequest(
      method: CoffeeHttpMethod.get,
      path: path,
      name: name,
      tags: tags,
      query: query ?? const {},
      headers: headers ?? const {},
    );

    final raw = await request(req);

    final handler = _config.hooks.handleResponse;

    if (handler == null) {
      throw StateError('CoffeeHooks.handleResponse is not configured.');
    }

    final value = handler(CoffeeHandleResponseContext(request: req, response: raw, forceStatusCode: forceStatusCode));

    return value as T;
  }

  /// Executes a POST request and applies the `handleResponse` hook.
  ///
  /// This method provides typed semantics while keeping transport behavior explicit.
  ///
  /// Throws a [StateError] if `handleResponse` is not configured.
  Future<T> postHandled<T>(
    String path, {
    String? name,
    Set<String> tags = const {},
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? jsonBody,
    int? forceStatusCode,
  }) async {
    final req = CoffeeRequest(
      method: CoffeeHttpMethod.post,
      path: path,
      name: name,
      tags: tags,
      query: query ?? const {},
      headers: headers ?? const {},
      jsonBody: jsonBody,
    );

    final raw = await request(req);

    final handler = _config.hooks.handleResponse;
    if (handler == null) {
      throw StateError('CoffeeHooks.handleResponse is not configured.');
    }

    final value = handler(CoffeeHandleResponseContext(request: req, response: raw, forceStatusCode: forceStatusCode));

    return value as T;
  }

  /// Merges headers according to the defined precedence rules.
  ///
  /// Merge order (highest wins last):
  /// 1. [CoffeeHttpConfig.defaultHeaders]
  /// 2. [CoffeeHttpConfig.headersBuilder]
  /// 3. [CoffeeRequest.headers]
  Future<Map<String, String>> _mergeHeaders(CoffeeRequest request) async {
    // 1) defaults
    final merged = <String, String>{..._config.defaultHeaders};

    // 2) dynamic headers from app
    if (_config.headersBuilder != null) {
      final built = await _config.headersBuilder!(request);
      merged.addAll(built);
    }

    // 3) request overrides win last
    merged.addAll(request.headers);

    return merged;
  }

  CoffeeHttpError _toCoffeeError(Object exception) {
    if (exception is CoffeeHttpError) return exception;
    if (exception is TimeoutException) {
      return CoffeeHttpError(kind: CoffeeHttpErrorKind.timeout, underlying: exception);
    }
    if (exception is http.ClientException) {
      return CoffeeHttpError(kind: CoffeeHttpErrorKind.network, underlying: exception);
    }
    return CoffeeHttpError(kind: CoffeeHttpErrorKind.unknown, underlying: exception);
  }
}
