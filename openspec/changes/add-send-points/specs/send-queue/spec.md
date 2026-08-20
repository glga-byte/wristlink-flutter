## Purpose

Define durable storage, delivery state transitions, acknowledgement handling, retry behavior, and queue presentation for WristLink point commands.

## ADDED Requirements

### Requirement: Durable Send Queue
The system SHALL persist every submitted point envelope, selected physical device id, timestamps, status, and failure information so queue state survives app and device restarts.

#### Scenario: Point is submitted
- **WHEN** a valid point is submitted for a configured physical watch
- **THEN** the system persists it as pending before attempting native transport

#### Scenario: App restarts with queued records
- **WHEN** WristLink starts after one or more records were persisted
- **THEN** the system restores the records with the same message ids, target device ids, payloads, timestamps, and recoverable states

#### Scenario: Persistence fails
- **WHEN** the queue cannot durably store a point
- **THEN** the system does not invoke Garmin transport and reports that the point was not queued

### Requirement: Explicit Queue State Machine
The system SHALL maintain each queue record in exactly one of the explicit domain statuses pending, sending, sent, or failed and SHALL persist every transition before publishing it to the UI.

#### Scenario: Transport attempt begins
- **WHEN** a pending point is selected for an immediate or background attempt
- **THEN** the system atomically transitions it to sending before invoking transport

#### Scenario: Point requires acknowledgement
- **WHEN** Garmin transport accepts a point message that requires acknowledgement
- **THEN** the record remains sending until a matching watch acknowledgement or timeout outcome is processed

#### Scenario: Watch accepts point
- **WHEN** a matching accepted acknowledgement arrives
- **THEN** the system transitions the record to sent and clears its failure information

#### Scenario: Watch rejects point
- **WHEN** a matching rejected or unsupported acknowledgement arrives
- **THEN** the system transitions the record to failed with the mapped reason

#### Scenario: Watch asks for retry
- **WHEN** a matching retryable acknowledgement arrives
- **THEN** the system transitions the record to pending with its retry reason preserved

#### Scenario: Process stops while sending
- **WHEN** the app later restores a record left in sending and no matching acknowledgement arrives within a bounded recovery period
- **THEN** the system marks it failed with an unknown-delivery outcome and requires explicit retry using the same message id rather than automatically risking duplicate point handling

### Requirement: Retry Classification
The system SHALL retry only pending records whose failures are transient and SHALL keep contract validation, missing companion app, rejected, unsupported, and other terminal errors failed until explicit user action.

#### Scenario: Target is temporarily unreachable
- **WHEN** delivery cannot start because the record's known target watch is offline
- **THEN** the system keeps the record pending and schedules a later attempt

#### Scenario: Garmin transport has a transient failure
- **WHEN** the SDK is temporarily unavailable, transport times out, or the device disconnects during an attempt
- **THEN** the system returns the record to pending with a retry reason and schedules bounded backoff

#### Scenario: Error is terminal
- **WHEN** the payload is invalid or too large, the companion app is missing, the platform is unsupported, or the watch rejects the point
- **THEN** the system marks the record failed and does not automatically retry it

#### Scenario: User retries a recoverable failure
- **WHEN** the user explicitly retries a failed record after correcting the cause
- **THEN** the system transitions it to pending and starts or schedules a new attempt without changing its message id

### Requirement: Retry Triggers and Mutual Exclusion
The system SHALL attempt eligible pending records on submission, app startup or foregrounding, relevant device readiness changes, and platform-granted background work while preventing concurrent attempts for the same record.

#### Scenario: Device becomes ready
- **WHEN** the shared device directory reports that a pending record's target watch became reachable and its companion app is installed
- **THEN** the queue starts one delivery attempt for that record

#### Scenario: Background execution is granted
- **WHEN** the operating system runs scheduled background work
- **THEN** the system loads durable state, attempts eligible pending records, persists outcomes, and requests more work only while retryable records remain

#### Scenario: Background execution is delayed
- **WHEN** the operating system postpones or denies scheduled background work
- **THEN** pending records remain durable and are reconsidered at the next startup, foreground, device-readiness, or background trigger

#### Scenario: Triggers overlap
- **WHEN** multiple retry triggers occur for the same record
- **THEN** at most one transport attempt for that record runs at a time

### Requirement: Acknowledgement Correlation
The system SHALL correlate watch acknowledgements by original message id and SHALL ignore or record diagnostics for acknowledgements that cannot validly transition a queue record.

#### Scenario: Matching acknowledgement arrives
- **WHEN** an acknowledgement references a known sending point message
- **THEN** the system applies the contract-defined status transition to that record

#### Scenario: Unknown or mismatched acknowledgement arrives
- **WHEN** an acknowledgement references no known record or cannot validly apply to the referenced record
- **THEN** the system leaves all queue records unchanged and records a diagnostic without failing an unrelated send

#### Scenario: Duplicate acknowledgement arrives
- **WHEN** an acknowledgement repeats an outcome already applied to a record
- **THEN** the system treats it idempotently and does not regress the record's state

### Requirement: Queue-Backed Presentation
The Queue destination and point status screens SHALL render persisted queue records rather than screen-local examples, using user-facing labels that map consistently to the four domain statuses.

#### Scenario: User opens Queue
- **WHEN** persisted point records exist
- **THEN** the Queue destination displays their point names, target or failure detail, updated order, and current pending, sending, sent, or failed state

#### Scenario: Pending point is shown as queued
- **WHEN** a point remains pending because its watch is temporarily unreachable
- **THEN** point-flow UI may label it **queued** while retaining pending as the persisted domain status

#### Scenario: Queue is empty
- **WHEN** no persisted records exist
- **THEN** the Queue destination displays an empty state instead of sample commands
