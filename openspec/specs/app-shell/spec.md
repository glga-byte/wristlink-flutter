## Purpose

Define the baseline Flutter app shell and initial home surface for WristLink.

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

### Requirement: Basic Home Screen
The system SHALL provide a basic home screen that identifies WristLink and presents the initial user-facing app surface.

#### Scenario: Home screen renders
- **WHEN** the app shell is displayed
- **THEN** the home screen shows the WristLink name and communicates that the app sends useful data to Garmin watches

### Requirement: Core Workflow Placeholders
The system SHALL show placeholders for the expected WristLink workflows without implementing send behavior.

#### Scenario: Workflow placeholders are visible
- **WHEN** the home screen is displayed
- **THEN** the user can see placeholders for points, timers, notes, and send queue status

### Requirement: Baseline Widget Test Coverage
The system SHALL include baseline widget tests for the app shell and home screen.

#### Scenario: Home screen test passes
- **WHEN** the widget test suite runs
- **THEN** it verifies that the app renders the expected WristLink home screen content
