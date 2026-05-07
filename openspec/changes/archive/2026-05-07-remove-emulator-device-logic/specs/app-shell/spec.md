## MODIFIED Requirements

### Requirement: Devices Destination Placeholder
The system SHALL provide a Devices destination that renders the implemented Garmin device readiness screen using the shared device directory.

#### Scenario: Devices destination renders
- **WHEN** the user opens the Devices destination
- **THEN** the system shows physical Garmin devices from the shared device directory with connection, setup, companion install, default watch, and offline readiness states as available

### Requirement: Settings Destination Placeholder
The system SHALL provide a Settings destination in the primary tab scaffold with visible rows for default watch, background sending, Developer Tools, and app information.

#### Scenario: Settings destination renders
- **WHEN** the user opens the Settings destination
- **THEN** the system shows settings rows for `Default watch`, `Background sending`, `Developer Tools`, and `About WristLink`

#### Scenario: Developer Tools setting opens inert layout
- **WHEN** the user opens `Developer Tools`
- **THEN** the system provides the Developer Tools layout without mutating the shared device directory, device settings storage, default watch, or send-target readiness
