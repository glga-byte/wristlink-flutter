## Context

The app shell already exposes Send, Queue, Devices, and Settings primary destinations, but Devices and Developer Tools are static placeholders. The referenced paper designs show device state in several workflows: the Devices tab summarizes readiness, Default Watch lets the user choose the preferred target, Developer Tools can enable an emulator device, and Share Confirm checks whether a watch and companion are ready before sending.

Devices therefore need to be a shared app concept rather than UI-only sample data. The Flutter app should own typed device models, selection state, emulator state, and readiness derivation, while native Android and iOS remain limited to Garmin Connect IQ Mobile SDK discovery/status/app-install bridge work.

## Goals / Non-Goals

**Goals:**

- Introduce reusable Dart models for Garmin devices, readiness, companion install state, default selection, and device source.
- Provide a shared service/repository boundary that all device-aware screens can use: Devices tab, Default Watch, Share Confirm, and future send queue behavior.
- Support real Garmin device listing through native Android and iOS SDK adapters exposed by typed Platform Channels.
- Support iOS Garmin Connect Mobile device authorization through handoff/callback, with persistent caching of the latest authorized devices.
- Implement the Devices screen from `docs/design/paper/primary-tabs/03-devices.png` using the shared model instead of hard-coded screen-only state.
- Support the Developer Tools emulator device from `docs/design/paper/settings/03-developer-tools.png` through the same device model and service contract as physical watches.
- Keep emulator behavior visible to Default Watch and Share Confirm so development/debug states exercise the same app flows as real devices.

**Non-Goals:**

- Implement Connect IQ watch app logic in this repository.
- Implement message sending, WorkManager background sending, or queue delivery behavior as part of the Devices screen change.
- Build a production-grade device history store beyond the minimum needed for latest authorized devices, default watch, and emulator state.
- Build final share parsing or send execution behavior; Share Confirm should consume device readiness but remains outside this screen implementation.

## Decisions

### Shared Device Domain

Create a `features/devices` domain layer with small immutable models:

- `GarminDeviceId`: stable app identifier for physical or emulated devices.
- `GarminDevice`: display name, model/family metadata if available, source, visual accent, last seen metadata, companion status, transport status, and default flag.
- `DeviceSource`: `physical` or `emulator`.
- `CompanionStatus`: `installed`, `missing`, or `unknown`.
- `DeviceReachability`: `reachable`, `nearby`, `offline`, and bridge/testing statuses needed by emulator controls such as `sending` and `failed`.
- `DeviceReadiness`: derived state used by UI and sending checks, such as `ready`, `needsSetup`, or `unavailable`.

Rationale: Default Watch, Devices, Share Confirm, and queue/sending validation all need the same facts but present them differently. A shared domain model avoids each screen inventing labels like "connected", "setup", "found", or "companion installed" from unrelated data.

Alternative considered: keep local view models inside each screen. This is faster initially but would duplicate readiness logic and make emulator behavior drift between Devices, Settings, and Send flows.

### Device Directory Service

Introduce a `DeviceDirectory` or `DeviceRepository` abstraction that exposes the effective device list and default-device selection:

- `watchDevices()` or `devices` stream/value for UI screens.
- `refreshDevices()` for user-initiated native discovery/authorization.
- `getDefaultDevice()` for Send home and Share Confirm readiness checks.
- `setDefaultDevice(deviceId)` for the Default Watch screen.
- `getSendTarget()` that returns the default reachable device first, or a clear unavailable reason.

The implementation should compose physical devices from native discovery adapters, persisted authorized devices, and emulator state. Deterministic sample data may remain test-only, but production UI should read through the directory contract.

Rationale: The UI can be implemented now without blocking on native Garmin integration, while the service boundary prevents direct Platform Channel calls from UI code later.

Alternative considered: expose Platform Channel responses directly to widgets. This violates the project constraint to wrap channels in typed Dart APIs and would couple UI rendering to native bridge payloads.

### Native Garmin Discovery Adapters

Add a `GarminDeviceDiscoveryGateway` Dart interface backed by platform-specific implementations:

- Android: wrap the Garmin Connect IQ Mobile SDK in native Kotlin/Java code and expose discovery, device status, and companion app install status through a Platform Channel.
- iOS: add Garmin's Connect IQ Mobile SDK package/XCFramework, call Garmin Connect Mobile for device selection/authorization, parse the callback URL into native `IQDevice` records, cache only the latest authorized device list, register for device events, and map `IQDeviceStatus` plus app install status into the Dart model.
- Unsupported/unavailable cases: return typed domain errors such as SDK unavailable, Garmin Connect missing, authorization cancelled, no authorized devices, bridge timeout, or unsupported platform.

On iOS, the app must be configured for the Garmin Connect callback path using a URL scheme or universal link, plus the Info.plist entries required by the SDK. The native adapter should treat Garmin Connect handoff as an asynchronous refresh operation because the app can be backgrounded or suspended while Garmin Connect is open.

Rationale: Garmin provides official Android and iOS Mobile SDKs for companion apps. Keeping platform details behind one Dart gateway lets the Devices screen and send flows consume one normalized contract while honoring each platform's discovery constraints.

Alternative considered: use custom Bluetooth scanning on iOS. This is not appropriate for Connect IQ companion app workflows because Garmin's SDK and Garmin Connect authorization are the supported path for interacting with Connect IQ-compatible devices.

### Emulator Device Composition

Add an `EmulatorDeviceService` that stores whether the emulator is enabled and the selected emulator bridge state. When enabled, it contributes a `GarminDevice` with `source: DeviceSource.emulator` to the same directory contract used by physical devices.

The Developer Tools design says the emulator overrides Connect IQ discovery. Model that as a directory policy: while emulator mode is enabled, the effective device list is emulator-backed for app flows, and the emulator device is shown on the Devices screen, Default Watch, and Share Confirm readiness checks. If product behavior later changes to append emulator devices beside physical devices, only the directory composition policy should change; UI consumers should not change.

Rationale: Treating emulator state as a real device source lets development exercise the same readiness, default selection, and send-target logic as physical watches.

Alternative considered: special-case emulator UI inside Developer Tools only. That would hide emulator behavior from the actual screens that need to be validated.

### UI-Specific View Models

Build thin presentation mappers on top of domain models:

- Devices tab mapper: featured default/ready device, secondary rows, status chips, and "Before sending" guidance.
- Default Watch mapper: selectable rows with default badge and setup/offline status.
- Share Confirm mapper: readiness checks such as "`Forerunner 965 found`" and "`Companion app installed`".

Rationale: Domain models should not contain copy, badge colors, or layout-specific grouping. Mappers keep visual treatment consistent with paper designs while leaving business state reusable.

Alternative considered: put display strings directly on `GarminDevice`. This would make a single model responsible for multiple screen-specific vocabularies.

### State and Persistence

Use the app layer for dependency construction and pass the device directory into screens through a lightweight inherited dependency or constructor injection, following the current simple app structure. Store default watch, emulator enabled/state, and the latest authorized native devices through a local settings/storage abstraction. Native SDK objects should not be persisted directly; persist only stable IDs and normalized metadata needed to reconstruct Dart models.

Rationale: The repo is still small and does not yet use a DI framework or state management package. Constructor/inherited injection keeps the design testable without adding a dependency prematurely.

Alternative considered: add a full state management package now. The current scope does not justify that dependency until device discovery, queue, and settings state become more complex.

## Risks / Trade-offs

- [Risk] The initial service may use static sample devices before Garmin discovery exists -> Mitigation: define the service contract around domain models and isolate sample data behind the repository implementation.
- [Risk] iOS discovery requires leaving the app for Garmin Connect and receiving a callback that can be cancelled or delayed -> Mitigation: model refresh as asynchronous, preserve the last authorized device list, and expose clear refresh/cancel/error states.
- [Risk] Native SDK setup can diverge between Android and iOS -> Mitigation: keep native adapters thin and normalize all outputs through `GarminDeviceDiscoveryGateway` tests.
- [Risk] Emulator override semantics may conflict with a future need to display physical and emulated devices together -> Mitigation: keep override/append behavior inside directory composition policy, not in UI widgets.
- [Risk] Readiness labels can drift between screens -> Mitigation: centralize readiness derivation in the devices domain and use screen-specific mappers only for presentation copy.
- [Risk] Default watch selection can point at a device that later disappears -> Mitigation: `getSendTarget()` should validate reachability and companion install state at use time and return an explicit unavailable reason.
- [Risk] Adding architecture before send behavior may overfit discovery data -> Mitigation: keep models minimal, prefer enums for states visible in designs and native SDK status/app-install results, and avoid fields that are not currently consumed.
