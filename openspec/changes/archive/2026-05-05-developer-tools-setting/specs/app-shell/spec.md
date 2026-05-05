## ADDED Requirements

### Requirement: Primary Navigation Iconography
The system SHALL use toolbar icons for the Send, Queue, Devices, and Settings destinations that match the referenced paper primary-tab designs.

#### Scenario: Primary navigation icons render
- **WHEN** the app shell is displayed
- **THEN** the primary navigation shows distinct icons for Send, Queue, Devices, and Settings matching the paper design intent

### Requirement: Send Quick Action Iconography
The system SHALL show meaningful icons for Send home quick actions matching the referenced paper Send home design.

#### Scenario: Send home quick action icons render
- **WHEN** the initial Send destination is displayed
- **THEN** the share-from-Maps, manual point, timer, note, and command actions each show an icon consistent with their action type

## MODIFIED Requirements

### Requirement: Settings Destination Placeholder
The system SHALL provide a Settings destination placeholder in the primary tab scaffold with visible rows for default watch, background sending, Developer Tools, and app information.

#### Scenario: Settings destination renders
- **WHEN** the user opens the Settings destination
- **THEN** the system shows settings rows for `Default watch`, `Background sending`, `Developer Tools`, and `About WristLink` without requiring any persisted preferences

#### Scenario: Developer Tools setting is placeholder only
- **WHEN** the user opens the Settings destination
- **THEN** the system shows `Developer Tools` with supporting text `Emulator device and bridge states` without showing Developer Tools behavior, emulator controls, or bridge state details
