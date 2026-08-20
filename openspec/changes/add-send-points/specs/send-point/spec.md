## Purpose

Define how users create, review, and send Garmin point commands from an embedded map or content shared by Google Maps on supported mobile platforms.

## ADDED Requirements

### Requirement: Manual Point Selection
The system SHALL let users create a point on Android and iOS by selecting **Manual point**, positioning a pin on an embedded map, and confirming a valid latitude and longitude.

#### Scenario: User selects a point on the map
- **WHEN** the user opens **Manual point**, moves the map or pin to a valid location, and selects **Use this point**
- **THEN** the system opens point confirmation with the selected coordinates and a manual-map source indication

#### Scenario: Location access is unavailable
- **WHEN** location permission is denied or the current phone location cannot be obtained
- **THEN** the map remains usable for manual pan, zoom, and pin selection without blocking point creation

#### Scenario: User cancels map selection
- **WHEN** the user cancels before accepting the selected pin
- **THEN** the system returns to the Send destination without creating a queue record

### Requirement: Cross-Platform Google Maps Share Reception
The system SHALL accept text or URL content shared to WristLink from Google Maps on Android and iOS and SHALL deliver each share to the point flow whether the containing app was stopped, backgrounded, or already running.

#### Scenario: Android receives a share
- **WHEN** the user chooses WristLink from an Android Google Maps share sheet
- **THEN** WristLink receives the shared text or URL and opens point confirmation after parsing succeeds

#### Scenario: iOS receives a share
- **WHEN** the user chooses WristLink from an iOS Google Maps share sheet
- **THEN** the WristLink share experience stores the shared text or URL and hands it to the containing app for point confirmation

#### Scenario: App cold-starts from a share
- **WHEN** valid shared content launches or is collected by an app process that was not running
- **THEN** the system consumes the pending share exactly once and presents its point confirmation after app initialization

#### Scenario: Running app receives a share
- **WHEN** valid shared content arrives while WristLink is already running or resumes from the background
- **THEN** the system presents a new point confirmation without losing the currently selected primary tab state after the flow is dismissed

#### Scenario: Duplicate platform delivery occurs
- **WHEN** the operating system redelivers the same pending share during app startup or resume
- **THEN** the system presents that pending share no more than once

### Requirement: Shared Point Parsing
The system SHALL preserve the original shared content and parse coordinates and an optional label from supported Google Maps URLs, Google Maps short links, `geo:` URIs, and plain latitude/longitude text.

#### Scenario: Direct Google Maps URL contains coordinates
- **WHEN** shared content includes a supported `google.com/maps` URL with valid coordinates
- **THEN** the system creates a point draft from those coordinates and uses an available place label as the editable default name

#### Scenario: Google Maps short link resolves
- **WHEN** shared content includes a supported `maps.app.goo.gl` or `goo.gl/maps` short link that redirects to a parseable Google Maps URL
- **THEN** the system follows bounded HTTPS redirects and parses the resulting coordinates and available label

#### Scenario: Geo URI is shared
- **WHEN** shared content includes a `geo:` URI with valid coordinates
- **THEN** the system creates a point draft from those coordinates

#### Scenario: Plain coordinates are shared
- **WHEN** shared text contains an unambiguous valid latitude/longitude pair
- **THEN** the system creates a point draft from that coordinate pair

#### Scenario: Parsed coordinates are out of range
- **WHEN** candidate latitude or longitude values fall outside the v1 point contract ranges
- **THEN** the system rejects the candidate and does not create a sendable point draft

#### Scenario: Short-link resolution is unavailable
- **WHEN** a supported short link cannot be resolved because of timeout, connectivity, redirect-limit, or invalid destination
- **THEN** the system shows a recoverable parse error while retaining the original shared content

#### Scenario: Shared content has no coordinates
- **WHEN** no supported representation yields valid coordinates
- **THEN** the system shows **No coordinates found**, retains the original shared content for copying, and offers manual coordinate entry

### Requirement: Point Confirmation
The system SHALL provide a common confirmation screen for manual and shared point drafts where the user can review coordinates, edit a non-empty name, and choose the point intent `navigate` or `save_waypoint` before sending.

#### Scenario: Shared point is reviewed
- **WHEN** parsing produces a point draft
- **THEN** confirmation shows its source, coordinates, editable name, intent selector, and current watch readiness

#### Scenario: User chooses navigation
- **WHEN** the user confirms with **Navigate** selected
- **THEN** the system creates a v1 point payload whose intent is `navigate`

#### Scenario: User chooses waypoint saving
- **WHEN** the user confirms with **Save waypoint** selected
- **THEN** the system creates a v1 point payload whose intent is `save_waypoint`

#### Scenario: User edits the name
- **WHEN** the user changes the point name to a valid non-empty value
- **THEN** the system uses the edited name as the point payload label

#### Scenario: Confirmation input is invalid
- **WHEN** the point has invalid coordinates or the edited name is empty
- **THEN** the system prevents submission and identifies the field that must be corrected

### Requirement: Shared Device Readiness
The point confirmation flow SHALL derive the default watch, reachability, and companion installation readiness from the shared `DeviceDirectory` rather than maintaining screen-local device state.

#### Scenario: Default watch is ready
- **WHEN** the shared directory resolves a reachable default watch with the companion app installed
- **THEN** confirmation identifies the watch as ready and permits an immediate send attempt

#### Scenario: Default watch is offline
- **WHEN** the shared directory resolves a known default watch with the companion app installed but not currently reachable
- **THEN** confirmation permits queueing and explains that delivery will retry when the watch reconnects

#### Scenario: No usable target is configured
- **WHEN** there is no default watch, the stored default is missing, or its companion app is not installed
- **THEN** confirmation prevents submission and presents the corresponding setup action instead of creating an undeliverable queue record

### Requirement: Point Submission Outcome
The system SHALL validate and durably enqueue a contract-compatible point envelope before attempting Garmin transport, then present a status derived from the resulting queue record.

#### Scenario: Ready watch accepts the point
- **WHEN** transport succeeds and the required matching watch acknowledgement is accepted
- **THEN** the system marks the point sent and presents the successful status

#### Scenario: Known watch is offline
- **WHEN** the user submits while the selected default watch is temporarily unreachable
- **THEN** the system retains the point as pending and presents **Point queued** with the selected watch and retry explanation

#### Scenario: Submission fails terminally
- **WHEN** validation, companion availability, unsupported platform, or a non-retryable transport or acknowledgement error prevents delivery
- **THEN** the system marks the record failed and presents a clear reason and available recovery action

#### Scenario: Point exceeds contract budget
- **WHEN** the serialized point envelope exceeds the v1 UTF-8 byte budget
- **THEN** the system does not invoke native Garmin transport and asks the user to shorten editable content

