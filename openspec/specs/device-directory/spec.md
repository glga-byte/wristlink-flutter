## Purpose

Define the shared Garmin device domain and directory behavior used by device-aware WristLink screens and send-target resolution.

## Requirements

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
The system SHALL expose a shared mode-aware device directory service that provides effective devices, refresh behavior, default-device selection, and send-target readiness while delegating physical and emulated behavior to mode-specific directory implementations.

#### Scenario: Screens read active effective devices
- **WHEN** a device-aware screen requests devices
- **THEN** the system provides the current active effective device list from the shared mode-aware directory instead of screen-local sample data or screen-local emulator branches

#### Scenario: User refreshes physical device list
- **WHEN** emulator mode is disabled and the user triggers device discovery or authorization refresh
- **THEN** the system delegates to the physical directory implementation, calls the native discovery gateway, persists authorized physical devices, and updates the shared active effective device list

#### Scenario: User refreshes emulated device list
- **WHEN** emulator mode is enabled and the user triggers a device refresh
- **THEN** the system delegates to the emulated directory implementation, returns the current emulator-backed effective device list, and does not call native Garmin discovery

#### Scenario: Physical native status event arrives
- **WHEN** the native Garmin bridge emits a status update for a known physical device
- **THEN** the physical directory implementation updates the cached physical device state and persists the updated authorized physical device list

#### Scenario: No devices are available
- **WHEN** the active directory implementation produces no effective devices
- **THEN** the system exposes an empty device list with a typed reason that UI can present as an empty state

### Requirement: Default Device Selection
The system SHALL store and resolve the user's physical default Garmin device through the physical directory while exposing the active mode's default device through the shared mode-aware directory.

#### Scenario: User chooses physical default watch
- **WHEN** emulator mode is disabled and the user selects a device on the Default Watch screen
- **THEN** the physical directory persists that physical device as the default watch and marks it as default in shared physical device state

#### Scenario: Emulator mode uses emulator default
- **WHEN** emulator mode is enabled
- **THEN** the shared mode-aware directory exposes the emulator-backed device as the active default without overwriting the persisted physical default watch

#### Scenario: Emulator mode is disabled
- **WHEN** the user disables emulator mode after using the emulator-backed device
- **THEN** the shared mode-aware directory exposes the previously persisted physical default watch if it remains present in the physical effective device list

#### Scenario: Default device disappears
- **WHEN** the persisted physical default device is no longer present in the latest physical effective device list
- **THEN** the system preserves the stored physical selection but does not return it as an immediately sendable target

### Requirement: Send Target Resolution
The system SHALL provide send-target resolution through the shared mode-aware directory by delegating to the active physical or emulated directory implementation.

#### Scenario: Physical default watch is ready
- **WHEN** emulator mode is disabled and the physical default watch is reachable with the companion app installed
- **THEN** the system returns that physical watch as the send target

#### Scenario: Emulator watch is ready
- **WHEN** emulator mode is enabled and the emulator-backed device is reachable with the companion app installed
- **THEN** the system returns the emulator-backed device as the send target

#### Scenario: Active default watch is not ready
- **WHEN** the active default watch is offline or missing the companion app
- **THEN** the system returns a typed unavailable reason for Share Confirm and future queue behavior
