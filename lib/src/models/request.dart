enum CoffeeHttpMethod { get, post, put, patch, delete }

/// `CoffeeRequest`'s only goal is to **describe what is being requested**, nothing more.
/// Everything else happens around it.
///
/// It is a data structure and not a behavior carrier.
///
/// Design trade-offs
/// This design favors:
/// - explicitness over convenience
/// - stability over flexibility
/// - conventions over configuration flags.
///
/// As a result some repetition is expected and higher-level helpers are built on top; not inside. This is intentional.
///
final class CoffeeRequest {
  /// The HTTP method for the request.
  ///
  /// Required and Explicit
  ///
  /// No implicit defaults.
  final CoffeeHttpMethod method;

  /// The request path, relative to the configured baseUrl.
  ///
  /// Examples:
  /// - /users/me
  /// - /products
  /// - /cart/items
  ///
  /// Must start with '/'.
  /// Invalid paths are considered programmer errors and are not validated at runtime.
  /// Must not include scheme or host.
  /// Base URL and prefix are resolved by the client.
  final String path;

  /// A human-readable identifier for the request.
  ///
  /// Examples:
  /// - user.me
  /// - products.list
  /// - cart.add
  ///
  /// Used for logging, telemetry, debugging, hook context.
  ///
  /// This is **not** required, but apps that provide names gain observability for free.
  final String? name;

  /// A set of string-based markers that describe the intent of the request.
  ///
  /// Examples:
  /// - { "auth" }
  /// - { "auth", "device" }
  /// - { "public" }
  ///
  /// Tags are used to:
  /// - drive headersBuilder behavior.
  /// - opt into auth-related flows.
  /// - keep the API extensible without booleans.
  ///
  /// Why we use tags instead of booleans:
  /// - scales without API changes.
  /// - Avoids combinatorial flags.
  /// - Allow app-specific conventions.
  ///
  /// Tags are treated as immutable.
  /// Mutating the set after construction is undefined behavior.
  ///
  /// `coffee_http` does not interpret tag meaning beyond documented conventions.
  final Set<String> tags;

  /// Query parameters for the request.
  ///
  /// - Explicitly string-based.
  /// - Callers are responsible for encoding values
  /// - No magic serialization.
  ///
  /// What you put in gets through to the API.
  final Map<String, String> query;

  /// Request level headers.
  ///
  /// - Merged last,
  /// - Always override headers from config or builders.
  /// - Allows conscious, local overrides
  ///
  /// Merge order:
  /// 1) Config `defaultHeaders`
  /// 2) `headersBuilder` output.
  /// 3) `request.headers`.
  final Map<String, String> headers;

  /// Optional JSON body for write requests.
  ///
  /// These can be Map, List or any JSON-encodable object.
  /// - Encoded using jsonEncode.
  /// - Only sent for applicable HTTP methods.
  ///
  /// `coffee_http` does not validate the body structure.
  final Object? jsonBody;

  const CoffeeRequest({
    required this.method,
    required this.path,
    this.name,
    this.tags = const {},
    this.query = const {},
    this.headers = const {},
    this.jsonBody,
  });

  /// Convenience constructor for GET requests.
  const CoffeeRequest.get({
    required String path,
    String? name,
    Set<String> tags = const {},
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
  }) : this(
          method: CoffeeHttpMethod.get,
          path: path,
          name: name,
          tags: tags,
          query: query,
          headers: headers,
        );

  /// Convenience constructor for POST requests.
  const CoffeeRequest.post({
    required String path,
    String? name,
    Set<String> tags = const {},
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Object? jsonBody,
  }) : this(
          method: CoffeeHttpMethod.post,
          path: path,
          name: name,
          tags: tags,
          query: query,
          headers: headers,
          jsonBody: jsonBody,
        );

  /// Convenience constructor for PUT requests.
  const CoffeeRequest.put({
    required String path,
    String? name,
    Set<String> tags = const {},
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Object? jsonBody,
  }) : this(
          method: CoffeeHttpMethod.put,
          path: path,
          name: name,
          tags: tags,
          query: query,
          headers: headers,
          jsonBody: jsonBody,
        );

  /// Convenience constructor for PATCH requests.
  const CoffeeRequest.patch({
    required String path,
    String? name,
    Set<String> tags = const {},
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Object? jsonBody,
  }) : this(
          method: CoffeeHttpMethod.patch,
          path: path,
          name: name,
          tags: tags,
          query: query,
          headers: headers,
          jsonBody: jsonBody,
        );

  /// Convenience constructor for DELETE requests.
  const CoffeeRequest.delete({
    required String path,
    String? name,
    Set<String> tags = const {},
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Object? jsonBody,
  }) : this(
          method: CoffeeHttpMethod.delete,
          path: path,
          name: name,
          tags: tags,
          query: query,
          headers: headers,
          jsonBody: jsonBody,
        );
}
