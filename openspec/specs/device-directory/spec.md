## Purpose

Define the shared physical Garmin device domain and directory behavior used by device-aware WristLink screens and send-target resolution.

## Requirements

### Requirement: Shared Device Models
The system SHALL define typed Dart models for physical Garmin devices that are reusable across Devices, Default Watch, Share Confirm, and future sending flows.

#### Scenario: Device model represents physical watch
- **WHEN** a native discovery adapter returns a physical Garmin device
- **THEN** the system represents it with a stable device id, display name, reachability state, companion install state, and default selection state

### Requirement: Centralized Readiness Derivation
The system SHALL derive device readiness from reachability and companion install state in the shared devices domain.

#### Scenario: Device is ready
- **WHEN** a device is reachable and the companion app is installed
- **THEN** the system reports the device as ready for send-target selection

#### Scenario: Device needs setup
- **WHEN** a device is nearby or reachable and the companion app is missing
- **THEN** the system reports the device as needing companion setup

#### Scenario: Device is unavailable
- **WHEN** a device is offline or has no current connection
- **THEN** the system reports the device as unavailable for immediate sending

### Requirement: Device Directory Service
The system SHALL expose a shared local device directory service that provides physical devices, refresh behavior, default-device selection, and send-target readiness.

#### Scenario: Screens read physical devices
- **WHEN** a device-aware screen requests devices
- **THEN** the system provides the current physical device list from the shared local device directory instead of screen-local sample data or screen-local emulator branches

#### Scenario: User refreshes physical device list
- **WHEN** the user triggers device discovery or authorization refresh
- **THEN** the system calls the native discovery gateway, persists authorized physical devices, and updates the shared physical device list

#### Scenario: Physical native status event arrives
- **WHEN** the native Garmin bridge emits a status update for a known physical device
- **THEN** the local device directory updates the cached physical device state and persists the updated authorized physical device list

#### Scenario: No devices are available
- **WHEN** the local device directory produces no physical devices
- **THEN** the system exposes an empty device list with a typed reason that UI can present as an empty state

### Requirement: Default Device Selection
The system SHALL store and resolve the user's physical default Garmin device through the shared local device directory.

#### Scenario: User chooses physical default watch
- **WHEN** the user selects a device on the Default Watch screen
- **THEN** the local device directory persists that physical device as the default watch and marks it as default in shared physical device state

#### Scenario: Default device disappears
- **WHEN** the persisted physical default device is no longer present in the latest physical device list
- **THEN** the system preserves the stored physical selection but does not return it as an immediately sendable target

### Requirement: Send Target Resolution
The system SHALL provide send-target resolution through the shared local device directory using physical device state.

#### Scenario: Physical default watch is ready
- **WHEN** the physical default watch is reachable with the companion app installed
- **THEN** the system returns that physical watch as the send target

#### Scenario: Active default watch is not ready
- **WHEN** the active default watch is offline or missing the companion app
- **THEN** the system returns a typed unavailable reason for Share Confirm and future queue behavior
