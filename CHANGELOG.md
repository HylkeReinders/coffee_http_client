## 0.0.1

Initial release.

- Introduces a minimal, opinionated HTTP client for Flutter and Dart
- Explicit request lifecycle with predictable behavior
- Clear separation between transport and response semantics
- Raw HTTP responses via `CoffeeRawResponse`
- Application-defined response handling via `handleResponse`
- Lifecycle hooks: `onResponse`, `onError`
- Stable configuration model with explicit header merging
- Example app and public API tests included

## 0.0.2

Updated README and added a ROADMAP.md

## 0.0.3

Removed Typedefs.

## 0.0.4

Added a postHandled<T>()

## 0.1.0

- Improved error classification with `unknown` fallback
- Added `CoffeeMockAdapter` for deterministic, no-network tests
- Added `CoffeeRequest` convenience constructors
- Documented timeout mapping and handled POST requests
