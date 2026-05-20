## ADDED Requirements

### Requirement: Flavor-Driven Connect IQ App Identifier Configuration
The system SHALL configure the WristLink Connect IQ companion app UUID through Flutter flavors that feed Android and iOS native metadata used by Garmin discovery bridges.

#### Scenario: Dev flavor uses development app identifier
- **WHEN** a developer builds the `dev` Flutter flavor
- **THEN** Android and iOS native metadata use `11111111-1111-1111-1111-111111111111` until that placeholder is replaced with the real development Connect IQ app UUID

#### Scenario: Prod flavor uses production app identifier
- **WHEN** CI builds the `prod` Flutter flavor
- **THEN** Android and iOS native metadata use `22222222-2222-2222-2222-222222222222` until that placeholder is replaced with the real production Connect IQ app UUID
- **AND** production UUID replacement does not require source-file edits outside flavor build configuration

#### Scenario: Flavors install side by side
- **WHEN** the `dev` and `prod` Flutter flavors are installed on the same Android or iOS phone
- **THEN** Android uses `com.wristlink.wristlink_flutter.dev` for `dev` and `com.wristlink.wristlink_flutter` for `prod`
- **AND** iOS uses `com.wristlink.wristlinkFlutter.dev` for `dev` and `com.wristlink.wristlinkFlutter` for `prod`

#### Scenario: Flavor metadata uses one logical key
- **WHEN** Android or iOS app metadata is built for any supported flavor
- **THEN** the platform metadata value used by the native Garmin discovery bridge is populated from `WRISTLINK_CONNECT_IQ_APP_UUID` for that flavor
- **AND** the UUID is owned in one flavor build setting location per platform rather than duplicated in native source, Android manifest literals, or iOS Info.plist literals

#### Scenario: UUID values are treated uniformly
- **WHEN** the native Garmin discovery bridge reads the selected flavor's Connect IQ app UUID
- **THEN** it treats any syntactically valid configured UUID, including committed placeholder UUIDs, as a real Connect IQ app UUID without recognizing a placeholder sentinel value

#### Scenario: iOS callback schemes are flavor specific
- **WHEN** the `dev` and `prod` Flutter flavors are installed on the same iOS phone
- **THEN** `dev` registers and initializes Garmin authorization with `wristlink-ciq-dev`
- **AND** `prod` registers and initializes Garmin authorization with `wristlink-ciq`

#### Scenario: iOS flavor schemes drive build settings
- **WHEN** Flutter builds iOS with `--flavor dev` or `--flavor prod`
- **THEN** the selected Xcode scheme and flavor build configuration provide `PRODUCT_BUNDLE_IDENTIFIER`, `WRISTLINK_CONNECT_IQ_APP_UUID`, and `WRISTLINK_GARMIN_CALLBACK_SCHEME`
