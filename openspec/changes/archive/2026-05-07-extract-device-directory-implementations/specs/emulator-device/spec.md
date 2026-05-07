## MODIFIED Requirements

### Requirement: Emulator Device State Controls
The system SHALL allow Developer Tools to set emulator reachability and companion install states through an emulator controller that updates the emulated directory implementation.

#### Scenario: User selects emulator reachability
- **WHEN** the user selects reachable, offline, sending, or failed in Developer Tools
- **THEN** the system updates the emulator device reachability state in the emulated directory implementation and notifies shared device consumers when emulator mode is active

#### Scenario: User sets emulator companion state
- **WHEN** the user changes the emulated companion state
- **THEN** the system updates the emulator device companion install state in the emulated directory implementation and notifies shared device consumers when emulator mode is active

### Requirement: Emulator Device Visibility
The system SHALL expose the emulator device through the same shared mode-aware directory contract as physical devices.

#### Scenario: Emulator mode is enabled
- **WHEN** emulator mode is enabled
- **THEN** the Devices tab, Default Watch, and Share Confirm readiness checks can display or consume the emulator device through the shared directory contract

#### Scenario: Emulator mode is disabled
- **WHEN** emulator mode is disabled
- **THEN** device-aware screens do not show the emulator device and consume the physical directory implementation through the same shared directory contract

#### Scenario: Emulator state changes while visible
- **WHEN** emulator mode is enabled and Developer Tools changes emulator reachability or companion state
- **THEN** device-aware screens update from the shared directory without screen-specific emulator branches

### Requirement: Emulator Discovery Override
The system SHALL apply emulator override behavior by selecting the emulated directory implementation inside the mode-aware directory wrapper.

#### Scenario: Emulator overrides physical discovery
- **WHEN** emulator mode is enabled
- **THEN** the effective device list for app flows is emulator-backed instead of native physical discovery-backed

#### Scenario: Emulator refresh avoids native discovery
- **WHEN** emulator mode is enabled and refresh is requested through the shared device directory
- **THEN** the system returns the emulator-backed device state without calling native Garmin discovery or launching Garmin Connect authorization

#### Scenario: Physical state is preserved during emulator mode
- **WHEN** emulator mode is enabled after physical devices and a physical default watch have been persisted
- **THEN** the system keeps the physical devices and physical default watch available for when emulator mode is disabled

#### Scenario: Emulator policy changes later
- **WHEN** the product changes emulator behavior from override to append
- **THEN** the change is isolated to mode-aware directory composition and does not require screen-specific emulator branches
