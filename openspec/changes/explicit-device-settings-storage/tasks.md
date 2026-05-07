## 1. Storage Boundaries

- [ ] 1.1 Remove fallback-store construction, `_useFallback` state, and fallback read/write paths from `MethodChannelDeviceSettingsStore`.
- [ ] 1.2 Ensure `MethodChannelDeviceSettingsStore` propagates `MissingPluginException` and `PlatformException` from settings reads and writes.
- [ ] 1.3 Add a web-backed `DeviceSettingsStore` that persists the existing default-device, authorized-devices, and emulator-settings string payloads in durable browser storage.
- [ ] 1.4 Keep JSON encoding, decoding, enum fallback, malformed payload handling, and device metadata filtering behavior shared with or equivalent to the current method-channel store.

## 2. Platform Wiring

- [ ] 2.1 Add app-layer platform-aware device settings store construction for iOS, Android, and web.
- [ ] 2.2 Wire `WristLinkAppShell` or its dependency setup to use the platform-aware store provider instead of constructing `MethodChannelDeviceSettingsStore` unconditionally.
- [ ] 2.3 Keep Android and iOS native `wristlink/device_settings` handlers as the required mobile persistence path.
- [ ] 2.4 Ensure Windows and Linux do not receive silent volatile fallback behavior in this change.

## 3. Tests

- [ ] 3.1 Update method-channel settings store tests to verify successful native-channel reads/writes and surfaced missing/plugin platform failures.
- [ ] 3.2 Add web settings store tests for default device id, authorized devices, emulator settings, malformed payloads, and enum fallback behavior.
- [ ] 3.3 Update widget and device-directory tests to inject in-memory or fake settings stores explicitly where storage transport is not under test.
- [ ] 3.4 Add or update app-wiring tests for iOS/Android method-channel selection and web store selection where the current test harness supports it.

## 4. Documentation And Verification

- [ ] 4.1 Update `AGENTS.md` to document explicit device settings storage providers and the no-implicit-fallback rule.
- [ ] 4.2 Run `dart format .`.
- [ ] 4.3 Run `flutter analyze`.
- [ ] 4.4 Run `flutter test`.
- [ ] 4.5 Run web-relevant verification, such as `flutter test --platform chrome`, if supported by the local Flutter setup.
