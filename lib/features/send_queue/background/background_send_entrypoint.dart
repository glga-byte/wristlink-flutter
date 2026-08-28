import 'dart:async';
import 'dart:io';

import 'package:workmanager/workmanager.dart';

import '../../../app/platform/device_settings_store_provider.dart';
import '../../../app/platform/garmin_device_discovery_gateway_provider.dart';
import '../../../app/platform/send_queue_repository_provider.dart';
import '../../devices/data/local_device_directory.dart';
import '../../garmin_bridge/garmin_acknowledgement_gateway.dart';
import '../../garmin_bridge/garmin_send_gateway.dart';
import '../application/send_queue_delivery_coordinator.dart';
import '../data/send_queue_repository.dart';
import 'background_send_scheduler.dart';
import 'workmanager_background_send_scheduler.dart';

const backgroundSendExecutionBudget = Duration(seconds: 25);

class BackgroundSendComposition {
  const BackgroundSendComposition({
    required this.repository,
    required this.deviceDirectory,
    required this.coordinator,
    required this.scheduler,
  });

  final SendQueueRepository repository;
  final LocalDeviceDirectory deviceDirectory;
  final SendQueueDeliveryCoordinator coordinator;
  final BackgroundSendScheduler scheduler;
}

typedef BackgroundSendCompositionFactory =
    Future<BackgroundSendComposition> Function();

@pragma('vm:entry-point')
void backgroundSendCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != backgroundSendTaskName &&
        taskName != backgroundSendUniqueWorkName) {
      return true;
    }
    return executeBackgroundSendTask();
  });
}

Future<bool> executeBackgroundSendTask({
  BackgroundSendCompositionFactory compositionFactory =
      createBackgroundSendComposition,
  Duration executionBudget = backgroundSendExecutionBudget,
}) async {
  BackgroundSendComposition? composition;
  try {
    composition = await compositionFactory();
    await composition.repository.initialize();
    await composition.deviceDirectory.hydrateTransport();
    await composition.coordinator.start();
    final result = await composition.coordinator.requestDrain(
      QueueDrainTrigger.background,
      deadline: DateTime.now().toUtc().add(executionBudget),
    );

    if (composition.scheduler.platform == BackgroundSendPlatform.android) {
      // Returning false asks Android WorkManager to retry this unique work with
      // its configured exponential backoff. Queue state remains authoritative.
      return !result.hasRetryableWork;
    }
    await composition.scheduler.reconcile(
      hasRetryableWork: result.hasRetryableWork,
      nextWakeUpAt: result.nextWakeUpAt,
      now: DateTime.now().toUtc(),
    );
    return true;
  } on Object {
    // WorkManager treats false as retryable. Any claimed/sending record remains
    // durable and is recovered conservatively by the next coordinator run.
    return false;
  } finally {
    if (composition != null) {
      await composition.coordinator.dispose();
      composition.deviceDirectory.dispose();
      await composition.repository.close();
    }
  }
}

Future<BackgroundSendComposition> createBackgroundSendComposition() async {
  final repository = await createSendQueueRepository();
  final deviceDirectory = LocalDeviceDirectory(
    store: createDeviceSettingsStore(),
    discoveryGateway: createGarminDeviceDiscoveryGateway(),
  );
  try {
    await deviceDirectory.load();
    final scheduler = WorkmanagerBackgroundSendScheduler(
      platform: Platform.isAndroid
          ? BackgroundSendPlatform.android
          : Platform.isIOS
          ? BackgroundSendPlatform.ios
          : BackgroundSendPlatform.unsupported,
      callbackDispatcher: backgroundSendCallbackDispatcher,
    );
    final coordinator = SendQueueDeliveryCoordinator(
      repository: repository,
      deviceDirectory: deviceDirectory,
      sendGateway: MethodChannelGarminSendGateway(),
      acknowledgementGateway: EventChannelGarminAcknowledgementGateway(),
    );
    return BackgroundSendComposition(
      repository: repository,
      deviceDirectory: deviceDirectory,
      coordinator: coordinator,
      scheduler: scheduler,
    );
  } on Object {
    deviceDirectory.dispose();
    await repository.close();
    rethrow;
  }
}
