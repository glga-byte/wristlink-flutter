## Why

The Connect IQ companion app UUID is currently duplicated in Android and iOS platform metadata, which makes local development and production release configuration easy to drift. The app needs Flutter flavors so development builds can target a development Connect IQ app while CI production builds target the production Connect IQ app without editing source files.

## What Changes

- Introduce Flutter `dev` and `prod` flavors for Connect IQ companion app configuration.
- Make `dev` and `prod` mobile app variants installable side by side on the same phone.
- Replace duplicated hardcoded Android and iOS Connect IQ app UUID metadata values with a shared flavor configuration file consumed by both platform build systems.
- Configure the `dev` flavor to use `11111111-1111-1111-1111-111111111111` until that placeholder is replaced with the real development Connect IQ app UUID.
- Configure the `prod` flavor to use `22222222-2222-2222-2222-222222222222` until that placeholder is replaced with the real production Connect IQ app UUID.
- Keep native Garmin bridge code responsible for reading platform metadata, but make the metadata generated from shared flavor configuration.
- Remove placeholder UUID special handling; configured flavor UUID values, including committed placeholder UUIDs, are treated uniformly as ordinary UUIDs by the app.
- Make iOS Garmin callback URL schemes flavor-specific so `dev` and `prod` installs do not compete for the same callback route.
- Document the flavor and configuration contract so future Android/iOS Garmin bridge changes keep UUID replacement centralized in one file.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `garmin-device-discovery`: require Connect IQ companion app status checks to use flavor-driven app UUID configuration with development and production values.

## Impact

- Android build configuration, application id configuration, and Android manifest metadata.
- iOS build configuration, schemes/configurations, bundle identifier configuration, and iOS `Info.plist` metadata.
- Native Garmin bridge tests or configuration tests for flavor UUID metadata, app identifiers, and iOS callback schemes.
- Project guidance in `AGENTS.md`.
- CI/release documentation or commands that build the `prod` Android/iOS flavor.
