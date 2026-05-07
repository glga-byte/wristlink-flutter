## Why

Device settings currently depend on a method-channel store that silently falls back to in-memory storage when the native channel is missing or fails. That hides broken iOS/Android registration and gives web a non-durable storage path that loses default-watch, authorized-device, and emulator settings across reloads.

## What Changes

- **BREAKING**: Remove implicit in-memory fallback from the method-channel device settings store.
- Add explicit device settings storage selection for supported platforms:
  - iOS and Android use the existing `wristlink/device_settings` native channel.
  - Web uses an explicit web-backed store with durable browser persistence.
  - Tests inject an in-memory or fake store directly instead of relying on channel failure.
- Make missing or failing iOS/Android settings channels surface as errors instead of silent volatile storage.
- Keep durable device settings JSON mapping in Dart and native storage as simple key/value persistence.
- Document the platform storage contract in `AGENTS.md`.

## Capabilities

### New Capabilities

- `device-settings-storage`: Defines durable storage behavior and platform provider selection for default watch, authorized devices, and emulator settings.

### Modified Capabilities

- None.

## Impact

- Affected Dart code: device settings store implementations, app-shell dependency construction, device directory tests, widget tests.
- Affected platform code: existing Android and iOS channel registration remains required; no Windows or Linux scope in this change.
- Affected web behavior: web must use an explicit durable store rather than missing-channel fallback.
- Affected project guidance: `AGENTS.md` must describe explicit platform stores and no implicit fallback persistence.
