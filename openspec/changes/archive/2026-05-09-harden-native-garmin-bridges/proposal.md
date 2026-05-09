## Why

The Android and iOS Garmin native bridges now carry enough discovery, status, and companion-state behavior that callback threading, payload drift, and app-entry-file coupling can cause platform-specific regressions. This change hardens the bridge contract before additional Garmin send and background features build on it.

## What Changes

- Serialize native SDK callbacks before mutating bridge state or completing Flutter method/event results.
- Normalize Android and iOS Garmin device payload fields so shared Dart mapping receives equivalent metadata on both platforms.
- Move native bridge responsibilities out of app entry files into focused bridge, mapping, and settings components.
- Replace brittle SDK status mapping with named or centralized mapping logic where available.
- Add native tests for mapping and callback orchestration seams.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `garmin-device-discovery`: tighten native discovery bridge requirements for serialized callback completion, consistent payload metadata, and maintainable platform adapter boundaries.

## Impact

- Android native code under `android/app/src/main/kotlin/com/wristlink/wristlink_flutter/`.
- Android native tests under `android/app/src/test/kotlin/com/wristlink/wristlink_flutter/`.
- iOS native code under `ios/Runner/`.
- iOS native tests under `ios/RunnerTests/`.
- Dart Garmin discovery gateway tests may be updated if payload normalization changes metadata expectations.
- No new external runtime dependencies are expected.
