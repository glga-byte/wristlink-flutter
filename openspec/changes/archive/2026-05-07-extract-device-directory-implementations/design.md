## Context

The current `LocalDeviceDirectory` is the only `DeviceDirectoryController` implementation. It reads and writes persisted settings, calls native Garmin discovery, subscribes to native device update events, composes the emulator device when enabled, mutates default-device state when emulator mode changes, and resolves send targets for both physical and emulator devices.

That shape worked for the first Devices implementation, but it makes emulator override behavior easy to get wrong. A user-facing example is the refresh affordance: `refreshDevices()` always means native discovery in the current class, even though emulator mode is meant to override native discovery for app flows. The same branching risk will grow when sending commands and queue retry behavior need physical and emulated paths.

## Goals / Non-Goals

**Goals:**

- Split physical Garmin directory behavior from emulator-backed directory behavior.
- Keep one shared service contract for device-aware screens: `DeviceDirectoryController` for Devices, Default Watch, Send, Share Confirm, and future queue behavior.
- Keep one Developer Tools contract: `EmulatorDeviceController` for reading and updating emulator settings.
- Preserve physical authorized devices and physical default-watch selection while emulator mode is enabled.
- Make emulator refresh and future emulator send behavior explicit no-native operations rather than conditionals hidden among physical discovery code.
- Keep native Garmin bridge adapters unchanged and behind typed Dart abstractions.

**Non-Goals:**

- Implement command/message sending, WorkManager queue delivery, or Connect IQ watch app behavior.
- Add a new state management package or dependency injection framework.
- Change the visual UI contract for Devices, Default Watch, Send, or Developer Tools.
- Redesign persistent storage beyond the minimal changes needed to stop emulator mode from overwriting physical default selection.

## Decisions

### Mode-Aware Facade

Keep the app and widgets wired to a single shared controller. `LocalDeviceDirectory` should become the mode-aware facade, or be replaced by an equivalently named facade to avoid broad call-site churn. It implements both `DeviceDirectoryController` and `EmulatorDeviceController`, owns two internal directory implementations, and delegates `devices`, `defaultDeviceId`, `emptyReason`, `lastRefreshError`, `refreshDevices()`, `setDefaultDevice()`, and `resolveSendTarget()` to whichever mode is active.

Rationale: Screens already have the right dependency shape. The problem is not that widgets consume one service; the problem is that one concrete service mixes incompatible physical and emulator responsibilities.

Alternative considered: inject separate physical/emulator directories into UI widgets and branch in screens. That would violate the existing architecture rule that emulator override behavior belongs in directory composition, not in individual device-aware screens.

### Physical Directory Implementation

Create a physical directory implementation that owns:

- persisted authorized physical devices
- persisted physical default device id
- native discovery refresh through `GarminDeviceDiscoveryGateway.discoverDevices()`
- native status updates through `GarminDeviceDiscoveryGateway.deviceUpdates`
- physical send-target resolution using the shared readiness rules

The physical directory should ignore non-physical native updates, keep timeout behavior that falls back to cached physical devices, map unexpected native failures to typed discovery errors, and cancel its event subscription on disposal.

Rationale: Native Garmin discovery and event handling have platform-specific behavior and failure modes. Keeping those concerns in a physical-only implementation prevents emulator state from accidentally launching Garmin Connect, overwriting physical cache, or leaking native errors into emulator flows.

Alternative considered: keep physical behavior in `LocalDeviceDirectory` and add guard flags for emulator mode. This is exactly the branching pattern the change is meant to remove.

### Emulated Directory Implementation

Create an emulated directory implementation that owns:

- current `EmulatorDeviceSettings`
- the stable emulator `GarminDevice`
- emulator default-device behavior
- emulator send-target resolution using the same readiness rules
- emulator refresh semantics

When emulator mode is enabled, the emulated directory exposes the emulator device as the active effective device. Its `refreshDevices()` should be an emulated refresh/no-op that returns the current emulator-backed list and must not call native discovery. With only one emulator device, default selection can be internal and deterministic: the emulator device is the active default while emulator mode is enabled.

Rationale: Treating the emulator as a real directory implementation makes it possible to emulate future message sending, failures, and queue states through the same app-facing contracts used by physical devices.

Alternative considered: only extract a helper that builds the emulator `GarminDevice`. That would reduce a little duplication but would not address refresh, default, send-target, or future command-sending policy.

### Default Selection Preservation

The physical default watch must remain physical state. Enabling emulator mode must not write the emulator id over the stored physical default. Disabling emulator mode should reveal the previously selected physical default if it still exists, or fall back to the existing missing/default resolution rules.

If existing persisted data contains the emulator id as the default from the previous implementation, the physical directory should treat it as a stale/non-physical default and recover without exposing it as a sendable physical target. If physical devices exist and the product wants automatic repair, the implementation can choose the first physical device and rewrite the physical default; otherwise it can preserve the stale value and return `defaultDeviceMissing` until the user chooses a physical default.

Rationale: Developer Tools should not disturb a user's real watch preferences. This also keeps future physical queue retries from accidentally targeting emulator state after the user turns the emulator off.

Alternative considered: add separate storage keys for physical and emulator defaults immediately. That may be useful later if multiple emulator devices exist, but it is unnecessary while there is a single deterministic emulator target.

Implementation rule: stale persisted emulator default ids are legacy pollution from the previous mixed implementation. On physical directory load, keep a persisted physical id when it is present, preserve a missing physical id as `defaultDeviceMissing`, repair a persisted emulator id to the first physical device when physical devices exist, and clear or ignore a persisted emulator id when no physical devices exist.

### Notifications and Native Events

The mode-aware facade should notify listeners when the active directory changes or when emulator settings toggle the active mode. Physical native events may continue updating and persisting the physical directory cache while emulator mode is active, but they must not change the active effective device list shown to screens until physical mode becomes active again.

Rationale: Keeping the physical directory warm preserves cached physical status without leaking inactive-mode changes into emulator UI. It also makes mode switching responsive because the latest physical state is ready when the emulator is disabled.

Alternative considered: dispose and recreate the physical directory whenever emulator mode changes. That would avoid inactive notifications but would churn native event subscriptions and make state preservation more fragile.

Implementation rule: while emulator mode is active, the physical directory may process and persist native physical status events. The mode-aware facade continues exposing emulator devices and emulator send-target resolution, and active UI changes only for emulator state changes or mode switches.

### Future Command Sending Boundary

Do not add command sending to `DeviceDirectory` in this change. The split should, however, leave a clear path for a future `DeviceRuntime`, `SendCommandGateway`, or equivalent pair where physical and emulated command senders are selected by the same mode boundary as the directory.

Rationale: Device discovery/readiness and command delivery are related but different responsibilities. The directory split should prepare for send behavior without overloading the directory contract now.

Alternative considered: add send methods to the directory now. That would couple this refactor to command payload design before payload and queue requirements are ready.

## Risks / Trade-offs

- [Risk] More classes for the same current behavior → Mitigation: keep the public controller contract stable and add focused tests per implementation so the extra structure buys clarity.
- [Risk] Listener forwarding can double-notify or miss inactive-to-active changes → Mitigation: centralize notification forwarding in the mode-aware facade and test active physical, active emulator, and mode-toggle cases.
- [Risk] Migrating away from emulator-overwritten default ids can surprise existing local dev state → Mitigation: handle stale emulator ids as missing physical defaults and keep behavior explicit in tests.
- [Risk] Passive native event updates during emulator mode could still affect stored physical cache → Mitigation: allow cache updates but test that active emulator `devices` and send-target resolution do not change while emulator mode remains active.
- [Risk] The split may overfit before command sending exists → Mitigation: limit this change to directory/readiness contracts and document the future sender boundary without implementing it.

## Migration Plan

1. Introduce physical and emulated directory implementations behind the existing device directory interfaces.
2. Convert `LocalDeviceDirectory` into the mode-aware facade that delegates to the active implementation and forwards listener notifications.
3. Preserve existing app-shell constructor wiring where possible, updating only dependency construction internals.
4. Move existing directory tests to implementation-specific coverage and add mode-aware tests for switching, refresh isolation, default preservation, and native event isolation.
5. Run `dart format .`, `flutter analyze`, and `flutter test`.

Rollback is straightforward because this is a Dart-only refactor behind existing widget contracts: revert the facade and implementation split to the previous single `LocalDeviceDirectory` if the tests reveal behavior drift.

## Open Questions

- None.
