## ADDED Requirements

### Requirement: Typed Garmin Discovery Gateway
The system SHALL wrap platform Garmin Connect IQ Mobile SDK behavior in a typed Dart gateway rather than exposing raw Platform Channel payloads to UI code.

#### Scenario: Discovery gateway returns devices
- **WHEN** a platform adapter reports Garmin devices
- **THEN** the gateway maps them into shared Dart device models and domain states

#### Scenario: Discovery gateway reports error
- **WHEN** a platform adapter cannot complete discovery
- **THEN** the gateway returns a typed domain error such as SDK unavailable, Garmin Connect missing, authorization cancelled, no authorized devices, timeout, or unsupported platform

### Requirement: Android SDK Device Discovery
The system SHALL provide an Android native adapter for Garmin Connect IQ Mobile SDK device discovery, status, and companion app install state.

#### Scenario: Android adapter lists devices
- **WHEN** Android Garmin SDK discovery succeeds
- **THEN** the system returns physical Garmin devices with stable ids, display names, reachability state, and companion install state

#### Scenario: Android adapter maps bridge failure
- **WHEN** Android Garmin SDK discovery or status lookup fails
- **THEN** the system maps the failure to a clear domain error without leaking native exception details to UI code

### Requirement: iOS SDK Device Authorization
The system SHALL provide an iOS native adapter for Garmin Connect IQ Mobile SDK device selection and authorization through Garmin Connect Mobile handoff and callback.

#### Scenario: iOS starts device authorization
- **WHEN** the user refreshes devices on iOS and Garmin Connect Mobile is available
- **THEN** the system opens Garmin Connect Mobile device selection through the Garmin iOS SDK

#### Scenario: iOS receives device selection callback
- **WHEN** Garmin Connect Mobile returns selected Connect IQ-compatible devices to the app callback URL
- **THEN** the system parses the returned devices and updates the shared device directory with the latest authorized list

#### Scenario: iOS authorization is cancelled
- **WHEN** the user cancels or Garmin Connect Mobile returns no devices
- **THEN** the system keeps the previous authorized device cache and reports an authorization cancelled or no authorized devices result

### Requirement: Authorized Device Cache
The system SHALL persist only the latest authorized native device list and normalized metadata needed by the Dart device directory.

#### Scenario: Latest authorization replaces cache
- **WHEN** a native adapter returns a new authorized device list
- **THEN** the system replaces previously cached native devices with the latest authorized devices

#### Scenario: App restarts after authorization
- **WHEN** the app restarts after devices were authorized
- **THEN** the system restores normalized cached devices for display until the user refreshes or native status updates arrive

### Requirement: Native Status and Companion Mapping
The system SHALL map native SDK device connection status and Connect IQ app install status into shared reachability and companion install states.

#### Scenario: Device status changes
- **WHEN** a native SDK reports a device connection status change
- **THEN** the system updates the shared device directory with the mapped reachability state

#### Scenario: Companion app status is checked
- **WHEN** the app requests the WristLink Connect IQ app status for a device
- **THEN** the system maps the native app status to installed, missing, or unknown companion state

### Requirement: Platform Unsupported Behavior
The system SHALL handle platforms without a Garmin discovery adapter without crashing.

#### Scenario: Unsupported platform requests discovery
- **WHEN** the device directory refreshes on a platform without a native Garmin adapter
- **THEN** the system returns an unsupported platform domain error that UI can present or ignore
