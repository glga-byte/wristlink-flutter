import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/devices/data/in_memory_device_settings_store.dart';
import 'package:wristlink_flutter/features/devices/data/local_device_directory.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_acknowledgement_gateway.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_device_discovery_gateway.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_send_gateway.dart';
import 'package:wristlink_flutter/features/payloads/message_contract.dart';
import 'package:wristlink_flutter/features/send_queue/application/send_queue_delivery_coordinator.dart';
import 'package:wristlink_flutter/features/send_queue/background/background_send_entrypoint.dart';
import 'package:wristlink_flutter/features/send_queue/background/background_send_scheduler.dart';
import 'package:wristlink_flutter/features/send_queue/background/workmanager_background_send_scheduler.dart';
import 'package:wristlink_flutter/features/send_queue/data/send_queue_repository.dart';
import 'package:wristlink_flutter/features/send_queue/domain/send_queue_record.dart';

void main() {
  group('WorkmanagerBackgroundSendScheduler', () {
    test(
      'uses replaceable one-off Android work and cancels when empty',
      () async {
        final client = _FakeWorkmanagerClient();
        final scheduler = WorkmanagerBackgroundSendScheduler(
          platform: BackgroundSendPlatform.android,
          callbackDispatcher: _callbackDispatcher,
          client: client,
        );
        final now = DateTime.utc(2026, 8, 20, 12);

        expect((await scheduler.initialize()).isSuccess, isTrue);
        final scheduled = await scheduler.reconcile(
          hasRetryableWork: true,
          nextWakeUpAt: now.add(const Duration(minutes: 2)),
          now: now,
        );
        final cancelled = await scheduler.reconcile(
          hasRetryableWork: false,
          nextWakeUpAt: null,
          now: now,
        );

        expect(scheduled.scheduled, isTrue);
        expect(client.oneOffDelays, [const Duration(minutes: 2)]);
        expect(client.periodicDelays, isEmpty);
        expect(client.cancelCount, 1);
        expect(cancelled.scheduled, isFalse);
      },
    );

    test('uses iOS BGAppRefresh registration with a unique task', () async {
      final client = _FakeWorkmanagerClient();
      final scheduler = WorkmanagerBackgroundSendScheduler(
        platform: BackgroundSendPlatform.ios,
        callbackDispatcher: _callbackDispatcher,
        client: client,
      );
      final now = DateTime.utc(2026, 8, 20, 12);

      final result = await scheduler.reconcile(
        hasRetryableWork: true,
        nextWakeUpAt: now.subtract(const Duration(seconds: 1)),
        now: now,
      );

      expect(result.scheduled, isTrue);
      expect(client.initializeCount, 1);
      expect(client.periodicDelays, [Duration.zero]);
      expect(
        backgroundSendUniqueWorkName,
        'com.wristlink.sendQueue.backgroundRetry',
      );
      expect(backgroundSendTaskName, 'wristlinkSendQueueRetry');
    });

    test(
      'maps initialization, scheduling, and cancellation failures',
      () async {
        final initializeClient = _FakeWorkmanagerClient()
          ..initializeError = StateError('init');
        final initializeScheduler = WorkmanagerBackgroundSendScheduler(
          platform: BackgroundSendPlatform.android,
          callbackDispatcher: _callbackDispatcher,
          client: initializeClient,
        );
        expect(
          (await initializeScheduler.initialize()).error?.code,
          BackgroundSchedulingErrorCode.initializationFailed,
        );

        final scheduleClient = _FakeWorkmanagerClient()
          ..scheduleError = StateError('schedule');
        final scheduleScheduler = WorkmanagerBackgroundSendScheduler(
          platform: BackgroundSendPlatform.android,
          callbackDispatcher: _callbackDispatcher,
          client: scheduleClient,
        );
        expect(
          (await scheduleScheduler.reconcile(
            hasRetryableWork: true,
            nextWakeUpAt: null,
            now: DateTime.utc(2026, 8, 20),
          )).error?.code,
          BackgroundSchedulingErrorCode.schedulingFailed,
        );

        final cancelClient = _FakeWorkmanagerClient()
          ..cancelError = StateError('cancel');
        final cancelScheduler = WorkmanagerBackgroundSendScheduler(
          platform: BackgroundSendPlatform.android,
          callbackDispatcher: _callbackDispatcher,
          client: cancelClient,
        );
        expect(
          (await cancelScheduler.reconcile(
            hasRetryableWork: false,
            nextWakeUpAt: null,
            now: DateTime.utc(2026, 8, 20),
          )).error?.code,
          BackgroundSchedulingErrorCode.cancellationFailed,
        );
      },
    );
  });

  group('background headless execution', () {
    for (final platform in [
      BackgroundSendPlatform.android,
      BackgroundSendPlatform.ios,
    ]) {
      test(
        '${platform.name} sends ready durable work when execution is granted',
        () async {
          final now = DateTime.now().toUtc();
          final repository = _SingleRecordRepository(
            _record(now, device: _readyDevice),
          );
          final directory = LocalDeviceDirectory(
            store: InMemoryDeviceSettingsStore(
              defaultDeviceId: _readyDevice.id,
              authorizedDevices: const [_readyDevice],
            ),
            discoveryGateway: const _RestoringDiscoveryGateway(),
          );
          await directory.load();
          final acknowledgements = _FakeAcknowledgementGateway();
          final sendGateway = _AcceptingSendGateway(acknowledgements, now);
          final scheduler = _RecordingScheduler(platform);
          final coordinator = SendQueueDeliveryCoordinator(
            repository: repository,
            deviceDirectory: directory,
            sendGateway: sendGateway,
            acknowledgementGateway: acknowledgements,
          );

          final success = await executeBackgroundSendTask(
            compositionFactory: () async => BackgroundSendComposition(
              repository: repository,
              deviceDirectory: directory,
              coordinator: coordinator,
              scheduler: scheduler,
            ),
          );

          expect(success, isTrue);
          expect(repository.record?.status, SendQueueStatus.sent);
          expect(sendGateway.callCount, 1);
          expect(repository.closed, isTrue);
          if (platform == BackgroundSendPlatform.ios) {
            expect(scheduler.reconcileCalls, 1);
            expect(scheduler.lastHasRetryableWork, isFalse);
          } else {
            expect(scheduler.reconcileCalls, 0);
          }
          await acknowledgements.close();
        },
      );
    }

    test('asks Android to retry while offline work remains durable', () async {
      final now = DateTime.now().toUtc();
      final repository = _SingleRecordRepository(_record(now));
      final directory = LocalDeviceDirectory(
        store: InMemoryDeviceSettingsStore(
          defaultDeviceId: _offlineDevice.id,
          authorizedDevices: const [_offlineDevice],
        ),
        discoveryGateway: const _RestoringDiscoveryGateway(),
      );
      await directory.load();
      final coordinator = SendQueueDeliveryCoordinator(
        repository: repository,
        deviceDirectory: directory,
        sendGateway: const UnsupportedGarminSendGateway(),
        acknowledgementGateway: const UnsupportedGarminAcknowledgementGateway(),
      );

      final success = await executeBackgroundSendTask(
        compositionFactory: () async => BackgroundSendComposition(
          repository: repository,
          deviceDirectory: directory,
          coordinator: coordinator,
          scheduler: _RecordingScheduler(BackgroundSendPlatform.android),
        ),
      );

      expect(success, isFalse);
      expect(repository.record?.status, SendQueueStatus.pending);
      expect(
        repository.record?.failure?.code,
        SendQueueFailureCode.targetOffline,
      );
      expect(repository.closed, isTrue);
    });

    test(
      'does not claim a formerly-ready record when hydration is unavailable',
      () async {
        final now = DateTime.now().toUtc();
        final repository = _SingleRecordRepository(
          _record(now, device: _readyDevice),
        );
        final directory = LocalDeviceDirectory(
          store: InMemoryDeviceSettingsStore(
            defaultDeviceId: _readyDevice.id,
            authorizedDevices: const [_readyDevice],
          ),
        );
        await directory.load();
        final sendGateway = _CountingSendGateway();
        final coordinator = SendQueueDeliveryCoordinator(
          repository: repository,
          deviceDirectory: directory,
          sendGateway: sendGateway,
          acknowledgementGateway:
              const UnsupportedGarminAcknowledgementGateway(),
        );

        final success = await executeBackgroundSendTask(
          compositionFactory: () async => BackgroundSendComposition(
            repository: repository,
            deviceDirectory: directory,
            coordinator: coordinator,
            scheduler: _RecordingScheduler(BackgroundSendPlatform.android),
          ),
        );

        expect(success, isFalse);
        expect(repository.record?.status, SendQueueStatus.pending);
        expect(sendGateway.callCount, 0);
        expect(directory.devices.single.id, _readyDevice.id);
        expect(
          directory.devices.single.reachability,
          DeviceReachability.unknown,
        );
      },
    );

    test('iOS cancels scheduled work after an empty drain', () async {
      final repository = _SingleRecordRepository(null);
      final directory = LocalDeviceDirectory(
        store: InMemoryDeviceSettingsStore(),
      );
      await directory.load();
      final scheduler = _RecordingScheduler(BackgroundSendPlatform.ios);
      final coordinator = SendQueueDeliveryCoordinator(
        repository: repository,
        deviceDirectory: directory,
        sendGateway: const UnsupportedGarminSendGateway(),
        acknowledgementGateway: const UnsupportedGarminAcknowledgementGateway(),
      );

      final success = await executeBackgroundSendTask(
        compositionFactory: () async => BackgroundSendComposition(
          repository: repository,
          deviceDirectory: directory,
          coordinator: coordinator,
          scheduler: scheduler,
        ),
      );

      expect(success, isTrue);
      expect(scheduler.reconcileCalls, 1);
      expect(scheduler.lastHasRetryableWork, isFalse);
    });
  });
}

@pragma('vm:entry-point')
void _callbackDispatcher() {}

class _RestoringDiscoveryGateway implements GarminDeviceDiscoveryGateway {
  const _RestoringDiscoveryGateway();

  @override
  Stream<GarminDevice> get deviceUpdates => const Stream<GarminDevice>.empty();

  @override
  Future<List<GarminDevice>> discoverDevices() async => const [];

  @override
  Future<List<GarminDevice>> hydrateTransport(
    List<GarminDevice> authorizedDevices,
  ) async => authorizedDevices;
}

class _CountingSendGateway implements GarminSendGateway {
  var callCount = 0;

  @override
  Future<GarminSendResult> sendMessage({
    required GarminDeviceId deviceId,
    required MessageEnvelope message,
  }) async {
    callCount += 1;
    return const GarminSendResult(
      status: GarminSendStatus.deliveredToTransport,
      requiresAcknowledgement: true,
    );
  }
}

class _FakeWorkmanagerClient implements WorkmanagerClient {
  Object? initializeError;
  Object? scheduleError;
  Object? cancelError;
  var initializeCount = 0;
  var cancelCount = 0;
  final List<Duration> oneOffDelays = [];
  final List<Duration> periodicDelays = [];

  @override
  Future<void> initialize(Function callbackDispatcher) async {
    initializeCount += 1;
    if (initializeError case final error?) throw error;
  }

  @override
  Future<void> registerOneOff({required Duration initialDelay}) async {
    if (scheduleError case final error?) throw error;
    oneOffDelays.add(initialDelay);
  }

  @override
  Future<void> registerPeriodic({required Duration initialDelay}) async {
    if (scheduleError case final error?) throw error;
    periodicDelays.add(initialDelay);
  }

  @override
  Future<void> cancel() async {
    cancelCount += 1;
    if (cancelError case final error?) throw error;
  }
}

class _RecordingScheduler implements BackgroundSendScheduler {
  _RecordingScheduler(this.platform);

  @override
  final BackgroundSendPlatform platform;
  var reconcileCalls = 0;
  bool? lastHasRetryableWork;

  @override
  BackgroundSchedulingError? get lastError => null;

  @override
  Future<BackgroundSchedulingResult> initialize() async =>
      const BackgroundSchedulingResult.cancelled();

  @override
  Future<BackgroundSchedulingResult> reconcile({
    required bool hasRetryableWork,
    required DateTime? nextWakeUpAt,
    required DateTime now,
  }) async {
    reconcileCalls += 1;
    lastHasRetryableWork = hasRetryableWork;
    return hasRetryableWork
        ? const BackgroundSchedulingResult.scheduled()
        : const BackgroundSchedulingResult.cancelled();
  }
}

class _FakeAcknowledgementGateway implements GarminAcknowledgementGateway {
  final StreamController<WatchAcknowledgement> _controller =
      StreamController<WatchAcknowledgement>.broadcast();

  void add(WatchAcknowledgement acknowledgement) {
    _controller.add(acknowledgement);
  }

  Future<void> close() => _controller.close();

  @override
  Stream<WatchAcknowledgement> get acknowledgements => _controller.stream;

  @override
  Stream<GarminAcknowledgementDiagnostic> get diagnostics =>
      const Stream.empty();

  @override
  Stream<GarminAcknowledgementEvent> get events => const Stream.empty();
}

class _AcceptingSendGateway implements GarminSendGateway {
  _AcceptingSendGateway(this.acknowledgements, this.now);

  final _FakeAcknowledgementGateway acknowledgements;
  final DateTime now;
  var callCount = 0;

  @override
  Future<GarminSendResult> sendMessage({
    required GarminDeviceId deviceId,
    required MessageEnvelope message,
  }) async {
    callCount += 1;
    scheduleMicrotask(() {
      acknowledgements.add(
        WatchAcknowledgement(
          id: '01HX7Y8Z9ABCDEFGHJKMNPQS6Y',
          ackFor: message.id,
          status: WatchAcknowledgementStatus.accepted,
          receivedAt: now,
        ),
      );
    });
    return const GarminSendResult(
      status: GarminSendStatus.deliveredToTransport,
      requiresAcknowledgement: true,
    );
  }
}

class _SingleRecordRepository implements SendQueueRepository {
  _SingleRecordRepository(this.record);

  SendQueueRecord? record;
  var closed = false;

  @override
  List<QueueStorageDiagnostic> get diagnostics => const [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> close() async => closed = true;

  @override
  Future<SendQueueRecord> enqueue(SendQueueRecord record) async {
    this.record = record;
    return record;
  }

  @override
  Future<List<SendQueueRecord>> readAll() async => [?record];

  @override
  Future<SendQueueRecord?> findById(String messageId) async =>
      record?.id == messageId ? record : null;

  @override
  Future<SendQueueRecord?> claimNextEligible(DateTime now) async {
    final current = record;
    if (current == null) return null;
    return claimPending(current.id, now);
  }

  @override
  Future<SendQueueRecord?> claimPending(
    String messageId,
    DateTime now, {
    bool ignoreSchedule = false,
  }) async {
    final current = record;
    if (current == null ||
        current.id != messageId ||
        current.status != SendQueueStatus.pending ||
        (!ignoreSchedule && current.nextAttemptAt?.isAfter(now) == true)) {
      return null;
    }
    record = current.copyWith(
      status: SendQueueStatus.sending,
      updatedAt: now,
      attemptCount: current.attemptCount + 1,
      clearNextAttemptAt: true,
    );
    return record;
  }

  @override
  Future<SendQueueRecord> saveTransition(
    SendQueueRecord next, {
    required Set<SendQueueStatus> expectedStatuses,
  }) async {
    final current = record;
    if (current == null || !expectedStatuses.contains(current.status)) {
      throw const QueueStorageException(
        QueueStorageErrorCode.invalidTransition,
        'Invalid.',
      );
    }
    record = next;
    return next;
  }

  @override
  Future<SendQueueRecord> retryFailed(String messageId, DateTime now) async {
    throw UnimplementedError();
  }
}

SendQueueRecord _record(DateTime now, {GarminDevice device = _offlineDevice}) {
  return SendQueueRecord.pending(
    message: MessageEnvelope(
      id: '01HX7Y8Z9ABCDEFGHJKMNPQS6X',
      kind: MessageKind.point,
      createdAt: now,
      payload: const PointPayload(
        intent: PointIntent.navigate,
        latitude: 52.52,
        longitude: 13.405,
      ),
    ),
    createdAt: now,
    deviceId: device.id,
  );
}

const _readyDevice = GarminDevice(
  id: GarminDeviceId('physical:ready'),
  name: 'Ready watch',
  reachability: DeviceReachability.reachable,
  companionInstallState: CompanionInstallState.installed,
);

const _offlineDevice = GarminDevice(
  id: GarminDeviceId('physical:123'),
  name: 'Offline watch',
  reachability: DeviceReachability.offline,
  companionInstallState: CompanionInstallState.installed,
);
