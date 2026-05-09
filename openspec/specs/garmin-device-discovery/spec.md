## Purpose

Define typed Garmin Connect IQ Mobile SDK discovery behavior and platform adapter outcomes used by the shared device directory.

## Requirements

### Requirement: Typed Garmin Discovery Gateway
The system SHALL wrap platform Garmin Connect IQ Mobile SDK behavior in a typed Dart gateway rather than exposing raw Platform Channel payloads to UI code.

#### Scenario: Discovery gateway returns devices
- **WHEN** a platform adapter reports Garmin devices
- **THEN** the gateway maps them into shared Dart device models and domain states

#### Scenario: Discovery gateway reports error
- **WHEN** a platform adapter cannot complete discovery
- **THEN** the gateway returns a typed domain error such as SDK unavailable, Garmin Connect missing, authorization cancelled, no authorized devices, timeout, or unsupported platform

### Requirement: Native Garmin Bridge Boundaries
The system SHALL keep native Garmin discovery bridge responsibilities in focused adapter, mapping, event, and settings components rather than concentrating them in platform app entry files.

#### Scenario: Native app entry registers bridge components
- **WHEN** Android or iOS app startup configures Flutter platform channels
- **THEN** app entry code delegates Garmin discovery, Garmin device events, and device settings handling to focused native bridge components

#### Scenario: Native mapping is tested independently
- **WHEN** native Garmin status or payload mapping behavior changes
- **THEN** the system verifies the mapping through native unit tests without requiring a live Garmin SDK session

### Requirement: Android SDK Device Discovery
The system SHALL provide an Android native adapter for Garmin Connect IQ Mobile SDK device discovery, status, companion app install state, and normalized Garmin device payloads.

#### Scenario: Android adapter lists devices
- **WHEN** Android Garmin SDK discovery succeeds
- **THEN** the system returns physical Garmin devices with stable ids, display names, reachability state, companion install state, and normalized metadata fields shared with iOS

#### Scenario: Android adapter maps bridge failure
- **WHEN** Android Garmin SDK discovery or status lookup fails
- **THEN** the system maps the failure to a clear domain error without leaking native exception details to UI code

#### Scenario: Android adapter serializes SDK callbacks
- **WHEN** Android Garmin SDK callbacks resolve companion state, status events, initialization, or timeout completion
- **THEN** the system mutates bridge state and completes Flutter method or event results from the main thread through an idempotent completion path

### Requirement: iOS SDK Device Authorization
The system SHALL provide an iOS native adapter for Garmin Connect IQ Mobile SDK device selection, authorization through Garmin Connect Mobile handoff and callback, status events, companion state, and normalized Garmin device payloads.

#### Scenario: iOS starts device authorization
- **WHEN** the user refreshes devices on iOS and Garmin Connect Mobile is available
- **THEN** the system opens Garmin Connect Mobile device selection through the Garmin iOS SDK

#### Scenario: iOS receives device selection callback
- **WHEN** Garmin Connect Mobile returns selected Connect IQ-compatible devices to the app callback URL
- **THEN** the system parses the returned devices and updates the shared device directory with the latest authorized list using normalized metadata fields shared with Android

#### Scenario: iOS authorization is cancelled
- **WHEN** the user cancels or Garmin Connect Mobile returns no devices
- **THEN** the system keeps the previous authorized device cache and reports an authorization cancelled or no authorized devices result

#### Scenario: iOS adapter serializes SDK callbacks
- **WHEN** iOS Garmin SDK callbacks resolve companion state, status events, authorization callback, or timeout completion
- **THEN** the system mutates bridge state and completes Flutter method or event results from the main queue through an idempotent completion path

### Requirement: Authorized Device Cache
The system SHALL persist only the latest authorized native device list and normalized metadata needed by the Dart device directory.

#### Scenario: Latest authorization replaces cache
- **WHEN** a native adapter returns a new authorized device list
- **THEN** the system replaces previously cached native devices with the latest authorized devices

#### Scenario: App restarts after authorization
- **WHEN** the app restarts after devices were authorized
- **THEN** the system restores normalized cached devices for display until the user refreshes or native status updates arrive

### Requirement: Native Status and Companion Mapping
The system SHALL map native SDK device connection status, Connect IQ app install status, and Garmin device metadata into shared reachability, companion install, and payload fields consistently across Android and iOS.

#### Scenario: Device status changes
- **WHEN** a native SDK reports a device connection status change
- **THEN** the system updates the shared device directory with the mapped reachability state using the same normalized vocabulary on Android and iOS

#### Scenario: Companion app status is checked
- **WHEN** the app requests the WristLink Connect IQ app status for a device
- **THEN** the system maps the native app status to installed, missing, or unknown companion state

#### Scenario: Native payload metadata is emitted
- **WHEN** Android or iOS native discovery returns a Garmin device or emits a status event
- **THEN** the payload includes equivalent `id`, `name`, `modelName`, `family`, `unitId`, `reachability`, and `companionInstallState` fields where the Garmin SDK provides those values

### Requirement: Platform Unsupported Behavior
The system SHALL handle platforms without a Garmin discovery adapter without crashing.

#### Scenario: Unsupported platform requests discovery
- **WHEN** the device directory refreshes on a platform without a native Garmin adapter
- **THEN** the system returns an unsupported platform domain error that UI can present or ignore
