## 1. Device Domain and Directory

- [x] 1.1 Create `lib/features/devices/` structure for domain models, services, presentation mappers, and test fixtures.
- [x] 1.2 Implement typed device models for device id, source, reachability, companion install state, readiness, default selection, and normalized native metadata.
- [x] 1.3 Implement centralized readiness derivation for ready, needs setup, unavailable, and emulator bridge/testing states.
- [x] 1.4 Define the shared device directory/repository interface for effective devices, refresh, default-device selection, and send-target resolution.
- [x] 1.5 Implement an initial device directory that composes cached physical devices, emulator state, and default-watch state without exposing screen-local sample data.
- [x] 1.6 Add local storage abstractions for default watch, emulator settings, and latest authorized normalized devices.

## 2. Garmin Discovery Bridge

- [x] 2.1 Define a typed Dart `GarminDeviceDiscoveryGateway` API and domain errors for SDK unavailable, Garmin Connect missing, authorization cancelled, no authorized devices, timeout, and unsupported platform.
- [x] 2.2 Implement Platform Channel payload mapping between native discovery results and shared Dart device models.
- [ ] 2.3 Implement the Android Garmin Connect IQ Mobile SDK adapter for device discovery, device status, companion app install status, and native error mapping.
- [ ] 2.4 Configure Android dependencies and manifest entries needed for Garmin SDK discovery and status lookup.
- [ ] 2.5 Implement the iOS Garmin Connect IQ Mobile SDK adapter for device authorization handoff, callback parsing, device status events, companion app install status, and native error mapping.
- [ ] 2.6 Configure iOS SDK dependency, callback URL scheme or universal link handling, Info.plist entries, Bluetooth usage text, and linker/build settings required by the Garmin iOS SDK.
- [x] 2.7 Persist only the latest authorized normalized native device list and replace stale cached devices after each successful native authorization refresh.

## 3. Emulator Device

- [x] 3.1 Create `lib/features/developer_tools/` structure for emulator settings and presentation state.
- [x] 3.2 Implement emulator enabled/disabled state and emulator device composition through the shared device directory.
- [x] 3.3 Implement emulator reachability controls for reachable, offline, sending, and failed states.
- [x] 3.4 Implement emulator companion install controls and map them to shared companion install state.
- [x] 3.5 Apply emulator override behavior in device directory composition so screens do not need emulator-specific branches.

## 4. Device-Aware UI

- [x] 4.1 Refactor the app shell to inject the shared device directory into device-aware screens using the repo's lightweight app structure.
- [x] 4.2 Replace the Devices placeholder with the implemented Devices tab using `docs/design/paper/primary-tabs/03-devices.png`.
- [x] 4.3 Implement Devices presentation mapping for featured default ready device, secondary setup/offline rows, status labels, and before-sending guidance.
- [x] 4.4 Add a Devices refresh or authorize action that calls the shared device directory and preserves previous devices on refresh failure.
- [x] 4.5 Implement empty and error states for no devices, unsupported platform, missing Garmin Connect, cancelled authorization, and discovery timeout.
- [x] 4.6 Implement or update the Default Watch screen using `docs/design/paper/settings/01-default-watch.png` and shared default-device selection.
- [x] 4.7 Implement or update Developer Tools UI using `docs/design/paper/settings/03-developer-tools.png` and shared emulator state.
- [x] 4.8 Update Share Confirm readiness checks to consume shared send-target resolution for found-watch and companion-installed status.

## 5. Tests

- [x] 5.1 Add unit tests for device model mapping, readiness derivation, and send-target resolution.
- [x] 5.2 Add unit tests for device directory composition with physical devices, emulator override, default device persistence, stale default devices, and empty states.
- [x] 5.3 Add unit tests for native discovery gateway mapping and typed domain error mapping.
- [x] 5.4 Add widget tests for the Devices tab with ready default, setup, offline, empty, error, and emulator-enabled states.
- [x] 5.5 Add widget tests for Default Watch selection using the shared device directory.
- [x] 5.6 Add widget tests for Developer Tools emulator controls updating shared device state.
- [x] 5.7 Add widget tests for Share Confirm readiness using shared send-target resolution.
- [x] 5.8 Update existing app-shell tests to assert Devices and Developer Tools are no longer placeholders.

## 6. Verification and Documentation

- [x] 6.1 Run `dart format .`.
- [x] 6.2 Run `flutter analyze`.
- [x] 6.3 Run `flutter test`.
- [ ] 6.4 Run `flutter build apk --debug` after Android native bridge work is included.
- [ ] 6.5 Run `flutter build ios --no-codesign` after iOS native bridge work is included.
- [x] 6.6 Update `AGENTS.md` with any additional durable project knowledge discovered during implementation.
- [x] 6.7 Run `openspec validate implement-devices-screen --strict`.
