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
- Native Garmin discovery uses the `wristlink/garmin_devices` Platform Channel. Companion install checks require configuring the separate Connect IQ watch app UUID in Android manifest metadata `com.wristlink.CONNECT_IQ_APP_ID` and iOS `WristLinkConnectIQAppUUID`; placeholder UUIDs intentionally map companion state to unknown.
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
- Treat `contract/` as the read-only source of truth for WristLink
  phone-to-watch message envelopes, payload kinds, watch acknowledgements,
  schemas, metadata, and fixtures shared with the separate Connect IQ
  repository. Flutter code may consume these assets but must not redefine
  incompatible local message shapes.
- When adopting a changed message contract, update the `contract/` submodule
  pointer in the parent repo and document the adopted revision in the change's
  implementation notes or PR description.
- WristLink message contract v1 uses compact JSON envelopes with protocol
  version `1`, a 26-character ULID id, kind, UTC creation timestamp, optional
  TTL seconds, and kind-specific payload data. Enforce the shared v1 serialized
  envelope budget of 1024 UTF-8 JSON bytes before queueing or invoking native
  Garmin transport.
- Watch acknowledgements must be parsed through shared contract models and
  matched by original message id. Only message kinds whose contract metadata
  requires acknowledgement should wait for accepted/rejected/unsupported/
  retryable watch responses before final queue status transitions.
- Native Android/iOS Garmin send adapters must stay transport-oriented: accept
  already-normalized contract maps from Dart and map Garmin SDK transport
  failures, including too-large app-message payloads, to typed Dart domain
  errors. Do not add payload business rules in native bridge code.
- When a feature introduces durable project knowledge, architecture rules, platform constraints, verification steps, or conventions that future agents must follow, update `AGENTS.md` as part of the same change.

## Local Tooling

- Android Gradle/Kotlin commands must run with a supported JDK such as JDK 17 or JDK 21. Do not use Java 26+ for direct `./gradlew` commands; Kotlin Gradle script initialization can fail before tasks start.
- Flutter commands normally use the JDK bundled with Android Studio, as reported by `flutter doctor -v`.
- Do not change global `JAVA_HOME` just to run project checks. If a direct `./gradlew` command picks up an unsupported system JDK, prefix that command with Android Studio's bundled JDK for this invocation only:

```sh
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew testDebugUnitTest
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
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew testDebugUnitTest
flutter build apk --debug
flutter build ios --no-codesign
```
