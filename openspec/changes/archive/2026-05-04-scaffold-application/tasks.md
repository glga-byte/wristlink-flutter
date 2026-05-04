## 1. Flutter Project Setup

- [x] 1.1 Create or update the Flutter project files required for a runnable mobile app.
- [x] 1.2 Confirm `pubspec.yaml` defines the WristLink app package, Flutter SDK constraints, and test dependencies.
- [x] 1.3 Ensure generated platform scaffolding does not include Garmin SDK, WorkManager, or Connect IQ watch app logic.

## 2. App Shell

- [x] 2.1 Add `lib/main.dart` as the minimal executable entry point.
- [x] 2.2 Add the root WristLink app widget under `lib/app/`.
- [x] 2.3 Configure the app shell with Flutter `MaterialApp`, app title, baseline theme, and the home route.

## 3. Home Screen

- [x] 3.1 Add a home feature under `lib/features/home/`.
- [x] 3.2 Implement a basic home screen that displays the WristLink name and app purpose.
- [x] 3.3 Add visible placeholders for points, timers, notes, and send queue status without implementing send behavior.
- [x] 3.4 Keep reusable visual pieces in appropriate shared UI files if the implementation introduces shared widgets.

## 4. Verification

- [x] 4.1 Add widget tests that verify the app shell renders the home screen.
- [x] 4.2 Add widget test assertions for the WristLink name, app purpose, and workflow placeholders.
- [x] 4.3 Run Flutter formatting, analysis, and tests for the scaffolded app.
