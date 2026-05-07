## Why

Emulator device support is currently mixed into device discovery, default-watch selection, send-target readiness, settings storage, and Developer Tools UI. The feature needs to be removed so future emulator behavior can be rebuilt from a clean boundary instead of preserving the current mode-aware wrapper and storage contracts.

## What Changes

- **BREAKING**: Remove emulator devices from the shared Garmin device domain, directory behavior, send-target resolution, default-watch selection, and Devices/Share Confirm surfaces.
- **BREAKING**: Remove emulator settings persistence from `DeviceSettingsStore` and platform-backed string storage mappings.
- Collapse the current physical-only implementation into the app-facing local device directory, removing redundant wrapper/facade classes that existed only to switch between physical and emulated implementations.
- Keep the Settings destination's Developer Tools row and Developer Tools screen layout as inert UI only; controls may remain visible but must not persist state, create devices, affect discovery, or affect send readiness.
- Remove emulator-specific adapters, factories, facades, storage models, constants, and tests.
- Update durable project guidance so future work treats emulator logic as absent and intentionally unimplemented.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `app-shell`: Developer Tools remains reachable from Settings, but its emulator UI is presentational and does not affect shared device state.
- `device-directory`: Shared device behavior becomes physical-device-only, with no mode-aware emulated implementation or emulator send target.
- `devices-screen`: Devices UI presents physical Garmin devices only and no longer includes emulator-specific labels, colors, or effective-device states.
- `emulator-device`: Existing emulator-device behavior is removed and replaced by an inert Developer Tools layout contract.
- `device-settings-storage`: Device settings storage no longer reads, writes, or normalizes emulator settings payloads.

## Impact

- Affected Dart code: developer tools presentation, device domain models, device directory implementations, device settings stores, presentation mappers, app-shell dependency wiring, and tests.
- Affected platform storage behavior: Android/iOS/web device settings remain simple key/value storage for default watch and authorized physical devices, but emulator settings are no longer part of the Dart storage contract.
- Affected specs/documentation: current emulator-device, app-shell, device-directory, devices-screen, device-settings-storage, and `AGENTS.md` guidance must stop requiring emulator behavior.
- Not affected: native Garmin discovery adapters, native device event channels, physical default-watch persistence, and Connect IQ companion install mapping.
