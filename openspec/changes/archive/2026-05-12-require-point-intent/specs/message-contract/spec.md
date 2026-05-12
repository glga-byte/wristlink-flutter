## MODIFIED Requirements

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

## ADDED Requirements

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
