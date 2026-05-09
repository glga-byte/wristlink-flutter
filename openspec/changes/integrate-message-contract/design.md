## Context

The Flutter repo already has shared device models, Garmin discovery bridges, and explicit platform storage boundaries. It does not yet define the phone-to-watch message protocol that will be consumed by the separate Connect IQ app repo. The newly added `contract/` submodule is the right boundary for shared protocol assets because both repositories can reference the same schemas, fixtures, examples, and version notes without copying implementation code across project lines.

The Garmin Connect IQ transport accepts generic app-message data, but the exact serialized shape still needs to be compact, stable, and easy to parse on the watch. Flutter should therefore model WristLink messages explicitly in Dart, serialize them to the contract-defined shape, and let native Android/iOS bridge code only deliver already-normalized payload maps to Garmin SDK APIs.

Garmin's official Connect IQ API docs do not publish a numeric maximum size for app messages. They document the transmittable data types and expose too-large failures such as `BLE_REQUEST_TOO_LARGE`, so WristLink will define and test its own contract-level payload budget instead of depending on an undocumented platform limit.

## Goals / Non-Goals

**Goals:**

- Establish `contract/` as the read-only source of truth for WristLink message envelopes, payload kinds, acknowledgements, versioning, and fixtures.
- Add Flutter-side domain models and serializers that map point, timer, note, and command sends into the shared contract shape.
- Keep send queue storage durable by persisting contract-compatible message records rather than screen-local UI state.
- Add tests that validate Dart serialization against contract fixtures and reject unsupported or malformed contract payloads.
- Define a typed Garmin send bridge boundary that accepts domain send requests and returns domain send outcomes.

**Non-Goals:**

- Implement Connect IQ watch app code in this repository.
- Generate Monkey C code from Flutter.
- Build the complete send queue, background WorkManager service, or native Garmin send implementation unless a later implementation task explicitly scopes them in.
- Add emulator-device behavior or developer-tool overrides.

## Decisions

### Use the contract submodule as the normative artifact

The `contract/` submodule will contain versioned schemas, valid fixtures, invalid fixtures, and protocol notes. Flutter implementation will consume those files in tests and keep generated or handwritten Dart code aligned with them.

Alternatives considered:

- Docs-only contract: fast, but too easy for Flutter and Connect IQ to drift.
- Dart package as contract: useful for Flutter, but it does not directly serve Monkey C.
- Protobuf or binary schema: strong typing, but increases watch-side complexity before payload limits prove it necessary.

### Use a compact versioned envelope

Phone-to-watch messages should serialize into a compact envelope with a protocol version, message id, kind, creation time, optional TTL, and kind-specific payload. Watch-to-phone responses should reference the original id and include a status code that the send queue can map to sent, failed, or retryable states.

Message ids will use ULID strings. ULIDs are shorter than UUID strings, lexicographically sortable for queue/debug views, safe to store as plain text, and do not require the watch to parse anything more complex than an opaque string.

Example conceptual shape:

```json
{
  "v": 1,
  "id": "01HX...",
  "kind": "point",
  "createdAt": "2026-05-09T12:00:00Z",
  "ttlSec": 86400,
  "payload": {}
}
```

### Keep native bridge code transport-oriented

Dart owns message construction, validation, queue state, and domain errors. Android/iOS bridge code receives normalized maps, sends them through the Garmin SDK, and maps SDK errors back into typed Dart errors. Native code must not invent payload fields or apply business rules beyond platform transport requirements.

### Require acknowledgements only when transport success is insufficient

Garmin SDK send success is treated as transport-level success, not proof that the Connect IQ app parsed and applied the command. The contract will support watch acknowledgements for all message kinds, but each send kind can declare whether an acknowledgement is required. When acknowledgement is required, the queue only reaches `sent` after a matching watch acknowledgement; otherwise SDK transport success is sufficient.

### Validate with fixtures before integration behavior

The first implementation step should add contract fixture tests for serialization and parsing before building UI flows or background sending. This creates a stable compatibility guard for both the Flutter repo and the Connect IQ repo.

### Enforce a WristLink v1 payload budget

Because Garmin does not define a public numeric maximum, WristLink v1 will set its own serialized message budget in the shared contract. The initial budget should be 1024 UTF-8 JSON bytes per phone-to-watch envelope, with fixture tests covering every valid payload kind. This is intentionally conservative for short WristLink data and can be revised by a later contract version if measured target-device behavior supports a larger budget.

## Risks / Trade-offs

- Contract submodule drifts from expected branch or commit -> Pin the submodule pointer in Flutter changes and include contract update notes in PR descriptions.
- JSON-like payloads exceed Garmin transport limits -> Keep fixtures compact, add serialized-size checks, and reserve a later binary format migration if size becomes a measured issue.
- Watch-side parser rejects optional fields differently than Flutter -> Put optional and missing-field examples in fixtures and require both repos to test against them.
- Versioning becomes too vague -> Require every message to include a protocol version and require unknown major versions to fail with a typed unsupported-version outcome.
- Native bridge starts owning business rules -> Keep send bridge APIs typed and require tests around Dart serialization before native transport tests.

## Migration Plan

1. Add contract fixtures and schemas in the `contract/` submodule.
2. Add Flutter tests that read those fixtures and define expected Dart model behavior.
3. Implement Dart payload models, envelope serialization, acknowledgement parsing, and domain errors.
4. Introduce a typed Garmin send gateway over platform channels.
5. Implement Android/iOS transport adapters after the Dart contract boundary is stable.
6. Keep the existing app behavior unchanged until send flows are explicitly wired to the new gateway.

Rollback is straightforward before send flows launch: revert the Flutter change and leave the contract submodule revision unchanged. After send flows launch, rollback requires keeping protocol v1 parsing available until queued messages using v1 are drained or migrated.

## Resolved Questions

- Garmin does not publish an official numeric app-message size limit; WristLink v1 will enforce a contract-defined 1024-byte serialized JSON budget and map Garmin too-large failures to typed domain errors.
- Acknowledgements are required only for message kinds where SDK transport success is insufficient to prove the watch parsed and applied the command.
- Message ids use ULID strings.
