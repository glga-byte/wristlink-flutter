## Why

Point messages currently describe only a location, leaving the watch app to infer whether the point should start navigation or be saved as a waypoint. Making the intended action explicit in v1 lets the phone and watch share one required contract field before the watch-side behaviors diverge.

## What Changes

- **BREAKING**: Require every v1 `point` payload to include an `intent` field.
- Restrict point intent values to `navigate` and `save_waypoint`.
- Update v1 contract schema, docs, fixtures, and Flutter parsing/serialization so missing or unknown point intents are rejected.
- Keep native Garmin send adapters transport-oriented; they continue to receive normalized contract maps from Dart without adding point intent business rules.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `message-contract`: v1 point payloads require an explicit intent that distinguishes navigation from waypoint saving.

## Impact

- `contract/protocol/v1/message.schema.json`
- `contract/protocol/v1/README.md`
- `contract/fixtures/v1/messages/**`
- `lib/features/payloads/**`
- Payload, send queue, and Garmin send gateway tests that construct or validate point messages
- `contract/` submodule revision pin and implementation notes or PR description when the changed contract is adopted
