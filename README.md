# WristLink Flutter

WristLink is a Flutter app for sending short, useful data from a smartphone to Garmin watches.

This repository contains only the Flutter mobile app. Garmin Connect IQ watch app logic is developed separately.

## Development

Run the app locally with the development flavor:

```sh
flutter run --flavor dev
flutter build apk --debug --flavor dev
flutter build ios --no-codesign --flavor dev
```

Production and CI builds use the production flavor:

```sh
flutter build apk --debug --flavor prod
flutter build ios --no-codesign --flavor prod
```

### Android Gradle launcher

Run direct Android Gradle tasks through the JDK-aware launcher:

```sh
dart run tool/android_gradle.dart testDevDebugUnitTest testProdDebugUnitTest
```

It accepts any Gradle tasks, uses JDK 17 or 21 from `JAVA_HOME` or Flutter, and
needs no local Codex configuration. If Flutter has no supported JDK, configure
one with:

```sh
flutter config --jdk-dir="/path/to/jdk"
```

### Google Maps API keys

Follow Google's
[Maps SDK for Android setup guide](https://developers.google.com/maps/documentation/android-sdk/get-api-key)
to enable billing and create a restricted API key. Then create the local config:

```sh
cp config/wristlink-maps.example.xcconfig \
  config/wristlink-maps.local.xcconfig
```

Replace the example values with the dev/prod keys. The local file is ignored by Git; rebuild the app after changing it.

### Connect IQ app UUIDs

The Connect IQ companion app UUID is selected by flavor through `WRISTLINK_CONNECT_IQ_APP_UUID`. Replace the committed placeholder UUIDs in `config/wristlink-flavors.xcconfig` with the real development and production Garmin Connect IQ app UUIDs when they are available.

### Verification

Run the baseline checks with:

```sh
dart format .
flutter analyze
flutter test
```
