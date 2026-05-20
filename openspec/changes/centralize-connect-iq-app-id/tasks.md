## 1. Flavor Configuration Contract

- [ ] 1.1 Define `dev` and `prod` Flutter flavor names and the shared Connect IQ app UUID configuration key.
- [ ] 1.2 Define Android ids as `com.wristlink.wristlink_flutter.dev` for `dev` and `com.wristlink.wristlink_flutter` for `prod`.
- [ ] 1.3 Define iOS bundle identifiers as `com.wristlink.wristlinkFlutter.dev` for `dev` and `com.wristlink.wristlinkFlutter` for `prod`.
- [ ] 1.4 Define hardcoded placeholder Connect IQ app UUID values in flavor build configuration: `11111111-1111-1111-1111-111111111111` for `dev` and `22222222-2222-2222-2222-222222222222` for `prod`.
- [ ] 1.5 Document that placeholder UUIDs must be replaced in flavor build configuration with real Garmin Connect IQ app UUIDs, while native code treats the placeholders as ordinary UUIDs until replacement.
- [ ] 1.6 Define `WRISTLINK_GARMIN_CALLBACK_SCHEME` with `wristlink-ciq-dev` for `dev` and `wristlink-ciq` for `prod`.

## 2. Android Flavor Wiring

- [ ] 2.1 Add Android `dev` and `prod` product flavors with the required flavor dimension.
- [ ] 2.2 Configure distinct Android application ids for `dev` and `prod`, using a development suffix or equivalent so `dev` resolves to `com.wristlink.wristlink_flutter.dev` and `prod` resolves to `com.wristlink.wristlink_flutter`.
- [ ] 2.3 Resolve the Connect IQ UUID per Android flavor from `WRISTLINK_CONNECT_IQ_APP_UUID` defined once in Gradle flavor build configuration.
- [ ] 2.4 Replace the hardcoded Android manifest UUID value with manifest metadata substitution fed by the selected flavor.
- [ ] 2.5 Remove Android placeholder UUID special handling so configured UUIDs are treated uniformly.
- [ ] 2.6 Add Android checks that verify `dev` and `prod` manifest metadata contain the selected UUID values.
- [ ] 2.7 Add Android checks that verify `dev` and `prod` application ids resolve to distinct values.

## 3. iOS Flavor Wiring

- [ ] 3.1 Add shared Xcode schemes named `dev` and `prod` compatible with `flutter build ios --flavor <name>`.
- [ ] 3.2 Add flavor build configurations such as `Debug-dev`, `Profile-dev`, `Release-dev`, `Debug-prod`, `Profile-prod`, and `Release-prod`, based on the standard Flutter debug/release xcconfig files.
- [ ] 3.3 Configure distinct iOS bundle identifiers so `dev` resolves to `com.wristlink.wristlinkFlutter.dev` and `prod` resolves to `com.wristlink.wristlinkFlutter`.
- [ ] 3.4 Resolve the Connect IQ UUID per iOS flavor from `WRISTLINK_CONNECT_IQ_APP_UUID` defined once in flavor xcconfig/build settings.
- [ ] 3.5 Replace the hardcoded iOS Info.plist UUID value with build-setting substitution from the selected flavor.
- [ ] 3.6 Replace the hardcoded iOS Garmin callback scheme with flavor-specific build metadata and matching Info.plist URL schemes.
- [ ] 3.7 Remove iOS placeholder UUID special handling so configured UUIDs are treated uniformly.
- [ ] 3.8 Add iOS checks that verify `dev` and `prod` Info.plist metadata contain the selected UUID values.
- [ ] 3.9 Add iOS checks that verify `dev` and `prod` callback schemes resolve to `wristlink-ciq-dev` and `wristlink-ciq`.
- [ ] 3.10 Add iOS checks that verify `dev` and `prod` bundle identifiers resolve to distinct values.

## 4. Documentation And Guidance

- [ ] 4.1 Update `AGENTS.md` with the Flutter flavor and Connect IQ UUID configuration rule.
- [ ] 4.2 Document local development build commands using the `dev` flavor.
- [ ] 4.3 Document CI/release build commands using the `prod` flavor and where the development and production UUIDs are hardcoded.

## 5. Verification

- [ ] 5.1 Run `dart format .`.
- [ ] 5.2 Run `flutter analyze`.
- [ ] 5.3 Run `flutter test`.
- [ ] 5.4 Run Android native tests if Android Gradle logic or native tests change: `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew testDebugUnitTest`.
- [ ] 5.5 Run platform build checks for the development flavor: `flutter build apk --debug --flavor dev` and `flutter build ios --no-codesign --flavor dev`.
- [ ] 5.6 Run or document production flavor build checks: `flutter build apk --debug --flavor prod` and `flutter build ios --no-codesign --flavor prod`.
