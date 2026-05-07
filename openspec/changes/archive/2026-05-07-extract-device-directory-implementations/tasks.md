## 1. Directory Split

- [x] 1.1 Extract physical Garmin behavior from `LocalDeviceDirectory` into a physical directory implementation that owns authorized physical devices, native discovery refresh, native device update events, physical default selection, and physical send-target resolution.
- [x] 1.2 Extract emulator behavior into an emulated directory implementation that owns emulator settings, the stable emulator device, emulator default behavior, emulator refresh/no-op behavior, and emulator send-target resolution.
- [x] 1.3 Convert `LocalDeviceDirectory` into a mode-aware facade, or add an equivalent facade with the same app-facing contracts, that delegates `DeviceDirectoryController` calls to the active physical or emulated implementation.
- [x] 1.4 Keep `EmulatorDeviceController` updates routed through the mode-aware facade so Developer Tools can update emulator settings without widgets depending on concrete directory implementations.

## 2. Mode and State Semantics

- [x] 2.1 Preserve persisted physical authorized devices and the physical default watch when emulator mode is enabled or disabled.
- [x] 2.2 Ensure emulator mode exposes the emulator-backed device as the active default without writing the emulator id over the persisted physical default.
- [x] 2.3 Ensure `refreshDevices()` calls native discovery only through the physical directory when emulator mode is disabled.
- [x] 2.4 Ensure `refreshDevices()` in emulator mode returns the current emulator-backed effective device list without calling native discovery.
- [x] 2.5 Ensure native physical status events update the physical cache but do not change the active emulator effective device list while emulator mode remains enabled.
- [x] 2.6 Repair stale persisted emulator default ids to the first physical device when physical devices exist, and ignore or clear stale emulator default ids when no physical devices exist.

## 3. UI Contract Preservation

- [x] 3.1 Keep Devices, Default Watch, Send, and Settings wired to shared `DeviceDirectoryController` and `EmulatorDeviceController` contracts rather than concrete physical or emulated implementations.
- [x] 3.2 Keep existing Devices, Default Watch, Send readiness, and Developer Tools behavior visually unchanged except for behavior required by the mode-aware directory semantics.
- [x] 3.3 Keep native Garmin bridge APIs and method/event channel payload mapping unchanged.

## 4. Tests

- [x] 4.1 Add or reorganize unit tests for the physical directory implementation covering refresh success/failure, timeout fallback, native status events, empty state, default selection, and send-target resolution.
- [x] 4.2 Add unit tests for the emulated directory implementation covering emulator device composition, emulator state updates, emulator refresh/no-op behavior, default behavior, and send-target resolution.
- [x] 4.3 Add unit tests for the mode-aware facade covering mode switching, listener notifications, physical default preservation, stale emulator default-id repair, native discovery isolation in emulator mode, and native event isolation while emulator mode is active.
- [x] 4.4 Update widget tests to verify device-aware screens still consume shared services and continue reacting to emulator state changes through the facade.

## 5. Verification

- [x] 5.1 Run `dart format .`.
- [x] 5.2 Run `flutter analyze`.
- [x] 5.3 Run `flutter test`.
