## Why

The repository needs a runnable Flutter application baseline before WristLink-specific sending, queueing, and Garmin bridge features can be built coherently. A minimal app scaffold with a basic home screen establishes the app entry point, structure, and first user-facing surface for future capabilities.

## What Changes

- Create the Flutter application scaffold for the WristLink mobile app.
- Add app initialization structure under `lib/app/` for the root widget and routing/navigation entry point.
- Add a basic home screen that introduces WristLink and provides visible placeholders for core workflows such as points, timers, notes, and send queue status.
- Establish shared UI structure consistent with the recommended repository layout.
- Add baseline Flutter tests that verify the app launches and the home screen renders expected content.

## Capabilities

### New Capabilities

- `app-shell`: Defines the runnable Flutter app shell, app initialization, and basic home screen behavior.

### Modified Capabilities

None.

## Impact

- Affected code: `lib/`, `test/`, and Flutter project configuration files needed for a runnable app.
- APIs: No external API changes; no Garmin Platform Channel behavior is introduced by this change.
- Dependencies: Uses Flutter/Dart defaults unless the design phase identifies an existing project dependency requirement.
- Systems: Establishes the mobile app foundation only; Garmin Connect IQ watch app logic remains out of scope.
