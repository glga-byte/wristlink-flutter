## Purpose

Define the baseline Flutter app shell, primary navigation, and initial Send surface for WristLink.

## Requirements

### Requirement: Runnable Flutter App
The system SHALL provide a runnable Flutter application entry point that launches the WristLink app shell.

#### Scenario: App starts
- **WHEN** the Flutter application is launched
- **THEN** the system displays the WristLink app shell without requiring Garmin connectivity or native bridge setup

### Requirement: App Initialization Structure
The system SHALL keep root app initialization in the app layer and keep the executable entry point minimal.

#### Scenario: App shell is initialized
- **WHEN** the executable entry point runs
- **THEN** it delegates to a root app widget located under `lib/app/`

### Requirement: Primary Tab Navigation
The system SHALL provide a primary tab scaffold with Send, Queue, Devices, and Settings destinations.

#### Scenario: Primary tabs are visible
- **WHEN** the app shell is displayed
- **THEN** the system displays navigation destinations for Send, Queue, Devices, and Settings

#### Scenario: User switches primary destination
- **WHEN** the user selects a primary navigation destination
- **THEN** the system displays the selected destination without requiring Garmin connectivity or native bridge setup

### Requirement: Primary Navigation Iconography
The system SHALL use toolbar icons for the Send, Queue, Devices, and Settings destinations that match the referenced paper primary-tab designs.

#### Scenario: Primary navigation icons render
- **WHEN** the app shell is displayed
- **THEN** the primary navigation shows distinct icons for Send, Queue, Devices, and Settings matching the paper design intent

### Requirement: Queue Destination Placeholder
The system SHALL provide a Queue destination backed by durable send records rather than static queue progress and command status examples.

#### Scenario: Queue destination renders
- **WHEN** the user opens the Queue destination
- **THEN** the system shows summary counts and persisted point records with pending, sending, sent, and failed outcomes

#### Scenario: Queue destination is empty
- **WHEN** the user opens the Queue destination before any point has been submitted
- **THEN** the system shows an empty queue state without fabricated progress examples

### Requirement: Devices Destination Placeholder
The system SHALL provide a Devices destination that renders the implemented Garmin device readiness screen using the shared device directory.

#### Scenario: Devices destination renders
- **WHEN** the user opens the Devices destination
- **THEN** the system shows physical Garmin devices from the shared device directory with connection, setup, companion install, default watch, and offline readiness states as available

### Requirement: Basic Home Screen
The system SHALL provide a Send destination as the initial user-facing app surface that identifies the primary "send to watch" workflow.

#### Scenario: Home screen renders
- **WHEN** the app shell is displayed
- **THEN** the initial Send destination shows the "Send to watch" surface and communicates that the user can send useful data to a Garmin watch

### Requirement: Core Workflow Placeholders
The system SHALL make sharing a place from Maps and manual point selection interactive while continuing to present timers, notes, and commands as future workflow placeholders.

#### Scenario: Workflow placeholders are visible
- **WHEN** the initial Send destination is displayed
- **THEN** the user can start a manual point flow and can see instructions for sharing a place from Google Maps

#### Scenario: Future workflow placeholders remain visible
- **WHEN** the initial Send destination is displayed
- **THEN** the user can still see non-interactive placeholders for timers, notes, and commands

### Requirement: Send Quick Action Iconography
The system SHALL show meaningful icons for Send home quick actions matching the referenced paper Send home design.

#### Scenario: Send home quick action icons render
- **WHEN** the initial Send destination is displayed
- **THEN** the share-from-Maps, manual point, timer, note, and command actions each show an icon consistent with their action type

### Requirement: Settings Destination Placeholder
The system SHALL provide a Settings destination in the primary tab scaffold with visible rows for default watch, background sending, Developer Tools, and app information.

#### Scenario: Settings destination renders
- **WHEN** the user opens the Settings destination
- **THEN** the system shows settings rows for `Default watch`, `Background sending`, `Developer Tools`, and `About WristLink`

#### Scenario: Developer Tools setting opens inert layout
- **WHEN** the user opens `Developer Tools`
- **THEN** the system provides the Developer Tools layout without mutating the shared device directory, device settings storage, default watch, or send-target readiness

### Requirement: Baseline Widget Test Coverage
The system SHALL include baseline widget tests for the app shell, primary navigation, and placeholder destination content.

#### Scenario: App shell navigation test passes
- **WHEN** the widget test suite runs
- **THEN** it verifies that the app renders the primary tab scaffold, shows the initial Send destination, and can switch to Queue, Devices, and Settings destinations
