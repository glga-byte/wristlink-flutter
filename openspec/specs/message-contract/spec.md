## Purpose

Defines the shared phone-to-watch and watch-to-phone message contract used by
the Flutter app and the separate Connect IQ watch app repository.

## Requirements

### Requirement: Shared Contract Source
The system SHALL treat the `contract/` submodule as the source of truth for WristLink phone-to-watch and watch-to-phone message protocol assets shared with the separate Connect IQ app repository.

#### Scenario: Flutter consumes contract assets
- **WHEN** Flutter payload or send bridge behavior depends on message structure
- **THEN** the implementation uses schemas, examples, or fixtures from `contract/` rather than redefining incompatible local message shapes

#### Scenario: Contract changes are pinned
- **WHEN** the Flutter repo adopts a changed message contract
- **THEN** the parent repository pins the `contract/` submodule revision used for that implementation

### Requirement: Versioned Message Envelope
The system SHALL serialize every phone-to-watch command into a contract-defined envelope containing a protocol version, stable ULID message id, payload kind, creation timestamp, optional expiration metadata, and kind-specific payload data.

#### Scenario: Point message is serialized
- **WHEN** the user sends a point payload
- **THEN** the system serializes a contract-compatible envelope with kind `point` and point-specific data under the payload field, including a required `intent` value of `navigate` or `save_waypoint`

#### Scenario: Timer message is serialized
- **WHEN** the user sends a timer payload
- **THEN** the system serializes a contract-compatible envelope with kind `timer` and timer-specific data under the payload field

#### Scenario: Note message is serialized
- **WHEN** the user sends a note payload
- **THEN** the system serializes a contract-compatible envelope with kind `note` and note-specific data under the payload field

#### Scenario: Command message is serialized
- **WHEN** the user sends a command payload
- **THEN** the system serializes a contract-compatible envelope with kind `command` and command-specific data under the payload field

### Requirement: Contract Payload Size Budget
The system SHALL enforce the shared contract's v1 serialized payload budget before sending phone-to-watch messages through Garmin transport.

#### Scenario: Payload fits budget
- **WHEN** a serialized message envelope is within the v1 contract byte budget
- **THEN** the system allows it to proceed to queueing or native transport validation

#### Scenario: Payload exceeds budget
- **WHEN** a serialized message envelope exceeds the v1 contract byte budget
- **THEN** the system rejects it with a typed payload-too-large domain error before invoking native Garmin transport

#### Scenario: Native reports too large
- **WHEN** native Garmin transport reports that serialized input data is too large
- **THEN** the system maps the platform failure to the same typed payload-too-large domain error

### Requirement: Point Payload Intent
The system SHALL require every v1 point payload to declare an `intent` field that tells the watch how to handle the point.

#### Scenario: Point requests navigation
- **WHEN** a v1 point payload contains `intent` set to `navigate`
- **THEN** the payload is valid when all other point fields satisfy the contract

#### Scenario: Point requests waypoint saving
- **WHEN** a v1 point payload contains `intent` set to `save_waypoint`
- **THEN** the payload is valid when all other point fields satisfy the contract

#### Scenario: Point intent is missing
- **WHEN** a v1 point payload omits `intent`
- **THEN** the system rejects the payload as malformed

#### Scenario: Point intent is unsupported
- **WHEN** a v1 point payload contains an `intent` value other than `navigate` or `save_waypoint`
- **THEN** the system rejects the payload as malformed

### Requirement: Contract Validation
The system SHALL validate Flutter serialization and parsing behavior against shared contract fixtures before relying on a payload shape in send queue or Garmin bridge behavior.

#### Scenario: Valid fixtures round-trip
- **WHEN** a valid contract fixture is loaded by a Flutter test
- **THEN** the system parses it into typed Dart domain models and serializes it back to the same contract-compatible shape

#### Scenario: Invalid fixtures are rejected
- **WHEN** an invalid contract fixture is loaded by a Flutter test
- **THEN** the system rejects it with a typed domain error rather than silently enqueueing or sending it

#### Scenario: Unsupported protocol version is rejected
- **WHEN** a payload uses a protocol version unsupported by the Flutter implementation
- **THEN** the system rejects it with an unsupported-version domain error

### Requirement: Watch Acknowledgement Contract
The system SHALL parse watch-to-phone acknowledgement messages through the shared contract and map acknowledgement outcomes to send queue status decisions for message kinds that require watch-level confirmation.

#### Scenario: Watch accepts message
- **WHEN** acknowledgement is required and the watch returns an acknowledgement for a sent message with an accepted status
- **THEN** the system associates it with the original message id and marks the queued task as sent

#### Scenario: Watch rejects message
- **WHEN** acknowledgement is required and the watch returns an acknowledgement for a sent message with a rejected or unsupported status
- **THEN** the system associates it with the original message id and marks the queued task as failed with a clear domain reason

#### Scenario: Watch requests retry
- **WHEN** acknowledgement is required and the watch returns an acknowledgement for a sent message with a retryable status
- **THEN** the system keeps or restores the queued task to a retryable pending state

#### Scenario: Acknowledgement is not required
- **WHEN** a message kind does not require watch-level acknowledgement and native Garmin transport reports success
- **THEN** the system may mark the queued task as sent without waiting for a watch acknowledgement

### Requirement: Typed Garmin Send Boundary
The system SHALL expose phone-to-watch sending through a typed Dart Garmin send gateway instead of letting UI code call Platform Channels or construct raw contract maps directly.

#### Scenario: UI requests send
- **WHEN** a screen initiates a point, timer, note, or command send
- **THEN** the screen delegates through typed Dart services that construct a validated contract message before native transport is invoked

#### Scenario: Native transport reports failure
- **WHEN** Android or iOS Garmin SDK transport fails to send a validated contract message
- **THEN** the system maps the platform failure to a typed domain error that the send queue can persist

### Requirement: Repository Boundary
The system SHALL keep Connect IQ watch app implementation out of this Flutter repository while preserving enough shared contract tests to maintain compatibility.

#### Scenario: Watch behavior is needed
- **WHEN** implementation requires parsing or handling on the Connect IQ app side
- **THEN** that implementation belongs in the separate Connect IQ repository and uses the same `contract/` assets

#### Scenario: Durable contract knowledge changes
- **WHEN** this change introduces architecture rules, protocol constraints, or verification steps that future agents must follow
- **THEN** the implementation updates `AGENTS.md` as part of the same change
