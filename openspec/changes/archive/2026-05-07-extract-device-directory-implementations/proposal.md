## Why

`LocalDeviceDirectory` currently owns physical Garmin discovery, native status events, emulator settings, emulator device composition, default-device mutation, and send-target resolution in one class. As device-aware behavior expands toward sending commands and background queue retries, keeping physical and emulated behavior behind flags will make refresh, default selection, and future send policies harder to reason about and easier to regress.

## What Changes

- Extract physical Garmin directory behavior into a physical implementation that owns native discovery, authorized-device cache updates, native status events, physical default selection, and physical send-target resolution.
- Extract emulator behavior into an emulated implementation that owns the emulator-backed device, emulator state changes, emulator refresh semantics, emulator default selection, and emulator send-target resolution.
- Add a mode-aware directory/controller wrapper that exposes the existing shared `DeviceDirectoryController` and `EmulatorDeviceController` contracts to screens while delegating calls to the active physical or emulated implementation.
- Preserve the UI contract: Devices, Default Watch, Send, Share Confirm, and Settings/Developer Tools continue to consume shared device services instead of branching on emulator mode in widgets.
- Preserve physical-device state while emulator mode is enabled so toggling the emulator does not overwrite or discard the user's physical default watch or cached authorized devices.
- Keep future command sending and queue integration able to select physical or emulated behavior through the same mode boundary without adding screen-specific emulator branches.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `device-directory`: Clarify that the shared directory contract is backed by mode-specific physical and emulated implementations through a mode-aware wrapper, while screen consumers continue using one shared service.
- `emulator-device`: Clarify that emulator mode uses an emulated directory implementation that overrides native discovery for app flows and preserves physical directory state while active.

## Impact

- Affects `lib/features/devices/data/local_device_directory.dart`, which should be split or replaced by physical, emulated, and mode-aware directory classes.
- Affects app dependency wiring in `lib/app/wristlink_app_shell.dart` so screens receive the mode-aware shared service and Developer Tools receives the emulator controller boundary.
- Affects tests under `test/features/devices/` to cover physical directory behavior, emulated directory behavior, mode switching, native event isolation, and unchanged widget consumption.
- Does not require new third-party dependencies or native platform changes.
