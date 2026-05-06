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
    developer_tools/   # Emulator device settings and bridge-state controls
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
- Model Garmin devices, emulator devices, default-watch selection, companion install state, and reachability in shared Dart domain types with explicit mapping from native SDK and storage payloads.
- Device-aware Flutter screens must consume `DeviceDirectory` and presentation mappers under `lib/features/devices/`; keep emulator override behavior inside directory composition rather than branching in individual screens.
- Default watch, latest authorized devices, and emulator settings are persisted through the `wristlink/device_settings` Platform Channel; keep native storage as simple key/value persistence and JSON mapping in Dart.
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
- When a feature introduces durable project knowledge, architecture rules, platform constraints, verification steps, or conventions that future agents must follow, update `AGENTS.md` as part of the same change.

## Verification

Run these checks before handing off changes:

```sh
dart format .
flutter analyze
flutter test
# When native SDK bridge changes are included:
flutter build apk --debug
flutter build ios --no-codesign
```
