## 1. Flavor Configuration Contract

- [x] 1.1 Define `dev` and `prod` Flutter flavor names and the shared Connect IQ app UUID configuration key.
- [x] 1.2 Define Android ids as `com.wristlink.wristlink_flutter.dev` for `dev` and `com.wristlink.wristlink_flutter` for `prod`.
- [x] 1.3 Define iOS bundle identifiers as `com.wristlink.wristlinkFlutter.dev` for `dev` and `com.wristlink.wristlinkFlutter` for `prod`.
- [x] 1.4 Define hardcoded placeholder Connect IQ app UUID values in shared flavor configuration: `11111111-1111-1111-1111-111111111111` for `dev` and `22222222-2222-2222-2222-222222222222` for `prod`.
- [x] 1.5 Document that placeholder UUIDs must be replaced in `config/wristlink-flavors.xcconfig` with real Garmin Connect IQ app UUIDs, while native code treats the placeholders as ordinary UUIDs until replacement.
- [x] 1.6 Define `WRISTLINK_GARMIN_CALLBACK_SCHEME` with `wristlink-ciq-dev` for `dev` and `wristlink-ciq` for `prod`.
- [x] 1.7 Centralize committed Connect IQ UUID values in `config/wristlink-flavors.xcconfig` so Android and iOS consume the same source of truth.

## 2. Android Flavor Wiring

- [x] 2.1 Add Android `dev` and `prod` product flavors with the required flavor dimension.
- [x] 2.2 Configure distinct Android application ids for `dev` and `prod`, using a development suffix or equivalent so `dev` resolves to `com.wristlink.wristlink_flutter.dev` and `prod` resolves to `com.wristlink.wristlink_flutter`.
- [x] 2.3 Resolve the Connect IQ UUID per Android flavor from `config/wristlink-flavors.xcconfig` through Gradle and feed it to `WRISTLINK_CONNECT_IQ_APP_UUID`.
- [x] 2.4 Replace the hardcoded Android manifest UUID value with manifest metadata substitution fed by the selected flavor.
- [x] 2.5 Remove Android placeholder UUID special handling so configured UUIDs are treated uniformly.
- [x] 2.6 Add Android checks that verify `dev` and `prod` manifest metadata contain the selected UUID values.
- [x] 2.7 Add Android checks that verify `dev` and `prod` application ids resolve to distinct values.

## 3. iOS Flavor Wiring

- [x] 3.1 Add shared Xcode schemes named `dev` and `prod` compatible with `flutter build ios --flavor <name>`.
- [x] 3.2 Add flavor build configurations such as `Debug-dev`, `Profile-dev`, `Release-dev`, `Debug-prod`, `Profile-prod`, and `Release-prod`, based on the standard Flutter debug/release xcconfig files.
- [x] 3.3 Configure distinct iOS bundle identifiers so `dev` resolves to `com.wristlink.wristlinkFlutter.dev` and `prod` resolves to `com.wristlink.wristlinkFlutter`.
- [x] 3.4 Resolve the Connect IQ UUID per iOS flavor by including `config/wristlink-flavors.xcconfig` from flavor xcconfigs and mapping the selected value to `WRISTLINK_CONNECT_IQ_APP_UUID`.
- [x] 3.5 Replace the hardcoded iOS Info.plist UUID value with build-setting substitution from the selected flavor.
- [x] 3.6 Replace the hardcoded iOS Garmin callback scheme with flavor-specific build metadata and matching Info.plist URL schemes.
- [x] 3.7 Remove iOS placeholder UUID special handling so configured UUIDs are treated uniformly.
- [x] 3.8 Add iOS checks that verify `dev` and `prod` Info.plist metadata contain the selected UUID values.
- [x] 3.9 Add iOS checks that verify `dev` and `prod` callback schemes resolve to `wristlink-ciq-dev` and `wristlink-ciq`.
- [x] 3.10 Add iOS checks that verify `dev` and `prod` bundle identifiers resolve to distinct values.

## 4. Documentation And Guidance

- [x] 4.1 Update `AGENTS.md` with the Flutter flavor and Connect IQ UUID configuration rule.
- [x] 4.2 Document local development build commands using the `dev` flavor.
- [x] 4.3 Document CI/release build commands using the `prod` flavor and the shared config file where development and production UUIDs are hardcoded.

## 5. Verification

- [x] 5.1 Run `dart format .`.
- [x] 5.2 Run `flutter analyze`.
- [x] 5.3 Run `flutter test`.
- [x] 5.4 Run Android native tests if Android Gradle logic or native tests change: `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew testDebugUnitTest`.
- [x] 5.5 Run platform build checks for the development flavor: `flutter build apk --debug --flavor dev` and `flutter build ios --no-codesign --flavor dev`.
- [x] 5.6 Run or document production flavor build checks: `flutter build apk --debug --flavor prod` and `flutter build ios --no-codesign --flavor prod`.
