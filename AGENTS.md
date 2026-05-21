# AGENTS.md

## Project Context

WristLink is a Flutter app for quickly sending short, useful data from a smartphone to Garmin watches: points, timers, notes, and other commands.
This repository covers only the Flutter part. The Garmin Connect IQ app is developed separately.

## Technologies

- Flutter / Dart
- Android bridge through Platform Channels for Garmin Connect IQ Mobile SDK
- iOS bridge through Platform Channels for Garmin Connect IQ Mobile SDK
- Local storage for the send queue
- WorkManager through a native Platform Channel for background sending

## Recommended Structure

```text
lib/
  app/                 # App initialization, routing, DI
  features/
    devices/           # Shared device models, directory/repository, readiness, default watch
    developer_tools/   # Presentational Developer Tools settings UI
    send_queue/        # Send queue and task statuses
    garmin_bridge/     # Typed Dart API over Android/iOS Garmin SDK Platform Channels
    payloads/          # Models for points, timers, notes, commands
  shared/
    storage/           # Local storage abstractions
    errors/            # Shared errors and result types
    ui/                # Shared widgets
android/
  app/src/main/...     # Native bridge, Garmin SDK, WorkManager
ios/
  Runner/...           # Native Garmin SDK bridge and callback handling
test/                  # Unit/widget tests
integration_test/      # Integration scenarios when needed
```

## Best Practices

- Keep business logic in Dart; use native Android/iOS code only for Garmin SDK adapters, platform callbacks, and platform background services.
- Wrap Platform Channels in a typed Dart API; do not call channels directly from UI code.
- Device-aware UI must use shared device models and services; do not keep separate screen-local device state for Devices, Default Watch, Share Confirm, or send readiness.
- Model Garmin devices, default-watch selection, companion install state, and reachability in shared Dart domain types with explicit mapping from native SDK and storage payloads.
- Device-aware Flutter screens must consume `DeviceDirectory` and presentation mappers under `lib/features/devices/`.
- Emulator device logic is intentionally absent. The Developer Tools settings surface is currently presentational only and must not create devices, persist emulator settings, override discovery, change the default watch, or affect send readiness until a future change reintroduces emulator behavior from scratch.
- Default watch and latest authorized devices use explicit platform `DeviceSettingsStore` providers: Android/iOS persist through the required `wristlink/device_settings` Platform Channel, web persists through the web-backed store, and unsupported platforms must surface unsupported storage instead of silently falling back to volatile memory. Keep native/web storage as simple key/value persistence and JSON mapping in Dart.
- Connect IQ companion app UUIDs are flavor-owned in `config/wristlink-flavors.xcconfig`. Android must read that file and expose the selected value as manifest metadata `com.wristlink.CONNECT_IQ_APP_ID`; iOS flavor xcconfigs must map it to `WristLinkConnectIQAppUUID`. Do not duplicate UUID literals in native/platform files or add placeholder special handling.
- Keep `dev` and `prod` installable side by side. Android ids are `com.wristlink.wristlink_flutter.dev` and `com.wristlink.wristlink_flutter`; iOS bundle ids are `com.wristlink.wristlinkFlutter.dev` and `com.wristlink.wristlinkFlutter`; iOS callback schemes are `wristlink-ciq-dev` and `wristlink-ciq`.
- Native Garmin device status changes use the `wristlink/garmin_device_events` Event Channel and must update `DeviceDirectory` through the typed Dart Garmin discovery gateway; do not keep status callbacks native-only.
- On iOS, Garmin device discovery uses Garmin Connect Mobile handoff/callback. Cache only the latest authorized device list and handle cancellation, missing Garmin Connect, timeouts, and app suspension as typed domain outcomes.
- The send queue must survive app restarts and missing watch connectivity.
- Every command must have an explicit status: pending, sending, sent, failed.
- Map Garmin SDK and native bridge errors to clear domain errors.
- UI should follow each platform's native design guidelines: Material Design on Android and iOS-native patterns, controls, navigation, and motion on iOS.
- Do not mix UI models, storage models, and channel payloads without explicit mapping logic.
- Use WorkManager for background sending only through a dedicated bridge/service layer.
- Cover payload serialization, queue behavior, and bridge error handling with tests.
- Do not add Connect IQ watch app logic to this repository.
- Before changing message payloads, acknowledgements, contract schemas,
  fixtures, send queue contract handling, or Garmin transport mapping, read
  `contract/AGENTS.md`.
- When this repo adopts a changed message contract, update the `contract/`
  submodule pointer and document the adopted revision in the change's
  implementation notes or PR description.
- Native Android/iOS Garmin send adapters must stay transport-oriented: accept
  already-normalized contract maps from Dart and map Garmin SDK transport
  failures, including too-large app-message payloads, to typed Dart domain
  errors. Do not add payload business rules in native bridge code.
- When a feature introduces durable project knowledge, architecture rules, platform constraints, verification steps, or conventions that future agents must follow, update `AGENTS.md` as part of the same change.
- When Paper design files are updated, update the corresponding PNG snapshots
  in `docs/design/paper/` in the same change so design reviews stay in sync.

## Local Tooling

- Android Gradle/Kotlin commands must run with a supported JDK such as JDK 17 or JDK 21. Do not use Java 26+ for direct `./gradlew` commands; Kotlin Gradle script initialization can fail before tasks start.
- Flutter commands normally use the JDK bundled with Android Studio, as reported by `flutter doctor -v`.
- Do not change global `JAVA_HOME` just to run project checks. If a direct `./gradlew` command picks up an unsupported system JDK, prefix that command with Android Studio's bundled JDK for this invocation only:

```sh
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew testDevDebugUnitTest testProdDebugUnitTest
```

## Verification

Run these checks before handing off changes:

```sh
dart format .
flutter analyze
flutter test
# When message contract assets or Dart contract models change:
flutter test test/features/payloads
# When native SDK bridge changes are included:
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew testDevDebugUnitTest testProdDebugUnitTest
flutter build apk --debug --flavor dev
flutter build apk --debug --flavor prod
flutter build ios --no-codesign --flavor dev
flutter build ios --no-codesign --flavor prod
```
