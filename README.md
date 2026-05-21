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

The Connect IQ companion app UUID is selected by flavor through `WRISTLINK_CONNECT_IQ_APP_UUID`. Replace the committed placeholder UUIDs in `config/wristlink-flavors.xcconfig` with the real development and production Garmin Connect IQ app UUIDs when they are available.

Run the baseline checks with:

```sh
dart format .
flutter analyze
flutter test
```
