## ADDED Requirements

### Requirement: Primary Tab Navigation
The system SHALL provide a primary tab scaffold with Send, Queue, Devices, and Settings destinations.

#### Scenario: Primary tabs are visible
- **WHEN** the app shell is displayed
- **THEN** the system displays navigation destinations for Send, Queue, Devices, and Settings

#### Scenario: User switches primary destination
- **WHEN** the user selects a primary navigation destination
- **THEN** the system displays the selected destination without requiring Garmin connectivity or native bridge setup

### Requirement: Queue Destination Placeholder
The system SHALL provide a Queue destination that presents static queue progress and command status examples.

#### Scenario: Queue destination renders
- **WHEN** the user opens the Queue destination
- **THEN** the system shows queue summary counts and example command statuses including queued, sending, failed, and delivered

### Requirement: Devices Destination Placeholder
The system SHALL provide a Devices destination that presents static Garmin device readiness examples.

#### Scenario: Devices destination renders
- **WHEN** the user opens the Devices destination
- **THEN** the system shows example Garmin devices with connection, setup, and offline readiness states

### Requirement: Settings Destination Placeholder
The system SHALL provide a Settings destination placeholder in the primary tab scaffold.

#### Scenario: Settings destination renders
- **WHEN** the user opens the Settings destination
- **THEN** the system shows a placeholder settings surface without requiring any persisted preferences

## MODIFIED Requirements

### Requirement: Basic Home Screen
The system SHALL provide a Send destination as the initial user-facing app surface that identifies the primary "send to watch" workflow.

#### Scenario: Home screen renders
- **WHEN** the app shell is displayed
- **THEN** the initial Send destination shows the "Send to watch" surface and communicates that the user can send useful data to a Garmin watch

### Requirement: Core Workflow Placeholders
The system SHALL show placeholders for the expected WristLink workflows without implementing send behavior.

#### Scenario: Workflow placeholders are visible
- **WHEN** the initial Send destination is displayed
- **THEN** the user can see placeholders for sharing a place from Maps, manual points, timers, notes, and commands

### Requirement: Baseline Widget Test Coverage
The system SHALL include baseline widget tests for the app shell, primary navigation, and placeholder destination content.

#### Scenario: App shell navigation test passes
- **WHEN** the widget test suite runs
- **THEN** it verifies that the app renders the primary tab scaffold, shows the initial Send destination, and can switch to Queue, Devices, and Settings destinations
