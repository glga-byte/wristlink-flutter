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
- Keep physical Garmin ids canonical as `physical:<raw-native-id>` in Dart domain state, device settings, and queue records. The typed Dart Garmin gateway must validate and remove exactly one `physical:` prefix before sending the raw Android numeric id or iOS UUID over native transport channels; native Garmin caches remain keyed by the raw SDK id. Cover discovery-to-send round trips for both platform id formats.
- Connect IQ companion app UUIDs are flavor-owned in `config/wristlink-flavors.xcconfig`. Android must read that file and expose the selected value as manifest metadata `com.wristlink.CONNECT_IQ_APP_ID`; iOS flavor xcconfigs must map it to `WristLinkConnectIQAppUUID`. Do not duplicate UUID literals in native/platform files or add placeholder special handling.
- Keep `dev` and `prod` installable side by side. Android ids are `com.wristlink.wristlink_flutter.dev` and `com.wristlink.wristlink_flutter`; iOS bundle ids are `com.wristlink.wristlinkFlutter.dev` and `com.wristlink.wristlinkFlutter`; iOS callback schemes are `wristlink-ciq-dev` and `wristlink-ciq`.
- Share ingress is transport-only on native platforms: persist bounded raw text/URL records before notifying Flutter, expose pending/live records through the typed shared-content channels, and delete them only after Dart acknowledgement while suppressing recent OS redelivery. Coordinate parsing, short-link resolution, and point-flow ownership remain in Dart.
- Keep share-ingress lifecycle coverage executable: Android changes must run the connected `ShareIngressLifecycleInstrumentedTest` suite on an emulator/device, and iOS changes must run the host native tests that exercise extension persistence, stopped/running app delivery, acknowledgement cleanup, callback coexistence, and exactly-once emission.
- iOS share configuration is flavor-owned. Dev uses App Group `group.com.wristlink.wristlinkFlutter.dev`, callback scheme `wristlink-share-dev`, and extension bundle id `com.wristlink.wristlinkFlutter.dev.ShareExtension`; prod uses `group.com.wristlink.wristlinkFlutter`, `wristlink-share`, and `com.wristlink.wristlinkFlutter.ShareExtension`. Each app configuration and its matching Share Extension must use identical App Group entitlements.
- Google Maps keys are flavor build inputs, never Dart constants or committed unrestricted credentials. Keep Android manifest and iOS SDK initialization wired to the shared flavor configuration, and restrict deployed keys by the matching package/bundle id and signing identity in Google Cloud.
- Keep every iOS app, test, and Share Extension configuration on an iOS 14 minimum deployment target unless the Google Maps integration and extension are removed together.
- Native Garmin device status changes use the `wristlink/garmin_device_events` Event Channel and must update `DeviceDirectory` through the typed Dart Garmin discovery gateway; do not keep status callbacks native-only.
- On iOS, Garmin device discovery uses Garmin Connect Mobile handoff/callback. Cache only the latest authorized device list and handle cancellation, missing Garmin Connect, timeouts, and app suspension as typed domain outcomes.
- Treat persisted device reachability as a snapshot, not current transport readiness after process restart. Foreground and background composition must idempotently rehydrate native Garmin device/app state before startup drains: Android may silently query known SDK devices, while iOS must rebuild transport-only `IQDevice` objects from the Dart-owned persisted authorized-device descriptors without launching Garmin Connect Mobile or creating a second authoritative device store. Until hydration succeeds, keep the target known but non-send-ready and retain queued work.
- The send queue must survive app restarts and missing watch connectivity.
- Every command must have an explicit status: pending, sending, sent, failed.
- Map Garmin SDK and native bridge errors to clear domain errors.
- UI should follow each platform's native design guidelines: Material Design on Android and iOS-native patterns, controls, navigation, and motion on iOS.
- Do not mix UI models, storage models, and channel payloads without explicit mapping logic.
- Use WorkManager for background sending only through a dedicated bridge/service layer.
- Keep queue delivery orchestration in Dart through the shared delivery coordinator: resolve the record's stored physical target before a message-specific atomic claim, route every foreground/background trigger through the mutually exclusive drain, and persist transport plus acknowledgement outcomes before publishing them.
- Persist queue records transactionally in SQLite with a unique message id. Pending claims and guarded transitions must be atomic across foreground/background isolates, and `pending`, `sending`, `sent`, and `failed` remain the only stored statuses; **queued** is a UI label for an offline pending record, not another durable state.
- Treat a restored `sending` record whose acknowledgement recovery deadline expires as unknown delivery. It must become terminal and require explicit retry with the same message id; never automatically risk a duplicate point command.
- Native acknowledgement ownership ends at emitting raw app-message maps on `wristlink/garmin_acknowledgements`; Dart must validate them as `WatchAcknowledgement`, correlate message ids, apply idempotent queue transitions, and treat malformed, unknown, or late events as diagnostics rather than unrelated queue mutations.
- Background Flutter engines must register the same persisted device-settings and Garmin send/acknowledgement channels as the foreground engine. Android does this through the engine registrar plugin and iOS through WorkManager's plugin-registrant callback. Background execution remains best effort, scheduling failures must not discard pending records, and startup/foreground/device-readiness fallback drains are mandatory. Verify background composition and idempotent native bridge registration in tests, run both native platform test suites, and build both dev/prod flavors before handoff when these paths change.
- Cover payload serialization, queue behavior, and bridge error handling with tests.
- Track the application dependency lockfiles `/pubspec.lock` and `/ios/Podfile.lock`; keep broad or package-local lockfiles ignored unless their owning artifact is also an application.
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

Before running connected Android tests, check `adb devices`. If no emulator or
physical device is connected, ask the user to start one. Do not launch an
emulator automatically.

```sh
dart format .
flutter analyze
flutter test
# When message contract assets or Dart contract models change:
flutter test test/features/payloads
# When native SDK bridge changes are included:
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./android/gradlew -p android testDevDebugUnitTest testProdDebugUnitTest
# When Android share ingress or activity lifecycle handling changes (requires a connected emulator/device):
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./android/gradlew -p android connectedDevDebugAndroidTest
flutter build apk --debug --flavor dev
flutter build apk --debug --flavor prod
flutter build ios --no-codesign --flavor dev
flutter build ios --no-codesign --flavor prod
```
