## Context

See `proposal.md` for motivation and `specs/send-point/spec.md`, `specs/send-queue/spec.md`, and `specs/app-shell/spec.md` for behavior. The repository already has shared physical-device state, default-target resolution, v1 point payloads with required intent, a typed Dart Garmin send gateway, and a queue record state model. It does not have durable queue storage or orchestration, inbound share adapters, native Garmin send/acknowledgement adapters, an embedded map dependency, or background-work composition.

The native Garmin bridges currently retain SDK/device objects discovered during the app session. Send and acknowledgement adapters must extend that transport boundary without reconstructing payload business rules natively. The iOS app currently supports iOS 13 and has dev/prod bundle ids and Garmin callback schemes; a Share Extension and current Google Maps Flutter plugin require new flavor-specific identifiers, entitlements, and a higher deployment baseline.

Review of the completed transport path found two boundary assumptions that must be made explicit. Dart prefixes every physical device id with `physical:` for stable domain and storage identity, while the native Garmin SDK caches are keyed by the raw Android numeric id or iOS UUID. In addition, persisted Dart device snapshots survive a process restart while the native SDK-owned device/app objects do not. A send must therefore translate the target id at the typed channel boundary and must not treat persisted reachability as current transport readiness until the native cache has been rehydrated.

## Goals / Non-Goals

**Goals:**

- Keep share parsing, point validation, envelope creation, target policy, retry classification, and queue state transitions testable in Dart.
- Give Android and iOS one typed inbound-share boundary even though their OS lifecycles differ.
- Persist a point before its first transport attempt and expose one queue record as the source of truth for confirmation outcomes, status screens, and the Queue tab.
- Make foreground and platform-granted background attempts use the same delivery coordinator and transition rules.
- Keep persisted physical-device identity stable in Dart while making raw native-id conversion and transport-cache hydration explicit, typed bridge responsibilities.
- Match the Paper layouts while using Material behavior on Android and iOS-native navigation, sheets, controls, and motion on iOS.

**Non-Goals:**

- Search, reverse geocoding, routing, map annotations beyond a selected pin, or storing map tiles.
- Accepting attachments, images, or arbitrary share types; ingress is limited to text and URLs.
- Guaranteeing an exact background delivery time; operating systems control background execution.
- Changing the v1 contract or implementing acknowledgement/deduplication logic in the separate Connect IQ watch app.
- Making timers, notes, or commands interactive in this change.

## Decisions

### Model point acquisition separately from contract payloads

Add a `send_point` feature with a `PointDraft` containing coordinates, editable label, optional preserved source text, and a typed source (`manualMap`, `googleMapsShare`, or `manualCoordinates`). A `PointDraft` is presentation/application state and never serialized directly to Garmin. Submission maps it explicitly to the existing `PointPayload` and `MessageEnvelope`, including the chosen `PointIntent` and the existing v1 byte-budget validation.

This keeps partially parsed or invalid shared input out of durable send records and avoids adding URL/source fields to the shared message contract. Using `PointPayload` as form state was rejected because it cannot represent parse failures, source attribution, or incomplete coordinate entry cleanly.

### Use a typed, acknowledgement-based share ingress boundary

Define a Dart `SharedContentGateway` that returns pending `SharedContentRecord` values and emits records received while the main engine is alive. Each record contains an opaque ingress id, received timestamp, platform, and bounded original text/URL. Dart acknowledges an ingress id only after the coordinator has copied it into point-flow state; platform storage then removes it. Recently acknowledged ids are retained for a bounded period to suppress OS redelivery.

On Android, add a `text/plain` `ACTION_SEND` intent filter. A small native ingress adapter handles both the initial intent and `onNewIntent`, stores raw records in app-private storage before notifying Flutter, and clears/marks the handled intent. It never parses coordinates.

On iOS, add a pure Swift Share Extension accepting public URL and plain-text items. It writes each bounded record as an atomically renamed JSON file in a flavor-specific App Group container, then requests that the containing app open through a flavor-specific callback URL. If iOS declines to foreground the containing app, the extension completes successfully and the record is consumed on the next app foreground. The app and SceneDelegate route the callback to the ingress adapter; the extension contains no Flutter or Garmin code.

Flavor configuration will own these paired values:

- dev App Group `group.com.wristlink.wristlinkFlutter.dev` and share callback `wristlink-share-dev`
- prod App Group `group.com.wristlink.wristlinkFlutter` and share callback `wristlink-share`
- extension bundle ids derived from each app bundle id with a `.ShareExtension` suffix

App Group entitlements must be identical between each app flavor and matching extension configuration. An off-the-shelf receive-sharing plugin was rejected because this repository needs explicit dev/prod App Group ownership, atomic exactly-once handoff, and a narrow text-only contract.

### Parse in deterministic stages and restrict network resolution

Implement a pure Dart parser with fixtures for observed Google Maps share formats. Parsing runs in this order: extract candidate URI(s), parse `geo:` coordinates, parse direct Google Maps URL path/query/`@lat,lon` forms and selected-place `!3d<latitude>!4d<longitude>` data segments, then parse an unambiguous coordinate pair from plain text. Data-segment parsing accepts exactly one distinct adjacent latitude/longitude pair and rejects malformed, ambiguous, or out-of-range candidates rather than guessing. Candidate coordinates must be finite and within contract ranges. Labels come from Dart's already-decoded URI path/query accessors or surrounding shared text; label normalization replaces Google Maps `+` separators without percent-decoding a second time, so Unicode and literal percent characters remain valid and cannot escape as parser exceptions. Labels remain editable.

Only allowlisted Google short-link hosts (`maps.app.goo.gl` and `goo.gl/maps`) may trigger network access. A resolver uses a streamed HTTP request, HTTPS-only redirects, an allowlisted Google Maps destination, a small redirect limit, and short connect/overall timeouts without consuming response bodies. Original shared text is capped before persistence and retained locally only until ingress acknowledgement; a parse failure keeps the bounded text in point-flow state for copy/manual recovery.

This avoids sending arbitrary user-shared URLs to a server and limits redirect abuse. Relying on a remote parsing service or scraping page HTML was rejected for privacy, offline behavior, and fragility.

### Use Google Maps Flutter for the embedded picker

Use the maintained `google_maps_flutter` platform view on Android and iOS. The selected point is the map camera center under the Paper pin treatment, so panning is the primary interaction and **Use this point** reads the latest camera target. A tap may reposition the camera, but there is only one draft coordinate. The current-location control requests permission only when invoked; denial leaves pan/zoom selection available. No reverse-geocoding request is made, and manual selections default to `Dropped pin` until edited.

Adopt the plugin's maintained mobile baseline by raising all iOS app, test, and Share Extension configurations from iOS 13 to iOS 14. Verify Android's resolved `minSdk` against the chosen plugin before pinning the dependency. Map API keys are build configuration, not Dart constants: add documented dev/prod variables consumed as Android manifest placeholders and iOS Info.plist/SDK initialization values. Keys embedded in client apps must be restricted by package/bundle id and signing identity in Google Cloud; commit only an example/configuration contract, not unrestricted credentials.

Using MapKit on iOS and Google Maps on Android was rejected because it would make visual behavior and point interaction diverge from the Google Maps design source. A web-map view was rejected for poorer native gestures, offline/error behavior, and a larger security surface.

### Store queue records transactionally and expose a controller stream

Introduce a `SendQueueRepository` interface and SQLite-backed mobile implementation. Store one row per message with the full normalized envelope JSON, target physical device id, status, created/updated timestamps, failure code/message, next-attempt time, attempt count, and acknowledgement deadline. A unique message-id constraint and transactions make enqueue/transition operations atomic across foreground and background isolates. Unsupported platforms return an explicit unsupported repository rather than volatile fallback.

A `SendQueueController` loads ordered records, publishes immutable snapshots to UI, and delegates mutations to a `SendQueueDeliveryCoordinator`. The existing `SendQueueRecord` grows typed failure metadata and retry scheduling fields but retains the required pending/sending/sent/failed enum. The Paper word **queued** is a presentation mapping for an offline pending point; **delivered** is not added as a fifth durable status because an accepted acknowledgement already maps point messages to `sent`.

Shared preferences or a single JSON list was rejected because overlapping lifecycle/background triggers require atomic selection and transition of individual records.

### Centralize delivery and retry policy in Dart

All triggers call one coordinator:

1. Resolve the record's stored physical target against `DeviceDirectory` state.
2. Atomically claim an eligible pending record by transitioning it to sending.
3. Invoke `GarminSendGateway` with the already validated envelope.
4. If transport accepts a point, persist an acknowledgement deadline and remain sending.
5. Apply raw acknowledgements only after Dart contract parsing and message-id correlation.
6. Map transient transport failures back to pending with capped exponential backoff and terminal failures to failed.

Submission persists pending first, then calls the same coordinator. App start/foreground, relevant device-directory updates, and a platform background callback request a drain. A process-wide mutex plus the database claim prevents duplicate attempts from overlapping triggers. A record restored as sending gets a bounded acknowledgement recovery window; if no acknowledgement arrives, it becomes failed with `deliveryOutcomeUnknown` and requires explicit retry. This chooses safety over automatic duplicate navigation/waypoint operations after an ambiguous crash.

Use the Flutter `workmanager` integration behind a dedicated `BackgroundSendScheduler` interface for Android WorkManager and iOS BackgroundTasks. Register a top-level background Dart entrypoint that composes only queue storage, persisted device settings, transport/acknowledgement adapters, and the coordinator. That entrypoint selects the same supported mobile method-channel Garmin discovery/hydration gateway for both Android and iOS; `UnsupportedGarminDeviceDiscoveryGateway` is reserved for truly unsupported platforms and must never be selected for iOS headless execution. Refactor native bridge registration so the Garmin transport channels are available to both the foreground engine and the background engine with application-safe context and idempotent SDK initialization. Background callbacks return promptly, respect platform deadlines, and reschedule only when future eligible work remains. Foreground triggers remain mandatory because neither platform guarantees timely background execution.

Native-only delivery orchestration was rejected because it would duplicate queue policy and contract decisions outside Dart. Foreground-only retry was rejected because the designed queued outcome promises background attempts when the platform permits them.

### Separate canonical Dart device ids from raw native transport ids

Keep `GarminDeviceId` values canonical inside Dart and durable storage as `physical:<raw-native-id>`. The typed Dart Garmin send gateway validates that a target is a physical id, removes exactly one `physical:` prefix, and sends only the non-empty raw id over `wristlink/garmin_send`. Android continues to resolve that raw value as the SDK's numeric device identifier, and iOS continues to resolve it as the SDK UUID. Native caches are not re-keyed with Dart domain prefixes.

This conversion belongs at the typed Dart bridge boundary rather than in UI, queue, or native lookup code. Discovery mapping and outbound mapping use one tested codec so a raw id returned by native discovery round-trips back to the same native device. Invalid or non-physical ids fail as typed Dart bridge errors before platform invocation. Shared fixtures cover an Android numeric id and an iOS UUID across discovery mapping, durable identity, outbound channel arguments, and native cache lookup.

Sending canonical ids unchanged was rejected because it couples a Dart namespace prefix to SDK-specific native lookup formats and makes every real physical-device lookup fail.

### Rehydrate transport-owned device state before startup drains

Treat device settings as the persisted authorization snapshot, not proof that the current process can send. After `LocalDeviceDirectory` loads the latest authorized devices, foreground and background composition must re-establish the platform SDK/device/app cache before the delivery service runs its startup drain. Until hydration returns current status, restored devices remain known targets but are not considered send-ready; failed or unavailable hydration leaves their records pending for a later foreground, device-readiness, or background trigger.

Android hydration initializes the Connect IQ SDK, queries its current known devices and companion apps without user interaction, and applies the resulting live device maps through the existing typed discovery gateway. iOS hydration must not launch Garmin Connect Mobile. Dart maps the already persisted authorized-device metadata into a typed restore request; the native bridge reconstructs `IQDevice` transport objects from the UUID, model name, friendly name, and part number already returned by discovery, registers device events, rebuilds `IQApp` ownership, and queries current app/device state. The latest authorized list remains owned and JSON-mapped by Dart through `DeviceSettingsStore`; iOS does not introduce a second independently authoritative device list.

The same hydration path is shared by foreground and headless composition. It is idempotent per native bridge owner and completes before any eligible record is claimed. A cold-process test starts with a persisted ready snapshot and queued record, proves that native restoration happens first, and verifies that the subsequent send uses the raw platform id without visiting the Devices screen.

Starting the drain from stale persisted reachability was rejected because it converts a healthy queued record into avoidable SDK/device-unavailable backoff and can leave immediate submission dependent on a later manual refresh.

### Extend the Garmin bridge as one transport owner per platform

The existing native Garmin device bridge already owns SDK initialization and the authorized native device objects needed for sending. Extend that platform transport component to register:

- the existing `wristlink/garmin_send` method call, accepting only a raw platform target id and normalized contract map;
- a `wristlink/garmin_acknowledgements` event channel emitting raw app-message maps from registered target/app callbacks; and
- lifecycle-safe SDK/device/app registration usable by foreground and headless engines without duplicating event registrations.

Android and iOS adapters validate only channel shape needed to call the SDK, locate the native device/app, perform the Garmin send, and map SDK failures (including too-large messages) to existing typed error codes. Dart parses acknowledgement contracts and owns all status transitions. Add native mapping/completion tests; do not add point intent, coordinate, retry, or label rules natively.

### Route shares after app composition is ready

Move long-lived service composition above `WristLinkAppShell`: device directory, share ingress, parser/resolver, queue repository/controller, Garmin gateways, and background scheduler must have one app-scoped lifecycle. A root navigation coordinator waits for service initialization, drains pending shares, and pushes parse-error or confirmation routes over the tab shell. Returning from the route reveals the previously selected tab. Manual point launches the picker through the same coordinator and then reuses confirmation.

UI reads immutable presentation models derived from `PointDraft`, `DeviceDirectory`, and queue snapshots. Queue/status screens never copy record status into local mutable state. Platform-adaptive controls and transitions implement the Paper intent while semantics labels, minimum touch targets, dynamic text, loading states, and map alternatives keep the flow accessible.

## Risks / Trade-offs

- [Google Maps changes shared URL formats] → Maintain a redacted fixture corpus for every supported form, parse defensively, and always preserve copy/manual-coordinate recovery.
- [A short link tracks or redirects unexpectedly] → Resolve only allowlisted HTTPS Google hosts with strict redirect/time bounds and no HTML parsing.
- [iOS does not foreground the app from a Share Extension] → Commit the App Group record first, show a clear extension completion message, and drain it on the next callback or app foreground.
- [App Group, callback scheme, extension bundle id, or signing entitlements diverge by flavor] → Derive them from one flavor configuration contract and add project-file/configuration tests for dev and prod.
- [Adding the maintained map plugin drops iOS 13] → Mark the deployment change as breaking, raise every target/configuration consistently, and verify both flavor builds before release.
- [A headless background engine lacks a required plugin or Garmin SDK state] → Add background composition tests where possible, platform instrumentation coverage, idempotent bridge registration, and foreground fallback; treat background timing as best effort.
- [Persisted device reachability is stale after process restart] → Mark restored snapshots non-send-ready until platform hydration completes, hydrate before startup drains, and retain pending work when hydration is unavailable.
- [Dart and native device-id formats drift] → Keep one typed canonical-to-raw codec with Android numeric and iOS UUID round-trip fixtures spanning discovery, send-channel serialization, and native lookup.
- [The process dies after transport but before acknowledgement] → Keep the stable message id, wait a bounded recovery period, then require explicit retry with an unknown-delivery warning rather than automatically duplicating the command.
- [A SQLite row becomes malformed or corrupt] → Quarantine it without constructing or sending a queue record, preserve and continue exposing unaffected rows, and surface a persistent storage diagnostic through the controller/UI. Recovery must be explicit: the user may remove the quarantined row or invoke a supported recovery action; silently omitting it is not acceptable.
- [Native Garmin acknowledgements arrive more than once or out of order] → Correlate and transition idempotently in Dart; unknown/late acknowledgements must not regress terminal records.
- [Platform views complicate widget tests] → Put map interaction behind a small controller/widget boundary and use fakes for widget tests, plus focused device integration tests for the real map.

## Migration Plan

1. Add dependencies and platform configuration, including iOS 14, map-key injection, dev/prod App Groups, extension targets, callback schemes, and background identifiers without wiring user entry points.
2. Add queue schema version 1. Existing users have no durable queue, so initialize an empty database; preserve the current device settings store unchanged.
3. Add share ingress and parser behind fakes, then verify Android cold/warm intents and iOS dev/prod extension handoff before enabling share targets in release configurations.
4. Add map picker and point confirmation using fake send services, then wire durable enqueue and queue-backed UI.
5. Implement native Garmin send and acknowledgement transport, foreground delivery, and finally background scheduling/entrypoint composition.
6. Replace static Queue examples and activate point actions only after restoration, failure, and flavor build checks pass.
7. Before merge, correct the canonical/raw device-id boundary, hydrate foreground and background native transport state before startup drains, and commit the application dependency lockfiles.

Rollback removes share registrations and disables point entry actions first. Keep the queue database readable for at least one rollback version so already queued points can be surfaced or exported rather than silently discarded; do not downgrade stored schema destructively. Roll back iOS 14 only if all iOS-14-only dependencies, extension settings, and built artifacts are removed together.
