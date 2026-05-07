## ADDED Requirements

### Requirement: Inert Developer Tools Layout
The system SHALL keep a Developer Tools settings surface as presentational UI only while emulator behavior is removed.

#### Scenario: Developer Tools layout opens
- **WHEN** the user opens Developer Tools from Settings
- **THEN** the system displays the Developer Tools layout without requiring an emulator controller, emulator settings store, or emulated device directory

#### Scenario: Developer Tools controls are inert
- **WHEN** the user interacts with Developer Tools controls
- **THEN** the system does not create emulator devices, persist emulator settings, refresh discovery differently, change the default watch, or change send-target readiness

## REMOVED Requirements

### Requirement: Emulator Device Setting
**Reason**: Emulator device mode is being removed so the feature can be rebuilt later from scratch.
**Migration**: Keep the Developer Tools UI layout only; do not persist emulator enabled state or create emulator-backed Garmin devices.

### Requirement: Emulator Device State Controls
**Reason**: Emulator reachability and companion-state mutation depended on the removed emulator controller and emulated directory.
**Migration**: Developer Tools controls are inert until a future change specifies new emulator behavior.

### Requirement: Emulator Device Visibility
**Reason**: Device-aware screens should now consume physical Garmin devices only.
**Migration**: Remove emulator devices from Devices, Default Watch, Share Confirm readiness, and shared directory state.

### Requirement: Emulator Discovery Override
**Reason**: Mode-aware discovery override behavior is removed with the emulated directory implementation.
**Migration**: Device refresh always uses the physical Garmin discovery path provided by the local device directory.
