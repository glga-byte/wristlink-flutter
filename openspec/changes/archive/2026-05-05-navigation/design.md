## Context

WristLink currently launches a minimal Material app shell that points directly at a single `HomeScreen`. That screen identifies the app and lists broad workflow placeholders, but it does not yet provide the primary application structure shown in the paper designs under `docs/design/paper/primary-tabs/`.

This change establishes the first real navigation scaffold while deliberately keeping all Garmin, queue, payload, and background-send behavior out of scope. The UI should be credible enough for future feature work to land in the correct destination, but the data can remain static examples until the domain layers exist.

## Goals / Non-Goals

**Goals:**

- Replace the single home screen with a top-level tab scaffold for Send, Queue, Devices, and Settings.
- Match the intent of the primary-tab paper designs: Send as the default action surface, Queue for progress/status, Devices for Garmin readiness, and Settings as a placeholder destination.
- Keep root app initialization under `lib/app/` and keep `main.dart` minimal.
- Keep placeholder screen content static and local to the UI layer for now.
- Add widget test coverage for rendering the scaffold and switching between primary destinations.

**Non-Goals:**

- No deep linking, nested routing, or route restoration.
- No payload parsing from Maps shares or manual input forms.
- No persistent send queue, queue mutations, retries, or background scheduling.
- No Garmin Connect IQ SDK calls, native bridge calls, device discovery, or companion-app validation.
- No finalized visual design system beyond applying the current paper design direction to the scaffold.

## Decisions

- Use a stateful app shell with an indexed tab body and `NavigationBar`.
  - Rationale: The app only needs four top-level destinations for this change, and Material 3 `NavigationBar` matches the current `useMaterial3` theme without introducing a routing dependency.
  - Alternative considered: Add a router package or named routes. That would be premature because there is no nested navigation or deep-link requirement yet.

- Keep tab destination widgets simple and static.
  - Rationale: The proposal explicitly avoids complicated logic. Static example content lets implementation validate layout, hierarchy, and tab affordances without creating throwaway domain models.
  - Alternative considered: Create typed UI models for queue items and devices now. That can wait until real queue and Garmin bridge requirements exist, avoiding accidental coupling to placeholder data.

- Treat the existing `app-shell` capability as the owner of this change.
  - Rationale: The current spec already defines app launch, root initialization, baseline home surface, workflow placeholders, and widget tests. The navigation work changes that shell contract rather than introducing a separate capability.
  - Alternative considered: Add a new `navigation` capability. That would split responsibility for app shell behavior across capabilities and make archive semantics less clear.

- Keep Send as the initial selected tab.
  - Rationale: The primary design positions "Send to watch" as the default user task, and later share/manual payload flows should start from this surface.
  - Alternative considered: Keep a generic WristLink home tab. The design images do not include a separate home destination, and it would dilute the primary action.

## Risks / Trade-offs

- Static examples may look more functional than they are -> Use clear placeholder copy and avoid interactive controls that imply real sending, discovery, or setup behavior.
- Material `NavigationBar` may not fully match future iOS-native expectations -> Accept this for the Flutter scaffold now; platform-specific navigation refinement can be handled in a later design pass.
- Moving existing home content could break broad text-based widget tests -> Update tests to assert the new navigation contract and destination switching behavior.
- A Settings placeholder may feel sparse -> Keep it present because the tab set depends on it, but avoid inventing settings behavior before requirements exist.
