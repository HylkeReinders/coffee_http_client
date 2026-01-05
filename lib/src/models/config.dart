import 'dart:async';

import 'hooks.dart';
import 'request.dart';

/// Supported URL schemes for [CoffeeUri].
///
/// `coffee_http` intentionally supports only HTTP and HTTPS.
/// Anything else belongs outside this client.
enum CoffeeHttpScheme { http, https }

/// Global configuration for a [CoffeeHttp] client instance.
///
/// [CoffeeHttpConfig] defines the *shared* behavior for all requests made by a client:
/// - which base URL to use
/// - which headers always apply
/// - how timeouts are configured
/// - how per-request headers are built
/// - which hooks are enabled
///
/// It is designed to be created once at startup and treated as immutable afterwards.
///
/// Important: [CoffeeHttpConfig] contains *policies and defaults*, not application logic.
/// App logic should be provided via builders and hooks (e.g. token lookup in [headersBuilder]).
final class CoffeeHttpConfig {
  /// Base URL used for all requests (scheme + host + optional prefix).
  final CoffeeUri baseUrl;

  /// Headers that always apply to the request (unless overridden later.)
  final Map<String, String> defaultHeaders;

  /// Timeout configuration for requests.
  ///
  /// Default adapter mapping (`package:http`):
  /// - [CoffeeTimeouts.receiveTimeout] is applied as a total request timeout
  ///   via `Future.timeout(...)`.
  /// - [CoffeeTimeouts.connectTimeout] is currently reserved for future
  ///   adapters that can distinguish connection vs read phases.
  final CoffeeTimeouts timeouts;

  /// Builds additional headers for a single request.
  ///
  /// This is the primary integration point for app-specific concerns such as:
  /// - authentication (Bearer tokens, session tokens)
  /// - device identifiers
  /// - locale / language headers
  /// - custom API keys
  ///
  /// The builder is called once per request and may be async.
  /// Returned headers are merged into the final request headers.
  ///
  /// Header merge order (highest wins last):
  /// 1) [CoffeeHttpConfig.defaultHeaders]
  /// 2) [CoffeeHttpConfig.headersBuilder] output
  /// 3) [CoffeeRequest.headers]
  final FutureOr<Map<String, String>> Function(CoffeeRequest request)? headersBuilder;

  /// Hooks that allow observing or transforming the request lifecycle.
  ///
  /// In v0.0.1 we support:
  /// - `handleResponse`: app-defined standard response handling
  /// - `onResponse`: observe every received response
  /// - `onError`: observe transport/errors
  ///
  /// Hooks should remain predictable and should not hide behavior.
  final CoffeeHooks hooks;

  /// Creates a new immutable configuration object.
  ///
  /// This should typically be called once at app startup and passed into `CoffeeHttp.configure(...)`.
  CoffeeHttpConfig({
    required this.baseUrl,
    this.defaultHeaders = const {'Accept': 'application/json', 'Content-Type': 'application/json'},
    this.headersBuilder,
    this.timeouts = const CoffeeTimeouts(),
    this.hooks = const CoffeeHooks(),
  });
}

/// Represents the base address used to construct request URIs.
///
/// [CoffeeUri] is intentionally minimal:
/// - scheme (http/https)
/// - host (e.g. api.example.com)
/// - optional prefix (e.g. /api/v1)
///
/// `CoffeeUri` does not know anything about authentication, headers, retries, or parsing.
/// Its only job is to reliably build a `Uri` for a given request path and query map.
///
/// Example:
/// - host: api.example.com
/// - scheme: https
/// - prefix: /api/v1
/// - path: /users/me
///
/// => https://api.example.com/api/v1/users/me
final class CoffeeUri {
  /// Host name used for all requests.
  ///
  /// Examples:
  /// - "api.example.com"
  /// - "localhost:8080" (when using http)
  final String host;

  /// URL scheme used to build the final `Uri`.
  final CoffeeHttpScheme scheme;

  /// Optional path prefix applied before each request path.
  ///
  /// Common use cases:
  /// - versioning: `/api/v1`
  /// - tenant routing: `/api/{tenantId}`
  ///
  /// The prefix is normalized to:
  /// - always start with `/`
  /// - never end with `/` (unless it's the root "/")
  final String prefix;

  /// Creates a base URI descriptor.
  ///
  /// Prefer providing `prefix` for API routing rather than concatenating it into every request path.
  CoffeeUri({required this.host, required this.scheme, this.prefix = ''});

  /// Builds a concrete [Uri] for a request path.
  ///
  /// - [path] is normalized to always start with `/`.
  /// - [prefix] is normalized to always start with `/` and not end with `/`.
  /// - [query] is passed directly to `Uri.http/https`.
  ///
  /// This method does not validate whether [path] contains illegal characters.
  /// Invalid paths should be treated as programmer errors.
  Uri build(String path, {Map<String, String>? query}) {
    final normalizedPrefix = _normalizePrefix(prefix);
    final normalizedPath = _normalizePath(path);

    final fullPath = '$normalizedPrefix$normalizedPath';

    return switch (scheme) {
      CoffeeHttpScheme.http => Uri.http(host, fullPath, query),
      CoffeeHttpScheme.https => Uri.https(host, fullPath, query),
    };
  }

  /// Normalizes the prefix part of the URL.
  ///
  /// Guarantees:
  /// - returned value starts with `/` (when non-empty)
  /// - returned value does not end with `/` (unless it is "/")
  ///
  /// Examples:
  /// - ""        => ""
  /// - "api/v1"  => "/api/v1"
  /// - "/api/v1" => "/api/v1"
  /// - "/api/v1/"=> "/api/v1"
  String _normalizePrefix(String prefix) {
    if (prefix.isEmpty) return '';

    // Ensure that the string starts with a / and doesn't end with a /.
    final value = prefix.startsWith('/') ? prefix : '/$prefix';

    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  /// Normalizes the request path.
  ///
  /// Guarantees:
  /// - returned value starts with `/`
  ///
  /// Examples:
  /// - ""      => "/"
  /// - "users" => "/users"
  /// - "/me"   => "/me"
  String _normalizePath(String path) {
    if (path.isEmpty) return '/';

    return path.startsWith('/') ? path : '/$path';
  }
}

/// Timeout configuration for HTTP requests.
///
/// In v0.0.1 the default `package:http` adapter uses a single `.timeout(...)` call.
/// That means there is effectively one total timeout per request.
/// We use [receiveTimeout] as that total timeout.
///
/// [connectTimeout] is reserved for future adapters that can distinguish connection vs read phases.
final class CoffeeTimeouts {
  /// Intended maximum time to establish a connection.
  ///
  /// Note: not actively used by the v0.0.1 `package:http` adapter.
  final Duration connectTimeout;

  /// Maximum total time a request is allowed to take.
  ///
  /// In v0.0.1 this is used as the request-wide timeout via `Future.timeout(...)`.
  final Duration receiveTimeout;

  /// Creates a timeout configuration with sensible defaults.
  const CoffeeTimeouts({this.connectTimeout = const Duration(seconds: 10), this.receiveTimeout = const Duration(seconds: 20)});
}
