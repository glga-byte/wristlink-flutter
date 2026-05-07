## Purpose

Define the Devices tab behavior for presenting Garmin watch readiness from the shared device directory.

## Requirements

### Requirement: Devices Tab Uses Device Directory
The system SHALL render the Devices primary tab from the shared device directory rather than static screen-local data.

#### Scenario: Devices tab opens with effective devices
- **WHEN** the user opens the Devices tab and the device directory has effective devices
- **THEN** the system displays those devices with names, readiness details, and status labels derived from shared device state

#### Scenario: Devices tab opens with no devices
- **WHEN** the user opens the Devices tab and the device directory has no effective devices
- **THEN** the system displays a clear empty state and a way to refresh or authorize Garmin devices

### Requirement: Default Device Emphasis
The system SHALL visually emphasize the default ready device in the Devices tab as the primary send target.

#### Scenario: Default ready device is available
- **WHEN** the default device is reachable and the companion app is installed
- **THEN** the system presents it as the featured connected/default watch in the Devices tab

#### Scenario: Default device is not ready
- **WHEN** the default device is offline or missing the companion app
- **THEN** the system does not present it as ready for immediate sending and shows the relevant setup or offline state

### Requirement: Device Readiness Rows
The system SHALL show secondary device rows for non-featured devices using readiness states consistent with the paper Devices design.

#### Scenario: Nearby device needs setup
- **WHEN** a non-default device is nearby or reachable but the companion app is missing
- **THEN** the system shows the device with setup status and companion-missing detail

#### Scenario: Device is offline
- **WHEN** a device is offline
- **THEN** the system shows the device with offline status and last-seen detail when available

### Requirement: Before Sending Guidance
The system SHALL show before-sending guidance on the Devices tab.

#### Scenario: Devices tab renders guidance
- **WHEN** the Devices tab is displayed
- **THEN** the system tells the user to check companion install per device and use the default reachable watch first

### Requirement: Device Refresh Entry Point
The system SHALL provide a Devices-screen path to refresh physical Garmin devices through the shared device directory.

#### Scenario: User refreshes devices
- **WHEN** the user requests a device refresh from the Devices tab
- **THEN** the system starts platform discovery or authorization through the shared device directory

#### Scenario: Refresh fails
- **WHEN** platform discovery fails or is cancelled
- **THEN** the system keeps the previous effective device list and exposes the failure as user-presentable state
