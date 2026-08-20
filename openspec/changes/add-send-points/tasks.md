## 1. Dependencies and Mobile Configuration

- [ ] 1.1 Add and pin the Flutter dependencies for Google Maps, location access, streamed HTTP redirect resolution, SQLite/path access, and WorkManager/BackgroundTasks; verify their Android and iOS platform baselines before committing the lockfile.
- [ ] 1.2 Add documented dev/prod Google Maps API-key inputs, Android manifest placeholder wiring, iOS SDK initialization wiring, missing-key build diagnostics, and an example configuration without committing unrestricted credentials.
- [ ] 1.3 Raise every iOS app, test, and future extension configuration from iOS 13 to iOS 14, add location usage descriptions, and verify Android location permissions and resolved minimum SDK requirements.
- [ ] 1.4 Extend flavor-configuration tests to assert dev/prod map-key wiring, iOS deployment targets, bundle identifiers, callback schemes, and the absence of duplicated literal configuration in platform code.

## 2. Point Drafts and Shared-Content Parsing

- [ ] 2.1 Add explicit point-draft, source, parse-result, and parse-error domain types under a new `lib/features/send_point/` feature without mixing them with contract payload models.
- [ ] 2.2 Implement pure Dart parsing for `geo:` URIs, supported direct Google Maps URL path/query/`@lat,lon` forms, plain coordinate pairs, coordinate range validation, and editable label extraction.
- [ ] 2.3 Implement the allowlisted Google Maps short-link resolver with HTTPS-only bounded redirects, destination validation, streamed responses, timeouts, and typed connectivity/redirect errors.
- [ ] 2.4 Add redacted parsing fixtures and unit tests for every supported direct/short URL form, encoded labels, locale-independent numbers, ambiguous text, invalid ranges, unsupported URLs, redirect loops, timeouts, and no-coordinate recovery.
- [ ] 2.5 Add point-draft-to-`PointPayload`/`MessageEnvelope` mapping with Navigate/Save waypoint intent, stable ULID creation, editable label validation, and the existing v1 serialized-byte-budget error path.

## 3. Typed Share Ingress and Android Reception

- [ ] 3.1 Define `SharedContentGateway`, `SharedContentRecord`, pending-drain, live-event, acknowledgement, and unsupported-platform APIs with bounded raw-content handling and fake implementations for tests.
- [ ] 3.2 Add the Android share-ingress adapter that persists raw records before delivery, exposes pending/live records over typed channels, acknowledges consumed ids, suppresses recent duplicates, and performs no coordinate parsing.
- [ ] 3.3 Register a `text/plain` `ACTION_SEND` target and route both initial intents and `onNewIntent` through the adapter while preserving normal launcher behavior and clearing handled intent state.
- [ ] 3.4 Add Android unit/instrumentation coverage for valid and malformed extras, cold and warm intents, persistence before Flutter readiness, acknowledgement cleanup, duplicate delivery, size limits, and non-share launches.

## 4. iOS Share Extension and Handoff

- [ ] 4.1 Add dev/prod App Group ids, share callback schemes, extension bundle ids, entitlements, build configurations, and schemes so each Share Extension matches its containing app flavor and can be installed side by side.
- [ ] 4.2 Implement a pure Swift Share Extension for public URLs and plain text that bounds input, writes an atomic per-record JSON file to the App Group, requests containing-app handoff, and completes with a usable fallback when foregrounding is denied.
- [ ] 4.3 Add the iOS app-side ingress adapter that drains and acknowledges App Group records, emits live records after callback/resume, suppresses duplicates, and keeps parsing out of native code.
- [ ] 4.4 Route share callback URLs through AppDelegate/SceneDelegate without interfering with Garmin callbacks, and add native tests for record encoding, atomic drain/acknowledgement, malformed files, callback routing, and dev/prod configuration.

## 5. Durable Queue Storage

- [ ] 5.1 Extend `SendQueueRecord` with typed failure metadata, attempt count, next-attempt time, and acknowledgement deadline while retaining pending, sending, sent, and failed as the only stored statuses.
- [ ] 5.2 Define the `SendQueueRepository` contract for transactional enqueue, ordered reads, atomic pending claims, guarded transitions, acknowledgement lookup, retry scheduling, and explicit retry.
- [ ] 5.3 Implement SQLite schema version 1 with a unique message id, normalized envelope JSON, physical device id, timestamps, retry/acknowledgement fields, transactions, migrations, and an explicit unsupported-platform provider.
- [ ] 5.4 Implement an app-scoped queue controller that restores immutable snapshots, publishes persisted transitions, maps pending-offline to the UI label **queued**, and surfaces storage failures without attempting transport.
- [ ] 5.5 Add repository/controller tests for round trips, process restoration, concurrent claims, unique ids, transition guards, corrupted rows, migration rollback, persistence failures, sorting, and unsupported platforms.

## 6. Garmin Send and Acknowledgement Transport

- [ ] 6.1 Add a typed Dart acknowledgement gateway over `wristlink/garmin_acknowledgements` that validates raw maps through `WatchAcknowledgement` and exposes malformed events as diagnostics rather than queue mutations.
- [ ] 6.2 Extend the Android Garmin transport owner to send normalized maps to a discovered physical device/app, emit raw acknowledgement app messages, share idempotent SDK/device registration across engines, and map all documented SDK/too-large outcomes to existing error codes.
- [ ] 6.3 Extend the iOS Garmin transport owner with equivalent normalized send, app-message acknowledgement, lifecycle-safe registration, device/app lookup, main-queue completion, and typed transport-error mapping.
- [ ] 6.4 Add Dart, Kotlin, and Swift tests for send argument validation, device/app lookup, success completion, every mapped failure, too-large mapping, raw acknowledgement delivery, duplicate callbacks, timeout, and exactly-once completion.

## 7. Delivery Coordination and Background Retry

- [ ] 7.1 Implement the Dart delivery coordinator that resolves stored targets through shared device state, atomically claims pending records, invokes Garmin transport, waits for required acknowledgements, and persists every outcome.
- [ ] 7.2 Implement transient/terminal error classification, capped exponential backoff, acknowledgement deadlines, idempotent accepted/rejected/retryable handling, unknown/late acknowledgement diagnostics, and unknown-delivery recovery for interrupted sends.
- [ ] 7.3 Wire immediate submission, app startup/foreground, relevant `DeviceDirectory` readiness changes, and explicit retry to the same mutually exclusive queue-drain path.
- [ ] 7.4 Implement `BackgroundSendScheduler` with WorkManager/BackgroundTasks registration, constraints, unique work, cancellation when no retryable work remains, and platform scheduling errors mapped without losing pending records.
- [ ] 7.5 Add the top-level background Dart entrypoint and minimal headless composition for SQLite queue storage, persisted device settings, Garmin transport/acknowledgements, and the coordinator; register native bridges idempotently for foreground and background engines.
- [ ] 7.6 Add deterministic coordinator/background tests for ready/offline/missing-companion targets, transport and acknowledgement outcomes, backoff, overlapping triggers, process interruption, platform deadline/cancellation, and foreground fallback when background execution is delayed.

## 8. Manual Picker, Confirmation, and Recovery UI

- [ ] 8.1 Move long-lived device, share, queue, Garmin, parsing, and background services into one app-scoped composition and add a root point-flow coordinator that waits for initialization while preserving selected-tab state.
- [ ] 8.2 Implement the Android/iOS Google Maps manual picker from the Paper snapshot with camera-center pin selection, pan/zoom/tap behavior, optional current-location permission, coordinate sheet, cancel, and **Use this point** actions.
- [ ] 8.3 Implement the shared point confirmation screen with source, coordinates, editable non-empty name, Navigate/Save waypoint control, live `DeviceDirectory` readiness, setup actions, and immediate-send versus offline-queue messaging.
- [ ] 8.4 Implement the no-coordinate/short-link error state with bounded original text display, copy action, manual latitude/longitude entry, validation, retry, and transition into the same confirmation flow.
- [ ] 8.5 Implement queue-backed pending/sending/sent/failed point status screens, including the Paper **Point queued** explanation and typed terminal/retry recovery actions.
- [ ] 8.6 Connect the Send home share instructions and **Manual point** action while leaving timer, note, and command rows inert, and replace the static Queue destination with queue summaries, persisted point rows, and an empty state.
- [ ] 8.7 Add widget tests with fake map/share/queue/Garmin services for manual selection, both intents, editing, readiness variants, invalid fields, payload-too-large, parse recovery, copy/manual entry, status changes, Queue rendering, navigation restoration, semantics, large text, and platform-adaptive controls.

## 9. End-to-End and Platform Verification

- [ ] 9.1 Add integration scenarios for manual map point → confirmation → Navigate/Save waypoint envelope → ready send/accepted acknowledgement and offline durable queue → later reconnect/retry.
- [ ] 9.2 Verify Android Google Maps sharing on cold start, warm `singleTop` delivery, duplicate redelivery, malformed/non-coordinate text, and short-link connectivity failure for both dev and prod flavors.
- [ ] 9.3 Verify iOS Google Maps sharing through both dev and prod Share Extensions, including stopped/running app handoff, App Group fallback when foregrounding is denied, callback coexistence with Garmin discovery, and exactly-once consumption.
- [ ] 9.4 Verify queue restoration across process/device restart, background work on both platforms when granted, foreground fallback, acknowledgement timeout, explicit retry after unknown delivery, and concurrent trigger exclusion.

## 10. Project Knowledge and Final Checks

- [ ] 10.1 Update `AGENTS.md` with durable share-ingress ownership, dev/prod App Group and callback identifiers, map-key restrictions, iOS 14 baseline, queue transaction/state-machine rules, acknowledgement channel ownership, and background-engine verification requirements.
- [ ] 10.2 Run `dart format .`, `flutter analyze`, `flutter test`, and `flutter test test/features/payloads`.
- [ ] 10.3 With Android Studio's supported JDK, run Android dev/prod native unit tests and `flutter build apk --debug --flavor dev` plus `flutter build apk --debug --flavor prod`.
- [ ] 10.4 Run iOS native tests and `flutter build ios --no-codesign --flavor dev` plus `flutter build ios --no-codesign --flavor prod`, confirming the matching Share Extension is embedded once in each build.
- [ ] 10.5 Run `openspec validate add-send-points --strict`, review the final diff for unintended contract-submodule or Paper snapshot changes, and document that the existing contract revision `0324a3dcaaba9d580723a7e845b312084c6c2343` remains adopted.
