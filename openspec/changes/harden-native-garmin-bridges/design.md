## Context

The Flutter layer already owns the shared Garmin device model, readiness derivation, device directory, and device settings mapping. The Android and iOS native layers are adapters for Garmin Connect IQ Mobile SDK behavior, but their bridge code has grown inside `MainActivity.kt` and `AppDelegate.swift`.

Recent review found three maintainability risks:

- SDK callbacks can mutate shared native state and complete Flutter results without a guaranteed main-thread/main-queue handoff.
- Android and iOS payload mapping has drifted for metadata and reachability values.
- Bridge registration, SDK orchestration, payload mapping, event emission, and settings persistence are concentrated in app entry files.

The change should keep business logic and JSON mapping in Dart where possible while making native bridge behavior deterministic and testable.

## Goals / Non-Goals

**Goals:**

- Ensure native SDK callbacks are serialized before updating bridge state or completing Flutter method/event results.
- Define and enforce one Garmin native payload contract for Android and iOS discovery and status events.
- Extract native code into focused bridge, mapping, and settings components with app entry files left as thin registration/lifecycle glue.
- Add native tests around mapping and callback completion behavior.
- Preserve existing Dart domain APIs and channel names.

**Non-Goals:**

- Add Garmin send-message behavior or Connect IQ watch-app logic.
- Change device directory readiness rules except where native reachability mapping currently creates platform drift.
- Replace Platform Channels with a different transport.
- Add emulator device behavior.

## Decisions

### Serialize callbacks through platform main execution

All native SDK callbacks that touch bridge state or Flutter `Result`/event sinks will hop to the main thread/queue first.

- Android will route Garmin callback bodies through `mainHandler.post { ... }`.
- iOS will route Garmin callback bodies through `DispatchQueue.main.async { ... }`.
- Each async operation that can complete a Flutter result will use a small idempotent completion helper so timeout and SDK callback paths cannot double-complete the same request.

Alternative considered: rely on SDK callback queues. That keeps less code but leaves behavior dependent on SDK internals and makes tests harder to reason about.

### Keep the native payload contract explicit and small

Both platforms will emit the same keys for discovery responses and status events:

- `id`
- `name`
- `modelName`
- `family`
- `unitId`
- `reachability`
- `companionInstallState`

Android should stop using part number as `modelName`; part number-like values should map to `family` when available. iOS should use the same normalized reachability vocabulary as Android and Dart.

Alternative considered: compensate for platform differences in Dart. Dart already tolerates some payload variation, but pushing platform-specific meaning into Dart makes future native bridge changes less obvious.

### Split native bridge responsibilities by concern

Android should move Garmin discovery/event behavior out of `MainActivity` into a `GarminDeviceBridge`-style component and move settings channel behavior into `DeviceSettingsBridge`. Mapping helpers should remain separately testable.

iOS should move `GarminDeviceBridge` and `DeviceSettingsBridge` out of `AppDelegate.swift` into dedicated files, with mapping in a focused helper or extension that can be covered by XCTest.

Alternative considered: leave files in place and only patch callback handling. That fixes the highest-risk behavior but preserves a structure that makes later send/background bridge changes harder to isolate.

### Prefer named SDK statuses and mapper tests

Where the Garmin SDK exposes named enum cases, native mapping should use names rather than raw integer values. If an SDK type only exposes raw values in Swift, the mapping must be isolated in one helper with tests documenting the expected values.

Alternative considered: keep raw-value mapping inline. That is concise but brittle and difficult to audit.

## Risks / Trade-offs

- Native refactor could accidentally break channel registration -> keep channel names unchanged and verify with Flutter tests plus native unit tests.
- Garmin SDK types may be difficult to construct in tests -> isolate pure string/raw-value mapping helpers and test those directly; keep SDK object integration thin.
- iOS callback behavior may depend on URL handoff timing -> preserve current callback scheme and pending-request timeout behavior while changing only completion serialization.
- Android event listener unregister semantics may be limited by the SDK -> at minimum keep registration deduped and clear local registration state on SDK shutdown; add explicit unregister only if the SDK provides a safe API.

## Migration Plan

1. Extract native bridge and settings classes without changing channel names or Dart APIs.
2. Normalize native payload mapping and update tests.
3. Add callback serialization and idempotent completion helpers.
4. Run Dart, Flutter, Android unit, and iOS build checks relevant to native bridge changes.
5. Roll back by reverting the native refactor; persisted settings keys and Dart cache payloads remain unchanged.
