## Context

Android currently declares `com.wristlink.CONNECT_IQ_APP_ID` directly in `AndroidManifest.xml`, and iOS declares `WristLinkConnectIQAppUUID` directly in `Info.plist`. Native bridge code reads those platform metadata values to query Garmin Connect IQ companion app status.

This keeps the Garmin SDK boundary in the right native layer, but duplicates the UUID and makes release configuration error-prone. The project also needs an intentional Flutter flavor split so local development builds can use a development Connect IQ app UUID and CI production builds can use the production UUID.

## Goals / Non-Goals

**Goals:**

- Add `dev` and `prod` Flutter flavors for Connect IQ companion app configuration.
- Make `dev` and `prod` installable side by side on the same Android or iOS phone.
- Define one logical Connect IQ companion app UUID key per flavor.
- Use one flavor-owned build setting location per platform for the UUID values; do not duplicate the UUID in native source or platform metadata files.
- Feed the selected flavor UUID into Android manifest metadata and iOS Info.plist metadata.
- Require `dev` builds to use the development Connect IQ app UUID configured for the `dev` flavor.
- Require `prod` builds to use the production Connect IQ app UUID configured for the `prod` flavor.
- Remove placeholder UUID special handling so configured UUIDs are treated as real Connect IQ app identifiers.
- Make iOS Garmin callback URL schemes flavor-specific so `dev` and `prod` installs can receive authorization callbacks independently.
- Document the configuration contract in project guidance.

**Non-Goals:**

- Move Garmin SDK discovery or companion-status logic from native code into Dart.
- Add Connect IQ watch app logic to this repository.
- Introduce a runtime user setting for the Connect IQ app UUID.
- Define unrelated environment settings such as API endpoints, signing, icons, or Firebase projects unless implementation discovers they are required to make flavors build correctly.

## Decisions

### Use Flutter flavors as the selection mechanism

The implementation should introduce `dev` and `prod` Flutter flavors. Developers should run the development variant, and CI should build the production variant. The selected flavor determines which Connect IQ companion app UUID is emitted into native metadata.

Alternative considered: keep a single app target and select the UUID through an ad hoc build setting. That is simpler, but it does not make development and production variants explicit in the same way Flutter flavor tooling does.

### Keep the UUID as native build metadata, not a Dart runtime setting

The UUID is consumed by native Android and iOS Garmin SDK adapters. Each flavor should therefore provide it through platform build metadata, keeping Dart business logic unaware of a native-only integration detail.

Alternative considered: pass the value through `--dart-define` and then send it over a platform channel. That adds runtime plumbing and makes native discovery depend on Dart initialization even though the value is build metadata.

### Keep native metadata names stable

Android should continue exposing `com.wristlink.CONNECT_IQ_APP_ID`, and iOS should continue exposing `WristLinkConnectIQAppUUID`. The implementation changes how those values are produced, not how native bridge code reads them.

This minimizes risk in the Garmin bridge and keeps the platform metadata contract explicit for tests and future native work.

### Use one logical key across flavor-specific platform files

The implementation should use the logical key `WRISTLINK_CONNECT_IQ_APP_UUID` for both Android and iOS. Android product flavors should define the value once in Gradle flavor configuration and feed that key into manifest metadata substitution. iOS flavor build configurations should define the value once through xcconfig/build settings and feed the same key into `Info.plist` build-setting substitution.

This keeps the platform metadata names stable while making the flavor value explicit. A separate cross-platform configuration file is not required; the centralization boundary is one platform build setting per flavor, with identical key and flavor names across Android and iOS.

### Make production UUID selection flavor-owned

The `prod` flavor should own the production Connect IQ app UUID through flavor-specific build configuration. CI should select the `prod` flavor, not supply a different UUID for each release.

The `dev` flavor should own the development Connect IQ app UUID the same way. Both UUIDs should be hardcoded in flavor build configuration, not supplied at runtime, and native code should not recognize any magic placeholder UUID value.

Until real Garmin Connect IQ companion app UUIDs are available, the committed flavor configuration SHALL use syntactically valid placeholder UUIDs:

- `dev`: `11111111-1111-1111-1111-111111111111`
- `prod`: `22222222-2222-2222-2222-222222222222`

These placeholder UUIDs are documentation placeholders only. The app must still pass them through native metadata and Garmin bridge code as ordinary UUID values. Project documentation must identify the exact Android and iOS flavor build settings where the values are replaced with real Connect IQ app UUIDs.

### Make dev and prod separately installable

The `dev` and `prod` flavors must be installable side by side on the same phone. Android production keeps the canonical application id `com.wristlink.wristlink_flutter`; Android development uses `com.wristlink.wristlink_flutter.dev`, preferably by applying an `applicationIdSuffix` to the `dev` flavor.

iOS production keeps the canonical bundle identifier `com.wristlink.wristlinkFlutter`; iOS development uses `com.wristlink.wristlinkFlutter.dev` through flavor-specific build settings.

The production identifiers should remain the canonical app identifiers. The development identifiers should be clearly derived from production identifiers so logs, devices, and signing setup remain understandable.

### Use Xcode schemes and flavor build configurations for iOS

iOS should model Flutter flavors with shared Xcode schemes named `dev` and `prod`. Each scheme should select flavor-specific build configurations based on the standard Flutter configuration types, for example `Debug-dev`, `Profile-dev`, `Release-dev`, `Debug-prod`, `Profile-prod`, and `Release-prod`.

Each flavor configuration should continue to include the appropriate Flutter base xcconfig (`Debug.xcconfig` for debug, `Release.xcconfig` for release/profile) and add only the flavor-specific build settings needed for this change: `PRODUCT_BUNDLE_IDENTIFIER`, `WRISTLINK_CONNECT_IQ_APP_UUID`, and `WRISTLINK_GARMIN_CALLBACK_SCHEME`.

This follows Flutter's iOS flavor model, where `--flavor` selects an Xcode scheme, while keeping Garmin-specific values in build settings rather than native Swift source.

### Make iOS callback routing flavor-specific

iOS currently initializes Garmin Connect IQ with the hardcoded callback scheme `wristlink-ciq`. Because both installed variants may initiate Garmin authorization, each flavor should use a distinct callback URL scheme and matching `CFBundleURLSchemes` entry. The native bridge should read the selected callback scheme from build metadata key `WRISTLINK_GARMIN_CALLBACK_SCHEME` rather than hardcoding one shared value.

Production SHALL use `wristlink-ciq`. Development SHALL use `wristlink-ciq-dev`.

## Risks / Trade-offs

- A flavor is configured with a placeholder or wrong real UUID -> companion status checks may query a non-existent or wrong Connect IQ app. Mitigation: hardcode visible placeholder values until real values are available, pass all syntactically valid UUIDs through uniformly, and document the replacement points.
- Local developers need a private dev UUID -> a committed development UUID may not fit every workflow. Mitigation: treat the committed `dev` UUID as the project default and document how to change it intentionally if needed.
- Android and iOS flavor mechanisms differ -> a literal single source file would require glue code. Mitigation: keep one build-setting location per platform flavor and use identical logical keys and flavor names across Android and iOS.
- Flavors can expand scope into signing, bundle ids, icons, and schemes -> implementation may grow beyond UUID selection. Mitigation: include only the identifier and scheme/configuration work required for side-by-side `dev` and `prod` installs, and defer unrelated branding unless builds require it.
