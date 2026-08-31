## 1. Dependencies and Mobile Configuration

- [x] 1.1 Add and pin the Flutter dependencies for Google Maps, location access, streamed HTTP redirect resolution, SQLite/path access, and WorkManager/BackgroundTasks; verify their Android and iOS platform baselines before committing the lockfile.
- [x] 1.2 Add documented dev/prod Google Maps API-key inputs, Android manifest placeholder wiring, iOS SDK initialization wiring, missing-key build diagnostics, and an example configuration without committing unrestricted credentials.
- [x] 1.3 Raise every iOS app, test, and future extension configuration from iOS 13 to iOS 14, add location usage descriptions, and verify Android location permissions and resolved minimum SDK requirements.
- [x] 1.4 Extend flavor-configuration tests to assert dev/prod map-key wiring, iOS deployment targets, bundle identifiers, callback schemes, and the absence of duplicated literal configuration in platform code.

## 2. Point Drafts and Shared-Content Parsing

- [x] 2.1 Add explicit point-draft, source, parse-result, and parse-error domain types under a new `lib/features/send_point/` feature without mixing them with contract payload models.
- [x] 2.2 Implement pure Dart parsing for `geo:` URIs, supported direct Google Maps URL path/query/`@lat,lon` forms, plain coordinate pairs, coordinate range validation, and editable label extraction.
- [x] 2.3 Implement the allowlisted Google Maps short-link resolver with HTTPS-only bounded redirects, destination validation, streamed responses, timeouts, and typed connectivity/redirect errors.
- [x] 2.4 Add redacted parsing fixtures and unit tests for every supported direct/short URL form, encoded labels, locale-independent numbers, ambiguous text, invalid ranges, unsupported URLs, redirect loops, timeouts, and no-coordinate recovery.
- [x] 2.5 Add point-draft-to-`PointPayload`/`MessageEnvelope` mapping with Navigate/Save waypoint intent, stable ULID creation, editable label validation, and the existing v1 serialized-byte-budget error path.
- [x] 2.6 Parse the observed Google Maps selected-place `!3d<latitude>!4d<longitude>` data representation without guessing among distinct pairs, and add redacted direct/short-link regression fixtures for valid, malformed, ambiguous, and out-of-range cases.
- [x] 2.7 Stop percent-decoding already-decoded Google Maps path/query labels, preserve Unicode and literal percent characters, and cover address-only short-link destinations so they return the typed no-coordinate recovery result instead of an uncaught URI exception.

## 3. Typed Share Ingress and Android Reception

- [x] 3.1 Define `SharedContentGateway`, `SharedContentRecord`, pending-drain, live-event, acknowledgement, and unsupported-platform APIs with bounded raw-content handling and fake implementations for tests.
- [x] 3.2 Add the Android share-ingress adapter that persists raw records before delivery, exposes pending/live records over typed channels, acknowledges consumed ids, suppresses recent duplicates, and performs no coordinate parsing.
- [x] 3.3 Register a `text/plain` `ACTION_SEND` target and route both initial intents and `onNewIntent` through the adapter while preserving normal launcher behavior and clearing handled intent state.
- [x] 3.4 Add Android unit/instrumentation coverage for valid and malformed extras, cold and warm intents, persistence before Flutter readiness, acknowledgement cleanup, duplicate delivery, size limits, and non-share launches.

## 4. iOS Share Extension and Handoff

- [x] 4.1 Add dev/prod App Group ids, share callback schemes, extension bundle ids, entitlements, build configurations, and schemes so each Share Extension matches its containing app flavor and can be installed side by side.
- [x] 4.2 Implement a pure Swift Share Extension for public URLs and plain text that bounds input, writes an atomic per-record JSON file to the App Group, requests containing-app handoff, and completes with a usable fallback when foregrounding is denied.
- [x] 4.3 Add the iOS app-side ingress adapter that drains and acknowledges App Group records, emits live records after callback/resume, suppresses duplicates, and keeps parsing out of native code.
- [x] 4.4 Route share callback URLs through AppDelegate/SceneDelegate without interfering with Garmin callbacks, and add native tests for record encoding, atomic drain/acknowledgement, malformed files, callback routing, and dev/prod configuration.

## 5. Durable Queue Storage

- [x] 5.1 Extend `SendQueueRecord` with typed failure metadata, attempt count, next-attempt time, and acknowledgement deadline while retaining pending, sending, sent, and failed as the only stored statuses.
- [x] 5.2 Define the `SendQueueRepository` contract for transactional enqueue, ordered reads, atomic pending claims, guarded transitions, acknowledgement lookup, retry scheduling, and explicit retry.
- [x] 5.3 Implement SQLite schema version 1 with a unique message id, normalized envelope JSON, physical device id, timestamps, retry/acknowledgement fields, transactions, migrations, and an explicit unsupported-platform provider.
- [x] 5.4 Implement an app-scoped queue controller that restores immutable snapshots, publishes persisted transitions, maps pending-offline to the UI label **queued**, and surfaces storage failures without attempting transport.
- [x] 5.5 Add repository/controller tests for round trips, process restoration, concurrent claims, unique ids, transition guards, corrupted rows, migration rollback, persistence failures, sorting, and unsupported platforms.

## 6. Garmin Send and Acknowledgement Transport

- [x] 6.1 Add a typed Dart acknowledgement gateway over `wristlink/garmin_acknowledgements` that validates raw maps through `WatchAcknowledgement` and exposes malformed events as diagnostics rather than queue mutations.
- [x] 6.2 Extend the Android Garmin transport owner to send normalized maps to a discovered physical device/app, emit raw acknowledgement app messages, share idempotent SDK/device registration across engines, and map all documented SDK/too-large outcomes to existing error codes.
- [x] 6.3 Extend the iOS Garmin transport owner with equivalent normalized send, app-message acknowledgement, lifecycle-safe registration, device/app lookup, main-queue completion, and typed transport-error mapping.
- [x] 6.4 Add Dart, Kotlin, and Swift tests for send argument validation, device/app lookup, success completion, every mapped failure, too-large mapping, raw acknowledgement delivery, duplicate callbacks, timeout, and exactly-once completion.

## 7. Delivery Coordination and Background Retry

- [x] 7.1 Implement the Dart delivery coordinator that resolves stored targets through shared device state, atomically claims pending records, invokes Garmin transport, waits for required acknowledgements, and persists every outcome.
- [x] 7.2 Implement transient/terminal error classification, capped exponential backoff, acknowledgement deadlines, idempotent accepted/rejected/retryable handling, unknown/late acknowledgement diagnostics, and unknown-delivery recovery for interrupted sends.
- [x] 7.3 Wire immediate submission, app startup/foreground, relevant `DeviceDirectory` readiness changes, and explicit retry to the same mutually exclusive queue-drain path.
- [x] 7.4 Implement `BackgroundSendScheduler` with WorkManager/BackgroundTasks registration, constraints, unique work, cancellation when no retryable work remains, and platform scheduling errors mapped without losing pending records.
- [x] 7.5 Add the top-level background Dart entrypoint and minimal headless composition for SQLite queue storage, persisted device settings, Garmin transport/acknowledgements, and the coordinator; register native bridges idempotently for foreground and background engines.
- [x] 7.6 Add deterministic coordinator/background tests for ready/offline/missing-companion targets, transport and acknowledgement outcomes, backoff, overlapping triggers, process interruption, platform deadline/cancellation, and foreground fallback when background execution is delayed.
- [x] 7.7 Return from point submission after durable enqueue and launch submission/startup drains as observed asynchronous work so acknowledgement waits do not block confirmation navigation or app-shell initialization; cover controller updates, overlapping triggers, errors, and disposal in tests.
- [x] 7.8 Consume the unified acknowledgement event stream in the delivery coordinator, forward malformed gateway diagnostics as delivery diagnostics without queue mutation, and test malformed and valid events arriving in sequence.

## 8. Manual Picker, Confirmation, and Recovery UI

- [x] 8.1 Move long-lived device, share, queue, Garmin, parsing, and background services into one app-scoped composition and add a root point-flow coordinator that waits for initialization while preserving selected-tab state.
- [x] 8.2 Implement the Android/iOS Google Maps manual picker from the Paper snapshot with camera-center pin selection, pan/zoom/tap behavior, optional current-location permission, coordinate sheet, cancel, and **Use this point** actions.
- [x] 8.3 Implement the shared point confirmation screen with source, coordinates, editable non-empty name, Navigate/Save waypoint control, live `DeviceDirectory` readiness, setup actions, and immediate-send versus offline-queue messaging.
- [x] 8.4 Implement the no-coordinate/short-link error state with bounded original text display, copy action, manual latitude/longitude entry, validation, retry, and transition into the same confirmation flow.
- [x] 8.5 Implement queue-backed pending/sending/sent/failed point status screens, including the Paper **Point queued** explanation and typed terminal/retry recovery actions.
- [x] 8.6 Connect the Send home share instructions and **Manual point** action while leaving timer, note, and command rows inert, and replace the static Queue destination with queue summaries, persisted point rows, and an empty state.
- [x] 8.7 Add widget tests with fake map/share/queue/Garmin services for manual selection, both intents, editing, readiness variants, invalid fields, payload-too-large, parse recovery, copy/manual entry, status changes, Queue rendering, navigation restoration, semantics, large text, and platform-adaptive controls.

## 9. End-to-End and Platform Verification

- [x] 9.1 Add integration scenarios for manual map point → confirmation → Navigate/Save waypoint envelope → ready send/accepted acknowledgement and offline durable queue → later reconnect/retry.
- [x] 9.2 Verify Android Google Maps sharing on cold start, warm `singleTop` delivery, duplicate redelivery, malformed/non-coordinate text, and short-link connectivity failure for both dev and prod flavors.
- [x] 9.3 Verify iOS Google Maps sharing through both dev and prod Share Extensions, including stopped/running app handoff, App Group fallback when foregrounding is denied, callback coexistence with Garmin discovery, and exactly-once consumption.
- [x] 9.4 Verify queue restoration across process/device restart, background work on both platforms when granted, foreground fallback, acknowledgement timeout, explicit retry after unknown delivery, and concurrent trigger exclusion.

## 10. Project Knowledge and Final Checks

- [x] 10.1 Update `AGENTS.md` with durable share-ingress ownership, dev/prod App Group and callback identifiers, map-key restrictions, iOS 14 baseline, queue transaction/state-machine rules, acknowledgement channel ownership, and background-engine verification requirements.
- [x] 10.2 Run `dart format .`, `flutter analyze`, `flutter test`, and `flutter test test/features/payloads`.
- [x] 10.3 With Android Studio's supported JDK, run Android dev/prod native unit tests and `flutter build apk --debug --flavor dev` plus `flutter build apk --debug --flavor prod`.
- [x] 10.4 Run iOS native tests and `flutter build ios --no-codesign --flavor dev` plus `flutter build ios --no-codesign --flavor prod`, confirming the matching Share Extension is embedded once in each build.
- [x] 10.5 Run `openspec validate add-send-points --strict`, review the final diff for unintended contract-submodule or Paper snapshot changes, and document that the existing contract revision `0324a3dcaaba9d580723a7e845b312084c6c2343` remains adopted.

## 11. Merge-Blocking Review Follow-up

- [x] 11.1 Capture the accepted merge-blocking review findings in the proposal, design, requirements, tasks, and `AGENTS.md`, including the canonical/raw id invariant, cold-process transport hydration, and tracked application lockfiles.
- [x] 11.2 Add one typed Dart physical-device-id codec that preserves `physical:<raw-native-id>` in domain/storage state, emits only the validated raw id to `wristlink/garmin_send`, and rejects empty, malformed, or non-physical ids before native invocation.
- [x] 11.3 Add cross-boundary regression fixtures and tests that start with Android numeric and iOS UUID discovery payloads, map them to canonical `GarminDeviceId` values, serialize sends back to raw ids, and verify matching native cache lookup rather than independent incompatible samples.
- [x] 11.4 Extend the typed Garmin discovery/transport boundary with idempotent transport hydration and run it after persisted device settings load but before foreground or background delivery-service startup drains.
- [x] 11.5 On Android, silently initialize the Connect IQ SDK, reload known devices and companion apps, and publish current readiness before any cold-process record is claimed; keep work pending when hydration is unavailable.
- [x] 11.6 On iOS, reconstruct transport-only `IQDevice` objects from the latest Dart-owned authorized-device descriptors without launching Garmin Connect Mobile, register device/app events, refresh current readiness, and avoid introducing a second authoritative persisted device list.
- [x] 11.7 Add cold-process tests for Android and iOS covering a persisted formerly-ready target plus eligible queue record, hydration-before-drain ordering, unavailable hydration, immediate submission without visiting Devices, and raw-id transport lookup.
- [x] 11.8 Add narrow `.gitignore` exceptions for `/pubspec.lock` and `/ios/Podfile.lock`, commit both application lockfiles, and confirm package/library-local lockfiles remain ignored where appropriate.
- [x] 11.9 Run formatting, static analysis, Flutter tests, Android dev/prod native tests, iOS native tests, and dev/prod Android and iOS builds; document that the message contract and adopted contract revision remain unchanged.

## 12. Post-Verification Correctness Follow-up

- [x] 12.1 Capture the post-verification findings in the proposal, send-queue requirements, design decisions, focused follow-up tasks, durable project guidance, and implementation notes.
- [x] 12.2 Fix the iOS headless background composition to select the supported mobile method-channel Garmin discovery/hydration gateway, and add production-factory regression coverage proving both Android and iOS hydrate before claim/send.
- [x] 12.3 Surface quarantined or corrupted SQLite queue rows through the queue controller and UI as persistent diagnosable storage issues, provide explicit recovery/removal without hiding unaffected rows, and add repository/controller/widget coverage.
- [x] 12.4 Rerun proportional full verification: formatting, static analysis, Flutter tests, Android dev/prod native suites, iOS native suites, dev/prod Android and iOS builds, and `openspec validate add-send-points --strict`.

## Implementation Notes

- The point message contract remains unchanged. This implementation continues to adopt contract submodule revision `0324a3dcaaba9d580723a7e845b312084c6c2343`.
- Final diff review found no contract-submodule pointer change and no Paper design or snapshot changes.
- Follow-up verification added connected Android instrumentation for raw-intent persistence, cold/warm lifecycle handling, malformed inputs, acknowledgement cleanup, duplicate suppression, bounds, and non-share launches. iOS host tests now execute the same persistence service used by the Share Extension and verify stopped/running app delivery, callback/resume deduplication, Garmin callback coexistence, and acknowledgement cleanup.
- Merge-blocking review follow-up does not change the v1 message or acknowledgement contract; it corrects device identity at the transport boundary, restores native process-local transport state before delivery, and makes dependency resolution reproducible.
- Post-verification artifact updates add no message-contract change and retain adopted contract revision `0324a3dcaaba9d580723a7e845b312084c6c2343`.
- Final post-verification checks passed formatting, static analysis, all Flutter tests, Android and iOS dev/prod native suites, dev/prod Android and iOS builds, strict OpenSpec validation, and diff-integrity review; the contract revision remains unchanged and no Paper artifacts were modified.
