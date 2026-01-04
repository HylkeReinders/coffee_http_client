# Roadmap - coffee_http_client ☕️

This document describes the planned direction for `coffee_http_client`.

Goal: become a pragmatic, production-ready alternative to Dio for teams that want:

- explicit behavior
- predictable request lifecycles
- application-defined semantics
- minimal API surface
- composable features (no framework)

Non-goal: “become Dio” by copying every feature.
We only add features when they solve real production problems without introducing hidden magic.

## Design principles

- Transport ≠ Semantics
- Explicit > convenient
- No implicit retries
- No global interceptors that silently change behavior
- Small, composable primitives
- Stable public API (barrel exports are the contract)

## Current state (0.0.1)

- Client configuration (`CoffeeHttpConfig`, `CoffeeUri`, timeouts)
- Request model (`CoffeeRequest`, tags, query, headers, optional jsonBody)
- Raw responses (`CoffeeRawResponse`)
- Hooks:
  - `handleResponse`
  - `onResponse`
  - `onError`
- Adapter-based transport (currently `package:http`)

## v0.1.x — Foundation hardening

Focus: make the foundation rock-solid before adding “big” features.

- `postHandled<T>()` parity with `getHandled<T>()`
- Improve error classification (`unknown` fallback)
- Better timeout mapping and documentation
- Public API polish (naming consistency, docs, examples)
- Testing utilities:
  - official mock adapter (no network)
  - deterministic tests for lifecycle hooks
- Add small quality-of-life helpers (non-magical):
  - request builders / helpers that do not hide behavior

## v0.2.x — Request lifecycle features

Focus: features that teams need in real apps, but keep them explicit.

- Request cancellation support (where possible)
- Request-level timeout overrides
- Retry support as an explicit, opt-in policy
  - no automatic retries by default
  - retry decisions should be visible and testable
- Optional request/response redaction utilities for logging (PII-safe)

## v0.3.x — Multipart & file uploads

Focus: production-grade uploads without turning the client into a framework.

- Multipart/form-data support
  - file upload from bytes
  - file upload from path (platform permitting)
  - multiple files / mixed fields
- Upload progress reporting (explicit API, no global magic)
- Streaming uploads where the underlying transport supports it
- Clear separation:
  - request describes upload intent
  - adapter performs the upload

Notes:

- `package:http` has limitations for true streaming/progress on some platforms.
- If needed, we may introduce an optional alternative transport adapter while keeping the core API stable.

## v0.4.x — Downloads & streaming

- File downloads
- Optional progress reporting
- Streaming responses (bytes/stream)
- Large payload handling guidelines

## v0.5.x — Extensible adapters

Focus: allow multiple transports cleanly.

- `package:http` adapter remains the default
- Optional adapters (planned, not guaranteed):
  - `dart:io` adapter for advanced streaming
  - Web adapter (browser safe)
- Adapter capability matrix documented

## v0.6.x — Auth & token flows (explicit)

Goal: allow typical auth flows without baking in opinions.

- Hooks / utilities for:
  - token refresh workflows
  - “whenTokenExpired” pattern
- Explicit opt-in retry-after-refresh strategy
- No hidden auto-refresh by default

## v0.7.x — Telemetry & observability

Goal: integrate cleanly with analytics/logging without coupling.

- Request/response events
- Structured logging helpers
- Tracing hooks
- Tags-based sampling strategies

## v1.0.0 — Stable public contract

Criteria to hit 1.0:

- Core API surface stable
- Docs complete (usage, philosophy, non-goals)
- Test coverage high + deterministic
- Example app demonstrates real use cases
- Clear upgrade path for breaking changes in 0.x

## Non-goals (intentionally out of scope)

- Becoming a full networking framework
- Implicit global interceptors that mutate behavior invisibly
- Automatic retries by default
- Opinionated response models forced on users
- “Do everything” feature creep

## Feedback & direction

This is OSS. If you want something added:

- describe the real production problem
- include constraints (platforms, payload size, expected behavior)
- propose an explicit API shape

If it fits the principles above, it’s a good candidate.
