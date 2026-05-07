## 1. Domain And Storage Cleanup

- [x] 1.1 Remove emulator domain contracts, including `EmulatorDeviceSettings`, `EmulatorDeviceController`, emulator device ids, and the emulated directory implementation.
- [x] 1.2 Remove emulator settings read/write methods from `DeviceSettingsStore` and all concrete store implementations.
- [x] 1.3 Remove emulator settings JSON mapping and web/local-storage key usage from string-backed device settings stores.
- [x] 1.4 Remove emulator source handling from `GarminDevice` domain models, storage decoding, fixtures, and presentation models.

## 2. Device Directory Simplification

- [x] 2.1 Collapse the physical directory implementation into the app-facing `LocalDeviceDirectory` and remove the redundant physical/emulated wrapper structure.
- [x] 2.2 Ensure device refresh always uses native Garmin discovery through the local directory and never switches to an emulated implementation.
- [x] 2.3 Ensure default-watch selection and send-target resolution use physical device state only.
- [x] 2.4 Remove stale emulator default-id repair logic unless it is still needed as a one-way legacy cleanup for persisted physical defaults.

## 3. Developer Tools UI

- [x] 3.1 Keep the Settings `Developer Tools` row and route to a Developer Tools screen.
- [x] 3.2 Refactor `DeveloperToolsScreen` so it has no emulator controller dependency and no persistent emulator settings dependency.
- [x] 3.3 Preserve the Developer Tools layout as inert UI; interactions must not mutate device directory state, device settings storage, default watch, discovery behavior, or send-target readiness.

## 4. Tests And Documentation

- [x] 4.1 Remove or rewrite emulator-specific device-directory, storage, widget, web-store, and presentation tests.
- [x] 4.2 Add or update tests proving physical device directory behavior still works after the class collapse.
- [x] 4.3 Add or update widget tests proving Developer Tools opens and remains inert.
- [x] 4.4 Update `AGENTS.md` to document that emulator device logic is intentionally absent and Developer Tools UI is currently presentational only.

## 5. Verification

- [x] 5.1 Run `dart format .`.
- [x] 5.2 Run `flutter analyze`.
- [x] 5.3 Run `flutter test`.
