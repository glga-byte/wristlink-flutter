## 1. Android Bridge Refactor

- [ ] 1.1 Extract Garmin discovery, SDK lifecycle, device event, and companion-state handling from `MainActivity.kt` into a focused Android `GarminDeviceBridge` component.
- [ ] 1.2 Extract Android `wristlink/device_settings` channel handling into a focused `DeviceSettingsBridge` component.
- [ ] 1.3 Keep `MainActivity.kt` as Flutter engine registration glue that wires the focused native bridge components without changing channel names.

## 2. Android Callback And Payload Hardening

- [ ] 2.1 Route Garmin SDK callback bodies that mutate bridge state or complete Flutter results/events through the Android main handler.
- [ ] 2.2 Add idempotent completion handling for Android discovery initialization, companion-state lookup, timeout, and failure paths.
- [ ] 2.3 Normalize Android Garmin device payloads to emit consistent `id`, `name`, `modelName`, `family`, `unitId`, `reachability`, and `companionInstallState` fields.
- [ ] 2.4 Extend Android native tests to cover reachability mapping, companion mapping, payload metadata mapping, and timeout/callback completion behavior where practical.

## 3. iOS Bridge Refactor

- [ ] 3.1 Move `GarminDeviceBridge` from `AppDelegate.swift` into a dedicated iOS source file while preserving callback scheme and plugin registration behavior.
- [ ] 3.2 Move `DeviceSettingsBridge` from `AppDelegate.swift` into a dedicated iOS source file while preserving the `wristlink/device_settings` channel and suite name.
- [ ] 3.3 Keep `AppDelegate.swift` and `SceneDelegate.swift` as startup, plugin registration, and URL callback forwarding glue.

## 4. iOS Callback And Payload Hardening

- [ ] 4.1 Route Garmin SDK callback bodies that mutate bridge state or complete Flutter results/events through the main queue.
- [ ] 4.2 Add idempotent completion handling for iOS authorization, callback, companion-state lookup, timeout, cancellation, and failure paths.
- [ ] 4.3 Normalize iOS Garmin device payloads to emit the same metadata and reachability vocabulary as Android.
- [ ] 4.4 Replace inline raw SDK status mapping with a focused mapper using named SDK cases when available, or isolate documented raw-value mapping behind tests when named cases are unavailable.
- [ ] 4.5 Add XCTest coverage for iOS reachability mapping, companion mapping, payload metadata mapping, and callback completion helpers where practical.

## 5. Dart Contract And Verification

- [ ] 5.1 Update Dart Garmin discovery gateway tests if payload normalization changes expected metadata behavior.
- [ ] 5.2 Run `dart format .`.
- [ ] 5.3 Run `flutter analyze`.
- [ ] 5.4 Run `flutter test`.
- [ ] 5.5 Run Android native unit tests with a supported JDK: `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew testDebugUnitTest`.
- [ ] 5.6 Run native bridge build checks relevant to the changed platforms: `flutter build apk --debug` and `flutter build ios --no-codesign`.
