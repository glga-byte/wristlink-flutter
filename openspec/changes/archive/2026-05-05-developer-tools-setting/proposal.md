## Why

The Settings surface should match the current paper design and expose a clear entry point for future diagnostics without adding Developer Tools behavior yet. The app shell iconography should also align with the updated Send home and Settings designs so primary navigation and quick actions feel consistent before deeper workflows are implemented.

## What Changes

- Add a new `Developer Tools` item to the Settings page between `Background sending` and `About WristLink`.
- Show the Developer Tools setting as a visible navigation row only, with supporting text `Emulator device and bridge states`.
- Do not implement the Developer Tools destination, diagnostics, emulator controls, bridge state inspection, persistence, or native integrations as part of this change.
- Update toolbar icon choices to match the paper designs for Send, Queue, Devices, and Settings.
- Update Send home quick action icons to match the paper design for share-from-Maps, manual point, timer, note, and command actions.
- Preserve the existing placeholder nature of the app shell and destinations.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `app-shell`: Update Settings destination content and app shell/action icon requirements to match the referenced paper designs without adding Developer Tools behavior.

## Impact

- Affects Flutter UI code for the app shell, Settings destination, bottom toolbar/navigation icons, and Send home quick action icons.
- Affects widget tests that assert Settings content, Send home quick actions, or primary navigation rendering.
- Does not affect storage, platform channels, Garmin Connect IQ bridge behavior, WorkManager, or send queue domain behavior.
