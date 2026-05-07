## Why

Users need a dedicated place to understand which Garmin watches WristLink can send to and whether each watch is ready before they send data. The current Devices tab is only a placeholder, so it does not yet reflect real device readiness or the emulator state needed for development.

## What Changes

- Implement the Devices primary tab using the referenced paper design in `docs/design/paper/primary-tabs/03-devices.png`.
- Show real Garmin device readiness states, including the default connected watch, nearby devices that need companion setup, and offline devices.
- Add typed Flutter-side device models and a shared device directory service so Devices, Default Watch, Share Confirm, and future sending flows use the same source of truth.
- Add native Garmin SDK discovery adapters for Android and iOS behind typed Platform Channel APIs.
- On iOS, support Garmin Connect Mobile handoff/callback device authorization and cache the latest authorized device list.
- Include "Before sending" guidance so users understand that the companion app must be installed per device and that WristLink sends to the default reachable watch first.
- Account for the Developer Tools emulator setting shown in `docs/design/paper/settings/03-developer-tools.png`.
- When the emulator device is enabled, expose the emulated Garmin device in the same Devices screen list/readiness model as physical devices.
- Preserve the existing primary tab navigation and avoid adding Connect IQ watch app logic to this Flutter repository.

## Capabilities

### New Capabilities

- `devices-screen`: Covers the Devices tab presentation, device readiness states, default-watch emphasis, and user-facing sending guidance.
- `device-directory`: Covers shared Dart device models, default-device selection, send-target readiness, and service APIs consumed across the app.
- `garmin-device-discovery`: Covers Android and iOS native Garmin SDK-backed discovery/status/app-install adapters exposed through typed Dart APIs.
- `emulator-device`: Covers the Flutter-side emulator device setting/state and its visibility as an emulated device on the Devices screen.

### Modified Capabilities

- `app-shell`: The Devices destination changes from a static placeholder to the implemented Devices screen, and Developer Tools changes from a placeholder setting toward emulator device behavior that can affect the Devices tab.

## Impact

- Affects Flutter UI under `lib/app/`, `lib/features/`, and shared UI components used by primary tab destinations.
- Introduces typed Dart models and services for Garmin device readiness, native discovery, emulator state, default-device selection, and send-target checks.
- Adds or extends Android and iOS Platform Channel bridges for Garmin Connect IQ Mobile SDK device discovery/status/app-install data.
- Affects settings/developer-tools navigation and local state for the emulator toggle.
- Requires unit tests for device directory/readiness behavior and widget tests for Devices, Default Watch, Share Confirm readiness, emulator visibility, and updated app-shell behavior.
