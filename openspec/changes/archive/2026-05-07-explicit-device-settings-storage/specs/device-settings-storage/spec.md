## ADDED Requirements

### Requirement: Explicit Platform Settings Store
The system SHALL choose a `DeviceSettingsStore` implementation explicitly for each supported runtime instead of relying on missing platform-channel behavior.

#### Scenario: Mobile app uses native settings channel
- **WHEN** the app runs on iOS or Android
- **THEN** the system uses the `wristlink/device_settings` method-channel-backed store for default watch, authorized devices, and emulator settings

#### Scenario: Web app uses browser settings storage
- **WHEN** the app runs on web
- **THEN** the system uses a web-backed store that persists default watch, authorized devices, and emulator settings in durable browser storage

#### Scenario: Unsupported desktop platforms are out of scope
- **WHEN** the app runs on Windows or Linux before platform support is added
- **THEN** the system does not silently use volatile fallback storage for device settings

### Requirement: Mobile Settings Channel Failure Visibility
The system SHALL treat missing or failing iOS and Android device settings channels as integration errors instead of falling back to in-memory settings.

#### Scenario: Mobile settings channel is missing
- **WHEN** the iOS or Android method-channel store reads or writes settings and the `wristlink/device_settings` handler is not registered
- **THEN** the system surfaces the channel failure instead of storing values in memory

#### Scenario: Mobile settings channel returns platform error
- **WHEN** the iOS or Android method-channel store receives a platform error while reading or writing settings
- **THEN** the system surfaces the platform error instead of storing values in memory

### Requirement: Consistent Device Settings Payloads
The system SHALL keep device settings payload mapping in Dart and store platform values as simple strings.

#### Scenario: Authorized devices are persisted
- **WHEN** the system stores authorized Garmin devices on iOS, Android, or web
- **THEN** the system writes the normalized authorized-device JSON string under the shared authorized devices key

#### Scenario: Emulator settings are persisted
- **WHEN** the system stores emulator settings on iOS, Android, or web
- **THEN** the system writes the normalized emulator settings JSON string under the shared emulator settings key

#### Scenario: Default watch is persisted
- **WHEN** the system stores a default watch on iOS, Android, or web
- **THEN** the system writes the default device id string under the shared default device key

### Requirement: Explicit Test Storage
The system SHALL require tests to provide deterministic settings storage directly or mock the exact storage transport under test.

#### Scenario: Widget test needs device settings
- **WHEN** a widget test exercises app behavior that depends on device settings
- **THEN** the test injects an in-memory or fake settings store instead of relying on missing-channel fallback

#### Scenario: Method-channel adapter test needs native behavior
- **WHEN** a test exercises the iOS or Android method-channel settings adapter
- **THEN** the test mocks the `wristlink/device_settings` channel and verifies success or surfaced failure explicitly
