## Why

WristLink is about to add a separate Connect IQ watch app, and the phone app needs a stable, shared message contract before send-queue and native-send behavior are implemented. A versioned contract prevents the Flutter, Android/iOS bridge, and Connect IQ repositories from drifting as point, timer, note, command, and acknowledgement payloads evolve.

## What Changes

- Introduce a shared message-contract capability for phone-to-watch messages, watch-to-phone acknowledgements, schema fixtures, versioning rules, and compatibility expectations.
- Treat the `contract/` submodule as the read-only source of truth consumed by the Flutter repo and the separate Connect IQ repo.
- Add Flutter-side contract consumption points for typed Dart payload models, validation fixtures, and Garmin send bridge boundaries without putting Connect IQ watch app logic in this repository.
- Define verification expectations so both repositories validate against the same contract fixtures before changing message shapes.

## Capabilities

### New Capabilities

- `message-contract`: Defines the shared WristLink phone/watch protocol, contract submodule ownership, versioning rules, payload envelopes, acknowledgements, and fixture-based compatibility checks.

### Modified Capabilities

- None.

## Impact

- Affects future Dart payload models under `lib/features/payloads/`, send queue serialization under `lib/features/send_queue/`, and typed Garmin send bridge APIs under `lib/features/garmin_bridge/`.
- Uses the `contract/` submodule as an external project boundary shared with the Connect IQ app repository.
- Adds contract fixture validation to Flutter tests when payload and send bridge implementation begins.
- Does not add Connect IQ watch app code to this repository.
