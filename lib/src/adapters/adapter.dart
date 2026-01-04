import '../models/request.dart';
import '../models/response.dart';

/// Abstraction over the underlying HTTP transport implementation.
///
/// `CoffeeTransportAdapter` defines the **lowest-level boundary**
/// between `coffee_http` and any concrete HTTP client
/// (e.g. `package:http`, `dart:io`, or a mock adapter in tests).
///
/// The adapter is intentionally minimal and opinion-free.
/// Its sole responsibility is:
/// - execute an HTTP request
/// - return the raw response
///
/// The adapter must **not**:
/// - interpret HTTP status codes
/// - throw based on 4xx / 5xx responses
/// - decode or parse response bodies
/// - implement retries or authentication logic
/// - call hooks or log
///
/// All higher-level behavior belongs to `CoffeeHttp` and hooks.
abstract class CoffeeTransportAdapter {
  /// Executes the given [request] using the provided HTTP [headers].
  ///
  /// The adapter receives fully merged headers.
  /// It must not modify or rebuild them.
  ///
  /// Implementations should:
  /// - translate [CoffeeRequest] into a concrete HTTP call
  /// - perform network I/O
  /// - surface transport-level failures via thrown exceptions
  ///
  /// The returned [CoffeeRawResponse] must contain:
  /// - status code
  /// - response headers
  /// - raw response body
  ///
  /// Timing information is handled by `CoffeeHttp`, not by the adapter.
  Future<CoffeeRawResponse> send(
    CoffeeRequest request, {
    required Map<String, String> headers,
  });
}
