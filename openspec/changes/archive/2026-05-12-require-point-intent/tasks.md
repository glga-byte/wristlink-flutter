## 1. Contract Assets

- [x] 1.1 Update `contract/protocol/v1/message.schema.json` so point payloads require `intent` and only allow `navigate` or `save_waypoint`.
- [x] 1.2 Update `contract/protocol/v1/README.md` to document point intent semantics.
- [x] 1.3 Update valid point fixtures to include `intent`.
- [x] 1.4 Add or update invalid point fixtures so missing and unsupported point intents are rejected.

## 2. Flutter Contract Models

- [x] 2.1 Add a typed point intent model with wire mappings for `navigate` and `save_waypoint`.
- [x] 2.2 Make `PointPayload.intent` required in construction, parsing, validation, and serialization.
- [x] 2.3 Update all point payload construction sites in app code and tests to provide an explicit intent.

## 3. Verification

- [x] 3.1 Update payload contract tests to cover valid point intents, missing intent, and unsupported intent.
- [x] 3.2 Run `dart format .`.
- [x] 3.3 Run `flutter analyze`.
- [x] 3.4 Run `flutter test`.
- [x] 3.5 Run `flutter test test/features/payloads`.

## 4. Adoption Notes

- [x] 4.1 Record the adopted `contract/` submodule revision in implementation notes or the PR description.
- [x] 4.2 Confirm no native Android or iOS Garmin adapter adds point intent business logic.
