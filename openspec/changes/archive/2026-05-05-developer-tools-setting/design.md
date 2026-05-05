## Context

The current Flutter app shell provides static Send, Queue, Devices, and Settings destinations. The Settings destination already presents placeholder rows for default watch, background sending, and app information, while the Send destination presents placeholder quick actions without implementing send behavior.

This change aligns those placeholder surfaces with the paper designs at `docs/design/paper/primary-tabs/04-settings.png` and `docs/design/paper/primary-tabs/01-send-home.png`. It is limited to visual structure and icon choices in the Flutter UI.

## Goals / Non-Goals

**Goals:**

- Add a `Developer Tools` row to Settings using the paper design label, subtitle, placement, and visual treatment.
- Keep the Developer Tools row as a non-functional placeholder entry point.
- Update bottom navigation icon choices for Send, Queue, Devices, and Settings to match the paper designs.
- Update Send home quick action icons for share-from-Maps, manual point, timer, note, and command actions.
- Cover the visible Settings and icon updates with focused widget tests where practical.

**Non-Goals:**

- Implement a Developer Tools screen.
- Add emulator controls, bridge state inspection, diagnostic state, persistence, or native bridge integration.
- Change send queue, Garmin bridge, WorkManager, or payload behavior.
- Introduce new icon packages or raster assets for this UI update.

## Decisions

- Use Flutter Material icon data for the updated icons.
  - Rationale: The app currently relies on `Icons.*`, and the paper icons can be approximated with built-in Material symbols without introducing a dependency.
  - Alternative considered: Add a third-party icon library or custom assets. This would increase dependency and asset management for a small placeholder UI update.

- Keep Developer Tools in the existing Settings list component.
  - Rationale: The desired UI is a Settings row consistent with existing settings items, and no navigation behavior is in scope.
  - Alternative considered: Add routing or a disabled destination. Routing would imply behavior the proposal explicitly excludes; a disabled state would reduce the visible future entry point shown in the design.

- Represent icon updates as app shell requirements instead of a new capability.
  - Rationale: The existing `app-shell` spec owns primary navigation, Settings placeholders, and Send home placeholders. The change refines that visible contract rather than introducing a new domain feature.
  - Alternative considered: Create a new `developer-tools` capability. That would incorrectly imply behavior beyond a visible Settings item.

## Risks / Trade-offs

- Material icons may not match the paper design exactly -> choose the closest built-in symbols and keep tests focused on visible content and widget structure rather than exact icon glyph pixels.
- The Developer Tools row could be mistaken for a functional screen -> do not add tap handlers, routing, emulator state, or bridge state content in this change.
- Widget tests can become brittle if they assert too much icon implementation detail -> assert key icon widgets only where identifiers are stable and leave visual exactness to manual/design review.

## Migration Plan

No data migration is required. The change can be deployed as a Flutter UI update and rolled back by removing the added Settings row and restoring the previous icon choices.

## Open Questions

- None.
