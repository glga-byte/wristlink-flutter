## ADDED Requirements

### Requirement: Shared Device Models
The system SHALL define typed Dart models for Garmin devices that are reusable across Devices, Default Watch, Share Confirm, and future sending flows.

#### Scenario: Device model represents physical watch
- **WHEN** a native discovery adapter returns a physical Garmin device
- **THEN** the system represents it with a stable device id, display name, physical source, reachability state, companion install state, and default selection state

#### Scenario: Device model represents emulator watch
- **WHEN** the emulator device is enabled
- **THEN** the system represents it with a stable device id, emulator source, reachability state, companion install state, and default selection state

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
The system SHALL expose a shared device directory service that provides effective devices, refresh behavior, default-device selection, and send-target readiness.

#### Scenario: Screens read effective devices
- **WHEN** a device-aware screen requests devices
- **THEN** the system provides the current effective device list from the shared directory instead of screen-local sample data

#### Scenario: User refreshes device list
- **WHEN** the user triggers device discovery or authorization refresh
- **THEN** the system delegates to the native discovery gateway and updates the shared effective device list

#### Scenario: No devices are available
- **WHEN** native discovery and emulator composition produce no effective devices
- **THEN** the system exposes an empty device list with a typed reason that UI can present as an empty state

### Requirement: Default Device Selection
The system SHALL store and resolve the user's default Garmin device through the shared device directory.

#### Scenario: User chooses default watch
- **WHEN** the user selects a device on the Default Watch screen
- **THEN** the system persists that device as the default watch and marks it as default in shared device state

#### Scenario: Default device disappears
- **WHEN** the persisted default device is no longer present in the latest effective device list
- **THEN** the system preserves the stored selection but does not return it as an immediately sendable target

### Requirement: Send Target Resolution
The system SHALL provide send-target resolution that chooses the default reachable companion-installed device first and otherwise returns a clear unavailable reason.

#### Scenario: Default watch is ready
- **WHEN** the default watch is reachable and the companion app is installed
- **THEN** the system returns that watch as the send target

#### Scenario: Default watch is not ready
- **WHEN** the default watch is offline or missing the companion app
- **THEN** the system returns a typed unavailable reason for Share Confirm and future queue behavior
