## ADDED Requirements

### Requirement: Emulator Device Setting
The system SHALL provide a Developer Tools setting that enables or disables an emulator Garmin device.

#### Scenario: User enables emulator device
- **WHEN** the user turns on the emulator device setting
- **THEN** the system persists emulator mode as enabled and creates an emulator-backed Garmin device in shared device state

#### Scenario: User disables emulator device
- **WHEN** the user turns off the emulator device setting
- **THEN** the system persists emulator mode as disabled and removes the emulator-backed device from shared device state

### Requirement: Emulator Device State Controls
The system SHALL allow Developer Tools to set emulator reachability and companion install states needed to test device-aware flows.

#### Scenario: User selects emulator reachability
- **WHEN** the user selects reachable, offline, sending, or failed in Developer Tools
- **THEN** the system updates the emulator device reachability state in the shared device directory

#### Scenario: User sets emulator companion install state
- **WHEN** the user changes the emulated companion state
- **THEN** the system updates the emulator device companion install state in the shared device directory

### Requirement: Emulator Device Visibility
The system SHALL expose the emulator device through the same device directory contract as physical devices.

#### Scenario: Emulator mode is enabled
- **WHEN** emulator mode is enabled
- **THEN** the Devices tab, Default Watch, and Share Confirm readiness checks can display or consume the emulator device

#### Scenario: Emulator mode is disabled
- **WHEN** emulator mode is disabled
- **THEN** device-aware screens do not show the emulator device

### Requirement: Emulator Discovery Override
The system SHALL apply emulator override behavior inside the device directory composition policy.

#### Scenario: Emulator overrides physical discovery
- **WHEN** emulator mode is enabled
- **THEN** the effective device list for app flows is emulator-backed instead of native physical discovery-backed

#### Scenario: Emulator policy changes later
- **WHEN** the product changes emulator behavior from override to append
- **THEN** the change is isolated to device directory composition and does not require screen-specific emulator branches
