# coffee_http_client ☕️

A minimal, opinionated HTTP client for Flutter and Dart.

`coffee_http_client` is designed for developers who want explicit request lifecycles, predictable behavior, and application-defined semantics — without framework magic or over-engineered abstractions.

This package focuses on being:

- boring
- explicit
- stable
- production-oriented

If you like hidden retries, global interceptors, and implicit behavior: this is not for you.

## Why `coffee_http_client`?

Flutter gives you complete freedom — which often results in:

- every project having a different HTTP setup
- ad-hoc response parsing
- scattered error handling
- duplicated glue code

coffee_http_client provides a stable foundation, not a framework.

It gives you:

- a clear request lifecycle
- explicit extension points
- a strict separation between transport and semantics
- predictable defaults that do not fight your architecture

You decide what a “successful response” means.
You decide how errors are handled.
You decide where parsing happens.

## Core principles

- Transport ≠ semantics
- Explicit over convenient
- No hidden magic
- Configuration over inheritance
- Application-defined behavior

## What this package does

- Executes HTTP requests
- Merges headers in a predictable way
- Measures request duration
- Exposes lifecycle hooks
- Returns raw responses

## What this package does NOT do

- No automatic retries
- No implicit JSON parsing
- No opinionated error mapping
- No global interceptors
- No state management
- No magic defaults

## Installation

```yaml
dependencies:
  coffee_http_client: ^0.0.1
```

## Basic Usage

```dart
CoffeeHttp.configure(
  CoffeeHttpConfig(
    baseUrl: CoffeeUri(
      host: 'api.example.com',
      scheme: CoffeeHttpScheme.https,
      prefix: '/api/v1',
    ),
  ),
);
```

This configuration is global and must be done once during app startup.

## Simple GET request (raw)

````dart
final response = await CoffeeHttp.instance.get(
  '/users/me',
);

print(response.statusCode);
print(response.body);
print(response.duration);```
````

This returns a CoffeeRawResponse and does no interpretation.

## Requests

Requests are represented by `CoffeeRequest`.

They describe what is being requested, not how it is handled.

```dart
final request = CoffeeRequest(
  method: CoffeeHttpMethod.post,
  path: '/cart/items',
  name: 'cart.add',
  tags: {'auth'},
  jsonBody: {
    'sku': 'ABC',
    'quantity': 2,
  },
);
```

### Why tags?

Tags are used instead of boolean flags.

They:

- scale without API changes
- avoid combinatorial options
- allow app-specific conventions

Example usage:

- auth
- device
- public
- retryable

The library does not interpret tags, your app does.

## Header merging

Headers are merged in a strict order:

1. `CoffeeHttpConfig.defaultHeaders`
2. `CoffeeHttpConfig.headersBuilder`
3. `CoffeeRequest.headers` (wins)

```dart
CoffeeHttpConfig(
  headersBuilder: (request) {
    if (request.tags.contains('auth')) {
      return {
        'Authorization': 'Bearer token',
      };
    }
    return {};
  },
);
```

## Hooks

Hooks allow you to observe and control the request lifecycle.

**Available hooks**

- `handleResponse`
- `onResponse`
- `onError`

All hooks are optional and opt-in.

### handleResponse

Defines how your application interprets responses.

Used by `getHandled<T>()`.

```dart
CoffeeHooks(
  handleResponse: (ctx) {
    final res = ctx.response;

    final isSuccess = ctx.forceStatusCode != null
        ? res.statusCode == ctx.forceStatusCode
        : res.statusCode >= 200 && res.statusCode < 300;

    if (!isSuccess) {
      throw Exception('Request failed: ${res.statusCode}');
    }

    if (res.body.isEmpty) return null;

    return jsonDecode(res.body);
  },
);
```

Usage:

```dart
final user = await CoffeeHttp.instance.getHandled<Map<String, dynamic>>(
  '/users/me',
  name: 'user.me',
  tags: {'auth'},
);
```

### onResponse

Called for every request that successfully produces a response.

```dart
CoffeeHooks(
  onResponse: (ctx) {
    debugPrint(
      '[HTTP] ${ctx.request.method.name} '
      '${ctx.request.path} → ${ctx.response.statusCode} '
      '(${ctx.response.duration.inMilliseconds}ms)',
    );
  },
);
```

Use cases:

- logging
- metrics
- debugging
- tracing

### onError

Called when a request fails before a response is produced.

```dart
CoffeeHooks(
  onError: (ctx) {
    debugPrint(
      '[HTTP ERROR] ${ctx.request.path} → ${ctx.error.kind}',
    );
  },
);
```

Use cases:

- crash reporting
- telemetry
- retries (explicitly)

## Errors

Transport-level failures are surfaced as CoffeeHttpError.

```dart
try {
  await CoffeeHttp.instance.get('/users/me');
} on CoffeeHttpError catch (e) {
  if (e.kind == CoffeeHttpErrorKind.timeout) {
    // handle timeout
  }
}
```

Supported kinds:

- network
- timeout
- unknown

## Raw vs handled responses

### Raw

- get, post, request
- return CoffeeRawResponse
- no semantics

### Handled

- getHandled<T>
- delegates to handleResponse
- application-defined meaning

This separation is intentional.

## Architecture position

`coffee_http_client` is infrastructure, not domain logic.

It belongs:

- below repositories
- below services
- above the transport layer

It is safe to use across:

- features
- modules
- layers

### Breaking changes will be explicit and documented.

## Non-goals

- Becoming a framework
- Competing with Dio
- Hiding HTTP complexity
- Enforcing architecture

## Philosophy

Production code should be:

- readable a year later
- boring in the best way
- explicit in intent
- easy to reason about

If something feels missing, it is probably intentional.

## Roadmap
`coffee_http_client` is intentionally small today, but designed to grow in a controlled and pragmatic way.

The long-term goal is to become a production-ready alternative to Dio, focused on what teams need, not feature parity for its own sake.

Planned areas of expansion include:
- request lifecycle improvements
- explicit retry and cancellation strategies
- multipart & file uploads
- streaming downloads
- extensible transport adapters
- observability and telemetry hooks

All new features must:
- respect the existing request lifecycle
- remain explicit and opt-in
- avoid hidden magic or implicit behavior

The full roadmap, including non-goals and version planning, lives in ROADMAP.md￼.


## License

MIT
