## Context

`MethodChannelDeviceSettingsStore` is currently constructed by the app shell for every runtime. It calls the `wristlink/device_settings` platform channel and catches `MissingPluginException` or `PlatformException` by switching the store instance to an in-memory fallback.

That fallback keeps tests and unsupported runtimes from crashing, but it also makes storage behavior ambiguous. A missing iOS or Android channel looks like a working app with volatile settings, and web currently has no explicit durable storage provider.

The project supports iOS, Android, and web for this change. Windows and Linux storage providers are intentionally out of scope.

## Goals / Non-Goals

**Goals:**

- Make device settings storage explicit for iOS, Android, and web.
- Preserve the existing iOS and Android `wristlink/device_settings` channel as the production mobile storage boundary.
- Add a durable web-backed `DeviceSettingsStore` for browser sessions.
- Remove silent fallback behavior from `MethodChannelDeviceSettingsStore`.
- Keep tests deterministic by injecting in-memory or fake stores explicitly.
- Keep JSON mapping for device settings in Dart, with platform storage limited to string key/value persistence.

**Non-Goals:**

- Add Windows or Linux storage support.
- Replace the Android/iOS native channel with a third-party storage package.
- Change Garmin device discovery behavior.
- Change default-watch, emulator override, send-target, or readiness semantics.
- Migrate any existing native persisted data schema beyond continuing to read the same string keys.

## Decisions

### Use Platform-Aware Store Construction

Introduce a small app-layer factory that chooses the settings store before constructing `LocalDeviceDirectory`:

- Web gets a web-backed store.
- Android and iOS get `MethodChannelDeviceSettingsStore`.
- Tests can bypass the factory by injecting `InMemoryDeviceSettingsStore` or fakes into the widget under test.

Rationale: `MethodChannelDeviceSettingsStore` should mean "the native channel exists and is required." Platform selection belongs at dependency construction, not inside a store that guesses at runtime failures.

Alternative considered: keep unconditional method-channel construction and only add web fallback inside the method-channel store. That preserves the current ambiguity and makes web behavior depend on channel failure rather than an intentional provider.

### Remove Implicit Fallback From MethodChannelDeviceSettingsStore

`MethodChannelDeviceSettingsStore` should no longer own a fallback store or `_useFallback` state. Missing plugin and platform errors should propagate to callers, where they can fail tests or surface through app initialization/error handling.

Rationale: A broken native settings channel on iOS or Android is a platform integration bug. Silent in-memory fallback can lose user settings and hide the failure until a restart.

Alternative considered: log the error and continue with in-memory storage. That improves observability slightly but still permits non-durable behavior in production.

### Add A Web-Backed Store Behind DeviceSettingsStore

Add a web-specific `DeviceSettingsStore` implementation that stores the same string keys used by the native channel in browser storage. The implementation should live behind conditional imports or another web-only boundary so non-web builds do not import web-only libraries.

Rationale: Web needs durable browser persistence, but it does not have a native `wristlink/device_settings` host channel in this repo. Keeping the same Dart JSON mapping means default watch, authorized devices, and emulator settings keep one data shape across platforms.

Alternative considered: use `shared_preferences` for every platform. That would add a dependency and duplicate the existing mobile native persistence path, which is unnecessary for the current scope.

### Keep Tests Explicit

Widget and device-directory tests should inject in-memory stores or mock the settings channel only when the behavior under test is specifically the method-channel adapter. Tests should no longer rely on missing channel behavior as setup.

Rationale: Tests should document whether they exercise storage behavior, app wiring, or device directory behavior. Explicit injection avoids confusing "works because channel missing" outcomes.

Alternative considered: keep method-channel mocks in all widget tests. That still works, but it keeps broad UI tests coupled to a storage transport detail.

## Risks / Trade-offs

- [Risk] Web storage APIs are only available in web builds -> Mitigation: isolate the web store behind conditional imports or web-only files and verify `flutter analyze` for mobile and web-compatible code paths.
- [Risk] Removing fallback can expose previously hidden mobile channel registration bugs -> Mitigation: add focused tests for channel success and channel error propagation, and verify app startup on Android/iOS.
- [Risk] Browser storage can contain malformed JSON from older development sessions -> Mitigation: keep the existing tolerant JSON decoding behavior that ignores malformed authorized-device payloads and falls back enum values.
- [Risk] Web has settings persistence but no Garmin discovery implementation -> Mitigation: keep discovery unsupported on web unless emulator mode is enabled; this change only concerns settings storage.
- [Risk] App startup may need a user-visible error state if mobile settings storage fails during `load()` -> Mitigation: define implementation handling before coding; failing tests are acceptable for adapter bugs, while UI behavior should remain intentional.
