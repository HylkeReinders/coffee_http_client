/// High-level error type used by `coffee_http`.
///
/// `CoffeeHttpError` represents failures that occur **around the HTTP transport**,
/// not application-level or domain-specific errors.
///
/// It is intentionally minimal and opinionated:
/// - it does not attempt to classify HTTP status codes
/// - it does not parse response bodies
/// - it does not map errors to domain models
///
/// Those concerns belong to:
/// - `handleResponse` (for HTTP semantics)
/// - application code (for domain errors)
///
/// `CoffeeHttpError` is thrown when the request lifecycle fails
/// *before* a valid HTTP response can be produced or handled.
enum CoffeeHttpErrorKind {
  /// A low-level network failure.
  ///
  /// Examples:
  /// - socket exceptions
  /// - DNS lookup failures
  /// - connection resets
  /// - unreachable hosts
  ///
  /// This typically indicates that the request never reached the server
  /// or that the connection was interrupted.
  network,

  /// A request timeout.
  ///
  /// Thrown when the request exceeds the configured timeout duration.
  /// In v0.0.1 this corresponds to the total request timeout
  /// (see `CoffeeTimeouts.receiveTimeout`).
  timeout,

  /// An unknown or unexpected error.
  ///
  /// Used as a fallback when an error does not clearly fit into
  /// another category.
  ///
  /// This often indicates:
  /// - programmer errors
  /// - unexpected exceptions from third-party libraries
  /// - logic errors outside the transport layer
  unknown,
}

/// Exception thrown by `CoffeeHttp` when a request fails
/// before producing a usable response.
///
/// `CoffeeHttpError` is **not** an HTTP error:
/// - it does not represent 4xx or 5xx responses
/// - it does not imply anything about API-level failures
///
/// Those cases are handled via:
/// - raw responses (`CoffeeRawResponse`)
/// - `handleResponse` hooks
///
/// This exception exists to:
/// - provide a stable, typed failure surface
/// - allow apps to react consistently to transport-level problems
/// - support observability via `onError` hooks
class CoffeeHttpError implements Exception {
  /// High-level classification of the failure.
  ///
  /// This allows applications to react differently to:
  /// - network issues
  /// - timeouts
  /// - unexpected failures
  final CoffeeHttpErrorKind kind;

  /// The original exception or error that caused this failure.
  ///
  /// This value is preserved for:
  /// - logging
  /// - debugging
  /// - crash reporting
  ///
  /// It should not be relied upon for control flow.
  final Object underlying;

  /// Creates a new transport-level HTTP error.
  ///
  /// Instances of this class are typically created internally by `CoffeeHttp`
  /// and surfaced to the application via thrown exceptions and `onError` hooks.
  CoffeeHttpError({required this.kind, required this.underlying});
}
