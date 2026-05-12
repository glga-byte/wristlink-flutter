## Context

The v1 WristLink message contract is shared through the `contract/` submodule and consumed by the Flutter app and the separate Connect IQ watch app. The current point payload contains coordinates plus optional label and note, but it does not tell the watch whether the point should be used for navigation or saved as a waypoint.

This change intentionally updates v1 in place and ignores backward compatibility. Existing point messages without `intent` become invalid.

## Goals / Non-Goals

**Goals:**

- Make point intent explicit and required in the v1 contract.
- Support exactly two point intents: `navigate` and `save_waypoint`.
- Keep schema, docs, fixtures, Dart domain models, and tests aligned.
- Preserve the native Garmin bridge boundary as a transport adapter that receives already-normalized contract maps.

**Non-Goals:**

- Add Connect IQ watch-side behavior in this Flutter repository.
- Add compatibility parsing for legacy point payloads without `intent`.
- Introduce a new protocol version.
- Add native Android or iOS point business rules.

## Decisions

1. Require `intent` inside the point `payload`.

   Rationale: The intent is kind-specific data, so placing it under `payload` keeps the envelope generic and avoids adding point-only fields beside `kind`.

   Alternative considered: Add a new message kind for waypoint saving. That would duplicate the point coordinate shape and make future point variants harder to evolve.

2. Use string wire values `navigate` and `save_waypoint`.

   Rationale: The values are compact, readable, stable across Dart and Connect IQ code, and match the user's requested names.

   Alternative considered: Use shorter values such as `nav` and `save`. The byte savings are not worth the loss of clarity in shared fixtures and watch-side parsing.

3. Treat missing or unknown point intent as malformed payload.

   Rationale: v1 is being changed in place and backward compatibility is explicitly out of scope. Rejecting invalid point payloads keeps queue and transport behavior deterministic.

   Alternative considered: Default missing intent to `navigate`. That would preserve older messages but hide ambiguous behavior and conflict with the required-field requirement.

## Risks / Trade-offs

- [Risk] Existing queued point messages without `intent` will fail validation after the app updates. -> Mitigation: This is accepted as part of the requested breaking v1 change.
- [Risk] The Flutter repo and Connect IQ repo can temporarily disagree on the contract revision. -> Mitigation: Pin the updated `contract/` submodule revision in each consuming repo and document the adopted revision in implementation notes or the PR description.
- [Risk] Adding a required field increases message size. -> Mitigation: Keep the values compact and continue enforcing the existing 1024-byte v1 serialized envelope budget with fixtures and tests.
