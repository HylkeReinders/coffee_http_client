import 'dart:async';

import '../error.dart';

class CoffeeCancellationToken {
  bool _isCancelled = false;

  Object? _reason;

  final Completer<void> _completer = Completer<void>();

  /// Wheter this token has been cancelled.
  bool get isCancelled => _isCancelled;

  /// Optional cancellation reason, useful for debugging and telemetry.
  Object? get reason => _reason;

  /// A Future that gets completed once the token is cancelled.
  ///
  /// Useful for adapters, retry policies, and tests.
  Future<void> get whenCancelled => _completer.future;

  /// Cancels the token.
  ///
  /// This method is idempodent: Calling it multiple times doesn't matter.
  void cancel([Object? reason]) {
    if (_isCancelled) return;

    _isCancelled = true;
    _reason = reason;

    _completer.complete();
  }

  /// Throws [CoffeeRequestCancelled] if the request is cancelled.
  ///
  /// Convenience helper for internal use.
  void throwIfCancelled() {
    if (!_isCancelled) return;

    throw CoffeeRequestCancelled(_reason);
  }
}
