## 1. App Shell Navigation

- [x] 1.1 Replace the single home screen entry point with a top-level app shell that owns the selected primary tab state.
- [x] 1.2 Add Send, Queue, Devices, and Settings destinations to a Material primary navigation bar.
- [x] 1.3 Ensure Send is the initial selected destination and tab switching does not depend on Garmin connectivity or native bridge setup.

## 2. Placeholder Destinations

- [x] 2.1 Build the Send destination using static content based on the primary-tabs Send design, including share-from-Maps, manual point, timer, note, and command entry points.
- [x] 2.2 Build the Queue destination using static progress summaries and example queued, sending, failed, and delivered items.
- [x] 2.3 Build the Devices destination using static Garmin readiness examples for connected, setup-needed, and offline devices.
- [x] 2.4 Build a Settings placeholder destination without adding persisted preferences or settings logic.

## 3. Tests and Verification

- [x] 3.1 Update widget tests to verify the primary tab scaffold and initial Send destination render.
- [x] 3.2 Add widget coverage for switching to Queue, Devices, and Settings and verifying each destination's placeholder content.
- [x] 3.3 Run `dart format .`, `flutter analyze`, and `flutter test`.
