/// Raw HTTP response returned by `CoffeeHttp`.
///
/// `CoffeeRawResponse` represents the **lowest-level successful result**
/// of an HTTP request:
/// - a response was received
/// - status code, headers, and body are available
///
/// It intentionally does **not**:
/// - interpret HTTP status codes
/// - throw on 4xx / 5xx
/// - parse or decode the response body
/// - map data to domain models
///
/// Those responsibilities are explicitly delegated to:
/// - `handleResponse` hooks
/// - application-level logic
///
/// This separation ensures that transport concerns remain isolated
/// from business logic and API semantics.
class CoffeeRawResponse {
  /// HTTP status code returned by the server.
  ///
  /// Examples:
  /// - 200
  /// - 401
  /// - 404
  /// - 500
  ///
  /// The presence of a status code does **not** imply success.
  /// Interpretation of status codes is the responsibility of `handleResponse`.
  final int statusCode;

  /// Response headers returned by the server.
  ///
  /// Header keys and values are represented as strings exactly as provided
  /// by the underlying HTTP client.
  ///
  /// No normalization or interpretation is applied.
  final Map<String, String> headers;

  /// Raw response body as a string.
  ///
  /// This is the unmodified body returned by the server.
  /// It may represent:
  /// - JSON
  /// - plain text
  /// - an empty body
  ///
  /// `coffee_http` does not attempt to decode or validate this value.
  /// Body parsing and validation should be performed in `handleResponse`
  /// or application-level code.
  final String body;

  /// Total duration of the request.
  ///
  /// This duration is measured by `CoffeeHttp` and represents the
  /// end-to-end time of the request, including:
  /// - header building
  /// - network transport
  /// - retries (if applicable)
  ///
  /// The adapter itself does not measure time.
  final Duration duration;

  /// Creates a raw HTTP response container.
  ///
  /// Instances of this class are produced internally by `CoffeeHttp`
  /// and passed through hooks and handlers without mutation.
  CoffeeRawResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.duration,
  });

  /// Creates a copy of this response with selectively overridden fields.
  ///
  /// This is primarily used internally to attach timing information
  /// after the transport layer has completed.
  CoffeeRawResponse copyWith({
    int? statusCode,
    Map<String, String>? headers,
    String? body,
    Duration? duration,
  }) {
    return CoffeeRawResponse(
      statusCode: statusCode ?? this.statusCode,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      duration: duration ?? this.duration,
    );
  }
}
