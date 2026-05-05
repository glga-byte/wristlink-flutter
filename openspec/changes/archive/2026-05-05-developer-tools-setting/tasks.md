## 1. Settings Surface

- [x] 1.1 Add a `Developer Tools` settings row between `Background sending` and `About WristLink`.
- [x] 1.2 Set the Developer Tools supporting text to `Emulator device and bridge states`.
- [x] 1.3 Keep the Developer Tools row non-functional with no destination, tap behavior, diagnostics, emulator controls, persistence, or bridge state content.
- [x] 1.4 Update the `Background sending` supporting text to match the paper design if the current copy differs.

## 2. Icon Updates

- [x] 2.1 Replace the bottom navigation icons for Send, Queue, Devices, and Settings with built-in Material icons that match the paper design intent.
- [x] 2.2 Add the share-from-Maps icon inside the Send home feature card.
- [x] 2.3 Add built-in Material icons to the Send quick action rows for manual point, timer, note, and command.
- [x] 2.4 Preserve the existing placeholder behavior and avoid adding new icon dependencies or raster assets.

## 3. Tests and Verification

- [x] 3.1 Update widget tests to assert the Developer Tools row and supporting text render in Settings.
- [x] 3.2 Add or update widget test coverage for the visible Send quick action/icon structure where practical.
- [x] 3.3 Run `dart format .`.
- [x] 3.4 Run `flutter analyze`.
- [x] 3.5 Run `flutter test`.
