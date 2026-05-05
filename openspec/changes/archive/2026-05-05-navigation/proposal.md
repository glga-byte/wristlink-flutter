## Why

The current app shell is only a basic home surface, but WristLink needs a stable application layout that matches the primary tab design direction before deeper sending, queue, or device logic is implemented. Establishing navigation now gives later feature work clear homes without coupling UI structure to unfinished Garmin bridge behavior.

## What Changes

- Scaffold a primary tab layout based on the referenced paper designs in `docs/design/paper/primary-tabs/`.
- Add top-level destinations for Send, Queue, Devices, and Settings.
- Shape the Send tab around the "Send to watch" surface with entry points for shared places, manual points, timers, notes, and commands.
- Shape the Queue tab around progress summaries and visible queue item status examples.
- Shape the Devices tab around Garmin Connect IQ device readiness examples and pre-send guidance.
- Include a Settings destination as a placeholder so the tab model is complete.
- Keep behavior intentionally simple: no payload parsing, queue persistence, Garmin SDK calls, WorkManager scheduling, or real device discovery in this change.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `app-shell`: Replace the single basic home surface with a primary tabbed app scaffold and placeholder destination screens for the core WristLink workflows.

## Impact

- Affects Flutter app shell and navigation structure under `lib/app/` and likely shared UI/widgets used by destination screens.
- Updates widget tests to verify the app renders the tab scaffold and can switch between primary destinations.
- Does not change Android Platform Channels, Garmin Connect IQ Mobile SDK integration, queue persistence, WorkManager bridge behavior, or payload serialization.
