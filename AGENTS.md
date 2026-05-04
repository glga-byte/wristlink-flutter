# AGENTS.md

## Project Context

WristLink is a Flutter app for quickly sending short, useful data from a smartphone to Garmin watches: points, timers, notes, and other commands.
This repository covers only the Flutter part. The Garmin Connect IQ app is developed separately.

## Technologies

- Flutter / Dart
- Android bridge through Platform Channels for Garmin Connect IQ Mobile SDK
- Local storage for the send queue
- WorkManager through a native Platform Channel for background sending

## Recommended Structure

```text
lib/
  app/                 # App initialization, routing, DI
  features/
    send_queue/        # Send queue and task statuses
    garmin_bridge/     # Dart API over Platform Channels
    payloads/          # Models for points, timers, notes, commands
  shared/
    storage/           # Local storage abstractions
    errors/            # Shared errors and result types
    ui/                # Shared widgets
android/
  app/src/main/...     # Native bridge, Garmin SDK, WorkManager
test/                  # Unit/widget tests
integration_test/      # Integration scenarios when needed
```

## Best Practices

- Keep business logic in Dart; use native Android code only for the Garmin SDK and WorkManager.
- Wrap Platform Channels in a typed Dart API; do not call channels directly from UI code.
- The send queue must survive app restarts and missing watch connectivity.
- Every command must have an explicit status: pending, sending, sent, failed.
- Map Garmin SDK and native bridge errors to clear domain errors.
- Do not mix UI models, storage models, and channel payloads without explicit mapping logic.
- Use WorkManager for background sending only through a dedicated bridge/service layer.
- Cover payload serialization, queue behavior, and bridge error handling with tests.
- Do not add Connect IQ watch app logic to this repository.
