## MODIFIED Requirements

### Requirement: Devices Tab Uses Device Directory
The system SHALL render the Devices primary tab from the shared device directory rather than static screen-local data.

#### Scenario: Devices tab opens with effective devices
- **WHEN** the user opens the Devices tab and the device directory has physical devices
- **THEN** the system displays those physical devices with names, readiness details, and status labels derived from shared device state

#### Scenario: Devices tab opens with no devices
- **WHEN** the user opens the Devices tab and the device directory has no physical devices
- **THEN** the system displays a clear empty state and a way to refresh or authorize Garmin devices

### Requirement: Device Readiness Rows
The system SHALL show secondary physical device rows for non-featured devices using readiness states consistent with the paper Devices design.

#### Scenario: Nearby device needs setup
- **WHEN** a non-default physical device is nearby or reachable but the companion app is missing
- **THEN** the system shows the device with setup status and companion-missing detail

#### Scenario: Device is offline
- **WHEN** a physical device is offline
- **THEN** the system shows the device with offline status and last-seen detail when available
