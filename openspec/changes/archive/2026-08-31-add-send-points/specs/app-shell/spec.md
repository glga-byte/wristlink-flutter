## MODIFIED Requirements

### Requirement: Queue Destination Placeholder
The system SHALL provide a Queue destination backed by durable send records rather than static queue progress and command status examples.

#### Scenario: Queue destination renders
- **WHEN** the user opens the Queue destination
- **THEN** the system shows summary counts and persisted point records with pending, sending, sent, and failed outcomes

#### Scenario: Queue destination is empty
- **WHEN** the user opens the Queue destination before any point has been submitted
- **THEN** the system shows an empty queue state without fabricated progress examples

### Requirement: Core Workflow Placeholders
The system SHALL make sharing a place from Maps and manual point selection interactive while continuing to present timers, notes, and commands as future workflow placeholders.

#### Scenario: Workflow placeholders are visible
- **WHEN** the initial Send destination is displayed
- **THEN** the user can start a manual point flow and can see instructions for sharing a place from Google Maps

#### Scenario: Future workflow placeholders remain visible
- **WHEN** the initial Send destination is displayed
- **THEN** the user can still see non-interactive placeholders for timers, notes, and commands
