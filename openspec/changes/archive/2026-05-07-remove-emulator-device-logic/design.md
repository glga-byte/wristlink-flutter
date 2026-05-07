## Context

The current implementation treats emulator mode as a first-class device source. `LocalDeviceDirectory` is a mode-aware wrapper that switches between a physical directory and `EmulatedDeviceDirectory`; Developer Tools mutates `EmulatorDeviceSettings`; `DeviceSettingsStore` persists those settings; presentation mappers special-case emulator rows; and tests assert emulator behavior across Devices, Default Watch, and send-target readiness.

The requested end state is intentionally simpler: emulator logic should be absent so it can be rebuilt later from scratch. The Settings area should keep the Developer Tools layout only, but interacting with that UI must not produce device state or persist emulator settings.

## Goals / Non-Goals

**Goals:**

- Remove emulator behavior from the shared device domain, directory, storage, presentation, and tests.
- Collapse redundant physical/emulated directory layering so the app-facing local directory directly owns physical Garmin device behavior.
- Keep Settings and Developer Tools UI shape available as inert layout for future implementation.
- Update specs and `AGENTS.md` so future agents do not preserve or reintroduce the previous emulator architecture.

**Non-Goals:**

- Reimplement emulator behavior with a different architecture.
- Add a new fake-device testing framework.
- Change native Garmin discovery, native status event mapping, companion install mapping, or physical default-watch persistence.
- Remove the Developer Tools Settings entry or the visual layout used for future Developer Tools controls.

## Decisions

### Collapse the Directory Wrapper

The surviving app-facing directory should be `LocalDeviceDirectory`. The current physical implementation should be moved into that class/name, and the wrapper that only chose between physical and emulated implementations should be removed.

Rationale: after emulator removal, a `LocalDeviceDirectory -> PhysicalDeviceDirectory` delegation chain adds no meaningful boundary. Keeping both names would encode a historical implementation detail and make future emulator work harder to reason about.

Alternative considered: keep `PhysicalDeviceDirectory` as the only app-facing implementation and update all imports. That is accurate but less compatible with the current app wiring and tests, which already treat `LocalDeviceDirectory` as the local service.

### Remove Emulator Source From Effective Device State

The device domain and presentation layer should stop modeling emulator devices as an effective source. If `DeviceSource` remains useful for native mapping, it should be physical-only; otherwise it can be removed entirely as part of the cleanup.

Rationale: leaving `DeviceSource.emulator` or emulator-specific presentation branches behind would make the removed feature appear supported and would invite accidental partial behavior.

Alternative considered: leave the enum value for future use. That preserves dead API surface and conflicts with the goal of rebuilding emulator logic from scratch later.

### Remove Emulator Settings From Storage Contracts

`DeviceSettingsStore` should only expose default-device and authorized-device persistence. String-backed stores may leave old persisted `emulatorSettings` values untouched in platform storage, but Dart code should no longer read, write, or normalize that key.

Rationale: deleting old persisted values is unnecessary migration risk. Ignoring them cleanly removes behavior while avoiding platform-specific cleanup code.

Alternative considered: actively delete the emulator settings key. That is more invasive and adds storage API surface solely for a removed feature.

### Keep Developer Tools UI Inert

The Developer Tools row should remain in Settings and open a Developer Tools screen that preserves the current layout shape. The screen should use local widget state, disabled controls, or no-op callbacks only; it must not require an emulator controller, update a directory, persist settings, or notify device-aware screens.

Rationale: the user explicitly wants to keep UI layout for later. A presentational screen keeps the design affordance without preserving the old architecture.

Alternative considered: keep only the Settings row and make tapping it do nothing. That is simpler, but it discards the layout the user asked to keep.

## Risks / Trade-offs

- [Risk] Tests currently encode emulator behavior across many files -> Mitigation: replace emulator assertions with physical-device-only assertions and keep a focused widget test that Developer Tools opens but does not affect device state.
- [Risk] Old emulator settings remain in native/web storage -> Mitigation: ignore the key after removing Dart read/write paths; future emulator work can decide whether to migrate or replace it.
- [Risk] Removing `DeviceSource.emulator` can cascade through JSON decoding and fixtures -> Mitigation: make malformed or unknown source values map to physical or drop invalid stored devices, matching the physical-only contract.
- [Risk] Specs and `AGENTS.md` still describe emulator behavior -> Mitigation: update all affected spec deltas and project guidance in the same implementation.

## Migration Plan

1. Update Dart contracts and implementation to remove emulator device logic.
2. Update tests to assert physical-only device behavior and inert Developer Tools UI.
3. Update `AGENTS.md` to document that emulator logic is intentionally absent.
4. Run `dart format .`, `flutter analyze`, and `flutter test`.

Rollback is straightforward at source level by reverting the change. Persisted emulator settings are not migrated or deleted, so rollback would still be able to read old values if the previous code is restored.

## Open Questions

- None. The proposal assumes the Developer Tools row should continue to open an inert screen that preserves layout.
