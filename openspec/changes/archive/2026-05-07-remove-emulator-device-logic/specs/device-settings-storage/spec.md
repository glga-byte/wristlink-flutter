## MODIFIED Requirements

### Requirement: Explicit Platform Settings Store
The system SHALL choose a `DeviceSettingsStore` implementation explicitly for each supported runtime instead of relying on missing platform-channel behavior.

#### Scenario: Mobile app uses native settings channel
- **WHEN** the app runs on iOS or Android
- **THEN** the system uses the `wristlink/device_settings` method-channel-backed store for default watch and authorized physical devices

#### Scenario: Web app uses browser settings storage
- **WHEN** the app runs on web
- **THEN** the system uses a web-backed store that persists default watch and authorized physical devices in durable browser storage

#### Scenario: Unsupported desktop platforms are out of scope
- **WHEN** the app runs on Windows or Linux before platform support is added
- **THEN** the system does not silently use volatile fallback storage for device settings

### Requirement: Consistent Device Settings Payloads
The system SHALL keep device settings payload mapping in Dart and store platform values as simple strings.

#### Scenario: Authorized devices are persisted
- **WHEN** the system stores authorized Garmin devices on iOS, Android, or web
- **THEN** the system writes the normalized authorized-device JSON string under the shared authorized devices key

#### Scenario: Default watch is persisted
- **WHEN** the system stores a default watch on iOS, Android, or web
- **THEN** the system writes the default device id string under the shared default device key

## REMOVED Requirements

### Requirement: Emulator Settings Storage
**Reason**: Emulator settings are no longer part of the app behavior or device settings contract.
**Migration**: Stop reading and writing the emulator settings key from Dart. Existing persisted emulator settings values may remain in platform storage and are ignored.
