## Context

WristLink needs a runnable Flutter baseline before feature work can be layered in. The repository currently has OpenSpec metadata and project guidance, but no Flutter app structure, entry point, home screen, or baseline widget tests.

The scaffold must follow the repository boundaries from `AGENTS.md`: business logic belongs in Dart, Platform Channels stay behind typed bridge APIs, and Connect IQ watch app logic is out of scope. This change is limited to the Flutter app shell and a basic first screen.

## Goals / Non-Goals

**Goals:**

- Provide a runnable Flutter application with a conventional `main.dart` entry point.
- Put root app initialization in `lib/app/` so later routing, dependency injection, and app-wide configuration have a clear home.
- Add a basic home screen that communicates the app purpose and shows placeholders for points, timers, notes, and send queue status.
- Add baseline widget coverage that verifies the app renders the home screen.
- Keep the scaffold compatible with later send queue, Garmin bridge, payload, storage, and WorkManager features.

**Non-Goals:**

- Implement Garmin Connect IQ SDK integration.
- Implement Platform Channels, WorkManager, local persistence, or send queue behavior.
- Implement real payload creation or delivery flows.
- Add Connect IQ watch app code.

## Decisions

### Use A Small App Shell Under `lib/app/`

The root widget will live under `lib/app/` and be launched from `lib/main.dart`. This keeps `main.dart` minimal and leaves a stable place for future app-level concerns such as routing, dependency injection, theming, and localization.

Alternative considered: keep all startup code in `main.dart`. That is simpler for a trivial app, but it creates churn as soon as app-level concerns are added.

### Model The Home Screen As A Feature

The basic home screen will live under `lib/features/home/` rather than directly in `lib/app/`. The app shell owns application setup, while the home feature owns the first user-facing screen. This matches the repository's feature-oriented structure and avoids mixing app wiring with screen content.

Alternative considered: place the home screen in `lib/shared/ui/`. That would blur shared widgets with a concrete screen and make later feature growth less clear.

### Use Flutter Defaults For Initial Navigation And Styling

The scaffold will use Flutter's standard `MaterialApp` and Material components without adding routing or state-management dependencies. A single home route is enough for this change, and keeping dependencies minimal reduces setup risk.

Alternative considered: add a routing package or state-management framework immediately. That would be premature before the app has multiple flows or shared state.

### Use Static Placeholder Content For Core Workflows

The home screen will show non-interactive or minimally interactive placeholders for points, timers, notes, and queue status. This creates a useful first viewport without implying that sending behavior exists.

Alternative considered: wire buttons to stub services. That risks creating fake contracts before the Garmin bridge and queue specs exist.

## Risks / Trade-offs

- App scaffold may need later restructuring as routing and dependency injection mature -> Mitigation: keep root app and home feature separated so future changes are localized.
- Placeholder home content could be mistaken for implemented workflows -> Mitigation: label content as upcoming or empty-state oriented without exposing fake send actions.
- Flutter project generation may introduce platform files beyond the user-visible scaffold -> Mitigation: keep generated platform changes conventional and avoid native Garmin or WorkManager logic in this change.

## Migration Plan

Create the Flutter scaffold and add the new `lib/` and `test/` files. No data migration or runtime migration is needed because there is no existing app state.

Rollback is removing the scaffold files and generated Flutter configuration from the change.

## Open Questions

None for the initial scaffold.
