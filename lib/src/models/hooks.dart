import '../error.dart';
import 'request.dart';
import 'response.dart';

/// Collection of optional hooks that observe or transform
/// the `coffee_http` request lifecycle.
///
/// Hooks are intentionally:
/// - explicit
/// - opt-in
/// - predictable
///
/// The lifecycle order in v0.0.1 is:
/// 1. Request is constructed
/// 2. Headers are merged
/// 3. HTTP transport is executed
/// 4. Duration is measured
/// 5. `onResponse` is called (if a response exists)
/// 6. `handleResponse` is invoked via `getHandled<T>()` or `postHandled<T>()`
///
/// In case of failure:
/// - `onError` is called
/// - a `CoffeeHttpError` is thrown
final class CoffeeHooks {
  /// Standard response handler used by `getHandled<T>()` and `postHandled<T>()`.
  ///
  /// If not provided, calling `getHandled<T>()` will throw.
  ///
  /// Transforms a raw HTTP response into an application-level value.
  ///
  /// `handleResponse` is the primary integration point for defining
  /// a *standard response contract* across an application.
  ///
  /// This function is responsible for:
  /// - interpreting HTTP status codes
  /// - decoding the response body (e.g. JSON)
  /// - throwing application-level errors when appropriate
  ///
  /// It is intentionally opinionated and **application-defined**.
  /// `coffee_http` does not impose any behavior here.
  ///
  /// The return value is typed at the call site via `getHandled<T>()`.
  final Object? Function(CoffeeHandleResponseContext ctx)? handleResponse;

  /// Observes a completed HTTP request.
  ///
  /// This hook is not called for transport-level failures.
  ///
  /// `onResponse` is called exactly once for every request
  /// that successfully produces a response, regardless of status code.
  ///
  /// Typical use cases:
  /// - logging
  /// - metrics / timing
  /// - debugging
  /// - tracing
  ///
  /// This hook must not:
  /// - throw for control flow
  /// - mutate the response
  /// - implement retries or parsing
  final void Function(CoffeeResponseContext ctx)? onResponse;

  /// Observes a request failure.
  ///
  /// `onError` is called when the request lifecycle fails
  /// before a valid HTTP response can be produced.
  ///
  /// Typical use cases:
  /// - error logging
  /// - crash reporting
  /// - telemetry
  ///
  /// This hook must not:
  /// - swallow errors
  /// - perform hidden retries
  /// - mutate request state
  final void Function(CoffeeErrorContext ctx)? onError;

  /// Observes request cancellation.
  ///
  /// `onCancel` is called when a request is explicitly cancelled via
  /// a [CoffeeCancellationToken].
  ///
  /// Cancellation represents **loss of interest**, not a transport failure.
  /// The underlying HTTP request may or may not have completed.
  ///
  /// Important semantics:
  /// - `onCancel` is **not** an error hook.
  /// - `onError` is **not** called for cancellations.
  /// - `onResponse` is **not** called for cancelled requests.
  ///
  /// A cancelled request always throws a [CoffeeRequestCancelled] exception.
  /// This exception is surfaced to the caller and may be caught explicitly.
  ///
  /// The provided [CoffeeCancelContext] includes:
  /// - the original request
  /// - the cancellation exception (with optional reason)
  /// - the lifecycle phase at which cancellation occurred
  ///
  /// Typical use cases:
  /// - telemetry (cancellation rates, user-aborted flows)
  /// - debugging and tracing
  /// - analytics (screen changes, navigation interrupts)
  ///
  /// This hook must not:
  /// - swallow the cancellation exception
  /// - retry the request implicitly
  /// - treat cancellation as a network or application error
  ///
  /// Cancellation is intentional and explicit.
  /// It should be observed, not corrected.
  final void Function(CoffeeCancelContext ctx)? onCancel;

  /// Creates a hooks container.
  ///
  /// All hooks are optional and opt-in.
  const CoffeeHooks({this.handleResponse, this.onResponse, this.onError, this.onCancel});
}

/// Context provided to [CoffeeHandleResponse].
///
/// This context contains all information necessary to interpret
/// the HTTP response in an application-specific way.
final class CoffeeHandleResponseContext {
  /// The original request that was executed.
  final CoffeeRequest request;

  /// The raw HTTP response produced by the transport layer.
  final CoffeeRawResponse response;

  /// Optional status code override used by the caller.
  ///
  /// This allows endpoints that return non-standard success codes
  /// (e.g. 201, 204) to be handled explicitly.
  final int? forceStatusCode;

  /// Creates a response-handling context.
  const CoffeeHandleResponseContext({required this.request, required this.response, this.forceStatusCode});
}

/// Context provided to [CoffeeOnResponse].
///
/// This context is intended for observation only.
final class CoffeeResponseContext {
  /// The original request that was executed.
  final CoffeeRequest request;

  /// The completed raw HTTP response.
  final CoffeeRawResponse response;

  /// Creates a response observation context.
  const CoffeeResponseContext({required this.request, required this.response});
}

/// Context provided to [CoffeeOnError].
///
/// This context represents a transport-level failure.
final class CoffeeErrorContext {
  /// The request that failed.
  final CoffeeRequest request;

  /// The transport-level error that occurred.
  final CoffeeHttpError error;

  /// Creates an error observation context.
  const CoffeeErrorContext({required this.request, required this.error});
}

/// Context provided to [onCancel].
///
/// This context represents a cancel failure.
final class CoffeeCancelContext {
  /// The request that got cancelled.
  final CoffeeRequest request;

  /// The cancel exception that got thrown.
  final CoffeeRequestCancelled error;

  /// Optional: how far the request got (before send / after send).
  final CoffeeCancelPhase phase;

  /// Creates an cancel observation context.
  const CoffeeCancelContext({required this.request, required this.error, required this.phase});
}

enum CoffeeCancelPhase {
  /// Cancelled before the transport adapter was invoked.
  beforeSend,

  /// Cancelled after a response was received but before processing hooks/handlers.
  afterSend,

  /// Cancelled while waiting (rare, but possible with adapter support).
  inFlight,
}
