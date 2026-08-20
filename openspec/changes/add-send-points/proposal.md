## Why

WristLink currently presents point sending only as static Send and Queue placeholders, so users cannot turn a selected or shared location into a durable Garmin command. The Paper designs define the first complete end-to-end payload workflow: choose or share a point, confirm its meaning and target readiness, and send immediately or retain it until the watch reconnects.

## What Changes

- Make **Manual point** open an embedded Google Maps picker on Android and iOS, allowing the user to position a pin and continue with validated coordinates.
- Accept shared text and URLs from Google Maps on Android and iOS in cold-start and already-running app states, preserve the original shared content, resolve supported short links, and parse Google Maps URLs, `geo:` URIs, plain coordinate text, and labels into a point draft.
- Present one confirmation flow for manual and shared points where the user can review coordinates, edit the point name, choose `Navigate` or `Save waypoint`, and see readiness derived from the shared `DeviceDirectory`.
- Build contract-compatible point envelopes through Dart services and attempt delivery through the typed Garmin send gateway; explicitly map stable Dart physical-device ids to raw platform ids and restore native transport-owned device state before cold-start drains, while native share and Garmin adapters remain transport-only.
- Replace point-flow queue placeholders with durable point records and explicit pending, sending, sent, and failed outcomes, including background retry when a previously unavailable watch becomes sendable.
- Show the Paper-designed queued and parse-error outcomes, preserving unparseable shared text so the user can copy it or enter coordinates manually.
- Keep the existing v1 point contract unchanged: `intent`, latitude, longitude, optional label, and optional note already cover this feature.
- Support Android share intents and an iOS Share Extension. Reverse geocoding/search, route preview, and Connect IQ watch-app changes are out of scope.
- **BREAKING**: Raise the iOS deployment target from 13 to 14 so the app and Share Extension can use the maintained Google Maps Flutter integration and one consistent platform baseline.

## Capabilities

### New Capabilities

- `send-point`: Manual map selection, Android and iOS shared-location ingestion and parsing, confirmation/editing, point envelope creation, readiness presentation, and delivery outcomes.
- `send-queue`: Durable queue persistence, point delivery state transitions, acknowledgement handling, retry orchestration, and queue-backed status presentation.

### Modified Capabilities

- `app-shell`: Replace the Send and Queue point placeholders with navigable point entry flows and queue-backed point progress while retaining the primary tab structure.

## Impact

- Flutter feature code under `lib/features/payloads/`, a new point presentation/application area, and an expanded `lib/features/send_queue/` service and storage boundary.
- App-level dependency injection and navigation so share ingress, map configuration, queue storage, device readiness, Garmin transport, and status routes use shared long-lived services.
- Android manifest/MainActivity integration for text sharing, an iOS Share Extension and App Group handoff, background retry scheduling, and Android/iOS map SDK configuration for the embedded picker.
- New Flutter dependencies for the embedded map, HTTP redirect resolution, durable local storage, and platform-appropriate background scheduling, plus flavor-owned non-secret map API-key configuration.
- iOS 13 devices will no longer be supported; Android's resolved minimum SDK must remain compatible with the selected Google Maps plugin or be raised explicitly if Flutter's configured minimum is lower than the plugin requirement.
- Existing typed device directory, message contract, and Garmin send gateway APIs are reused; no message-contract submodule update or watch-app implementation is expected.
- Application dependency lockfiles become tracked release inputs so Dart and CocoaPods transitive dependency resolution remains reproducible across developer and CI environments.
- Unit, widget, platform, and integration coverage for parsing, cold/warm share delivery, map selection, confirmation, durable restoration, send/acknowledgement transitions, retry, and error recovery.
