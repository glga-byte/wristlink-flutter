## 1. Contract Assets

- [ ] 1.1 Define the initial v1 contract structure in the `contract/` submodule, including schemas, protocol notes, valid fixtures, invalid fixtures, and acknowledgement examples.
- [ ] 1.2 Pin the Flutter repo to the intended `contract/` submodule revision and document the adopted contract revision in the implementation notes.
- [ ] 1.3 Define the v1 serialized message budget as 1024 UTF-8 JSON bytes in the shared contract and add checks for representative v1 fixtures so oversized Garmin app-message payloads are caught early.

## 2. Dart Contract Models

- [ ] 2.1 Add payload domain models for point, timer, note, and command messages under `lib/features/payloads/`.
- [ ] 2.2 Add a versioned message envelope model with stable ULID id, kind, creation timestamp, optional TTL, and kind-specific payload serialization.
- [ ] 2.3 Add acknowledgement models that map accepted, rejected, unsupported, and retryable watch responses into domain outcomes for message kinds that require watch-level confirmation.
- [ ] 2.4 Add typed contract errors for malformed payloads, unsupported versions, unsupported kinds, payloads over the size budget, and invalid acknowledgement references.

## 3. Fixture Validation

- [ ] 3.1 Add Flutter tests that parse all valid contract fixtures into Dart models and serialize them back to contract-compatible maps.
- [ ] 3.2 Add Flutter tests that reject invalid contract fixtures with typed domain errors.
- [ ] 3.3 Add tests for unsupported protocol versions and unknown payload kinds.
- [ ] 3.4 Add tests that ensure optional fields and missing optional fields behave consistently with the contract.
- [ ] 3.5 Add tests that enforce ULID message id validation and the v1 serialized message size budget.

## 4. Send Queue and Bridge Boundaries

- [ ] 4.1 Add a typed Garmin send gateway interface under `lib/features/garmin_bridge/` that accepts validated contract messages and returns typed send outcomes.
- [ ] 4.2 Add send queue record models that persist contract-compatible message envelopes and explicit pending, sending, sent, and failed statuses.
- [ ] 4.3 Map watch acknowledgements to send queue status transitions only for message kinds whose contract metadata requires acknowledgement.
- [ ] 4.4 Keep native Android/iOS transport adapters limited to delivering normalized contract maps and mapping Garmin SDK transport errors to domain errors.

## 5. Project Knowledge and Verification

- [ ] 5.1 Update `AGENTS.md` with durable contract ownership, submodule, versioning, and verification rules introduced by this change.
- [ ] 5.2 Run `dart format .`.
- [ ] 5.3 Run `flutter analyze`.
- [ ] 5.4 Run `flutter test`.
- [ ] 5.5 If native Garmin send bridge code is added, run Android native unit tests and debug Android/iOS builds required by `AGENTS.md`.
