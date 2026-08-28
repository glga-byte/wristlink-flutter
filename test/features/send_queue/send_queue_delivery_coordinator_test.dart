import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/devices/domain/device_directory.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_acknowledgement_gateway.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_send_gateway.dart';
import 'package:wristlink_flutter/features/payloads/message_contract.dart';
import 'package:wristlink_flutter/features/send_queue/application/send_queue_delivery_coordinator.dart';
import 'package:wristlink_flutter/features/send_queue/application/send_queue_delivery_service.dart';
import 'package:wristlink_flutter/features/send_queue/background/background_send_scheduler.dart';
import 'package:wristlink_flutter/features/send_queue/data/send_queue_repository.dart';
import 'package:wristlink_flutter/features/send_queue/domain/send_queue_record.dart';
import 'package:wristlink_flutter/features/send_queue/presentation/send_queue_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SendQueueDeliveryCoordinator', () {
    test(
      'claims a ready target and persists an accepted acknowledgement',
      () async {
        final now = DateTime.utc(2026, 8, 20, 12);
        final repository = _MemoryQueueRepository();
        await repository.enqueue(_pointRecord(_id(1), now));
        final directory = _FakeDeviceDirectory([_readyDevice]);
        final acknowledgements = _FakeAcknowledgementGateway();
        final sendGateway = _FakeSendGateway((deviceId, message) async {
          scheduleMicrotask(() {
            acknowledgements.add(
              _ack(message.id, WatchAcknowledgementStatus.accepted),
            );
          });
          return GarminSendResult(
            status: GarminSendStatus.deliveredToTransport,
            requiresAcknowledgement: true,
          );
        });
        final coordinator = _coordinator(
          repository: repository,
          directory: directory,
          sendGateway: sendGateway,
          acknowledgements: acknowledgements,
          now: () => now,
        );

        await coordinator.start();
        final result = await coordinator.requestDrain(
          QueueDrainTrigger.startup,
        );

        final stored = (await repository.readAll()).single;
        expect(stored.status, SendQueueStatus.sent);
        expect(stored.attemptCount, 1);
        expect(stored.failure, isNull);
        expect(sendGateway.callCount, 1);
        expect(result.hasRetryableWork, isFalse);
        await coordinator.dispose();
        await acknowledgements.close();
      },
    );

    test(
      'keeps offline targets pending and fails missing companions',
      () async {
        final now = DateTime.utc(2026, 8, 20, 12);
        final repository = _MemoryQueueRepository();
        await repository.enqueue(
          _pointRecord(_id(1), now, deviceId: _offlineDevice.id),
        );
        await repository.enqueue(
          _pointRecord(
            _id(2),
            now.add(const Duration(seconds: 1)),
            deviceId: _missingCompanionDevice.id,
          ),
        );
        final coordinator = _coordinator(
          repository: repository,
          directory: _FakeDeviceDirectory([
            _offlineDevice,
            _missingCompanionDevice,
          ]),
          sendGateway: _FakeSendGateway.success(),
          acknowledgements: _FakeAcknowledgementGateway(),
          now: () => now,
        );

        await coordinator.start();
        final result = await coordinator.requestDrain(
          QueueDrainTrigger.startup,
        );
        final records = {
          for (final record in await repository.readAll()) record.id: record,
        };

        expect(records[_id(1)]!.status, SendQueueStatus.pending);
        expect(
          records[_id(1)]!.failure?.code,
          SendQueueFailureCode.targetOffline,
        );
        expect(
          records[_id(1)]!.nextAttemptAt,
          now.add(const Duration(seconds: 15)),
        );
        expect(records[_id(2)]!.status, SendQueueStatus.failed);
        expect(
          records[_id(2)]!.failure?.code,
          SendQueueFailureCode.companionMissing,
        );
        expect(result.hasRetryableWork, isTrue);
        await coordinator.dispose();
      },
    );

    test('classifies transient and terminal transport failures', () async {
      final now = DateTime.utc(2026, 8, 20, 12);
      final repository = _MemoryQueueRepository();
      await repository.enqueue(_pointRecord(_id(1), now));
      await repository.enqueue(
        _pointRecord(_id(2), now.add(const Duration(seconds: 1))),
      );
      final coordinator = _coordinator(
        repository: repository,
        directory: _FakeDeviceDirectory([_readyDevice]),
        sendGateway: _FakeSendGateway((deviceId, message) async {
          if (message.id == _id(1)) {
            throw const GarminSendError(
              GarminSendErrorCode.sdkUnavailable,
              'SDK unavailable.',
            );
          }
          throw const GarminSendError(
            GarminSendErrorCode.appNotInstalled,
            'Companion missing.',
          );
        }),
        acknowledgements: _FakeAcknowledgementGateway(),
        now: () => now,
      );

      await coordinator.start();
      await coordinator.requestDrain(QueueDrainTrigger.foreground);
      final records = {
        for (final record in await repository.readAll()) record.id: record,
      };

      expect(records[_id(1)]!.status, SendQueueStatus.pending);
      expect(
        records[_id(1)]!.failure?.code,
        SendQueueFailureCode.sdkUnavailable,
      );
      expect(
        records[_id(1)]!.nextAttemptAt,
        now.add(const Duration(seconds: 15)),
      );
      expect(records[_id(2)]!.status, SendQueueStatus.failed);
      expect(
        records[_id(2)]!.failure?.code,
        SendQueueFailureCode.companionMissing,
      );
      await coordinator.dispose();
    });

    for (final status in WatchAcknowledgementStatus.values) {
      test(
        'handles ${status.wireName} acknowledgements idempotently',
        () async {
          final now = DateTime.utc(2026, 8, 20, 12);
          final repository = _MemoryQueueRepository();
          await repository.enqueue(_pointRecord(_id(1), now));
          final acknowledgements = _FakeAcknowledgementGateway();
          final coordinator = _coordinator(
            repository: repository,
            directory: _FakeDeviceDirectory([_readyDevice]),
            sendGateway: _FakeSendGateway((deviceId, message) async {
              scheduleMicrotask(
                () => acknowledgements.add(_ack(message.id, status)),
              );
              return GarminSendResult(
                status: GarminSendStatus.deliveredToTransport,
                requiresAcknowledgement: true,
              );
            }),
            acknowledgements: acknowledgements,
            now: () => now,
          );

          await coordinator.start();
          await coordinator.requestDrain(QueueDrainTrigger.submission);
          final stored = (await repository.readAll()).single;
          final expectedStatus = switch (status.outcome) {
            WatchAcknowledgementOutcome.sent => SendQueueStatus.sent,
            WatchAcknowledgementOutcome.failed => SendQueueStatus.failed,
            WatchAcknowledgementOutcome.retryable => SendQueueStatus.pending,
          };
          expect(stored.status, expectedStatus);
          if (status.outcome == WatchAcknowledgementOutcome.retryable) {
            expect(stored.nextAttemptAt, now.add(const Duration(seconds: 15)));
          }

          acknowledgements.add(
            _ack(stored.id, status, acknowledgementId: _id(8)),
          );
          await pumpEventQueue();
          expect((await repository.readAll()).single.status, expectedStatus);
          await coordinator.dispose();
          await acknowledgements.close();
        },
      );
    }

    test('acknowledgement timeout requires explicit retry', () async {
      final now = DateTime.utc(2026, 8, 20, 12);
      final repository = _MemoryQueueRepository();
      await repository.enqueue(_pointRecord(_id(1), now));
      final coordinator = SendQueueDeliveryCoordinator(
        repository: repository,
        deviceDirectory: _FakeDeviceDirectory([_readyDevice]),
        sendGateway: _FakeSendGateway.success(requiresAcknowledgement: true),
        acknowledgementGateway: _FakeAcknowledgementGateway(),
        clock: () => now,
        delay: (_) async {},
      );

      await coordinator.start();
      await coordinator.requestDrain(QueueDrainTrigger.submission);
      final timedOut = (await repository.readAll()).single;
      expect(timedOut.status, SendQueueStatus.failed);
      expect(
        timedOut.failure?.code,
        SendQueueFailureCode.acknowledgementTimeout,
      );

      final retried = await repository.retryFailed(timedOut.id, now);
      expect(retried.id, timedOut.id);
      expect(retried.status, SendQueueStatus.pending);
      await coordinator.dispose();
    });

    test(
      'overlapping triggers share one drain and one transport attempt',
      () async {
        final now = DateTime.utc(2026, 8, 20, 12);
        final repository = _MemoryQueueRepository();
        await repository.enqueue(_pointRecord(_id(1), now));
        final sendStarted = Completer<void>();
        final finishSend = Completer<GarminSendResult>();
        final acknowledgements = _FakeAcknowledgementGateway();
        final sendGateway = _FakeSendGateway((deviceId, message) {
          sendStarted.complete();
          return finishSend.future;
        });
        final coordinator = _coordinator(
          repository: repository,
          directory: _FakeDeviceDirectory([_readyDevice]),
          sendGateway: sendGateway,
          acknowledgements: acknowledgements,
          now: () => now,
        );

        await coordinator.start();
        final first = coordinator.requestDrain(QueueDrainTrigger.startup);
        await sendStarted.future;
        final second = coordinator.requestDrain(QueueDrainTrigger.foreground);
        expect(identical(first, second), isTrue);
        finishSend.complete(
          const GarminSendResult(
            status: GarminSendStatus.deliveredToTransport,
            requiresAcknowledgement: true,
          ),
        );
        acknowledgements.add(_ack(_id(1), WatchAcknowledgementStatus.accepted));
        await Future.wait([first, second]);

        expect(sendGateway.callCount, 1);
        expect(
          (await repository.readAll()).single.status,
          SendQueueStatus.sent,
        );
        await coordinator.dispose();
        await acknowledgements.close();
      },
    );

    test('recovers expired interrupted sends as unknown delivery', () async {
      final now = DateTime.utc(2026, 8, 20, 12);
      final repository = _MemoryQueueRepository();
      final sending =
          _pointRecord(
            _id(1),
            now.subtract(const Duration(minutes: 2)),
          ).copyWith(
            status: SendQueueStatus.sending,
            attemptCount: 1,
            acknowledgementDeadline: now.subtract(const Duration(minutes: 1)),
          );
      repository.seed(sending);
      final acknowledgements = _FakeAcknowledgementGateway();
      final coordinator = _coordinator(
        repository: repository,
        directory: _FakeDeviceDirectory([_readyDevice]),
        sendGateway: _FakeSendGateway.success(),
        acknowledgements: acknowledgements,
        now: () => now,
      );

      await coordinator.start();
      final recovered = (await repository.readAll()).single;
      expect(recovered.status, SendQueueStatus.failed);
      expect(
        recovered.failure?.code,
        SendQueueFailureCode.deliveryOutcomeUnknown,
      );

      final diagnostics = <DeliveryDiagnostic>[];
      final subscription = coordinator.diagnostics.listen(diagnostics.add);
      acknowledgements.add(_ack(_id(9), WatchAcknowledgementStatus.accepted));
      await pumpEventQueue();
      expect(
        diagnostics.single.code,
        DeliveryDiagnosticCode.unknownAcknowledgement,
      );
      await subscription.cancel();
      await coordinator.dispose();
      await acknowledgements.close();
    });

    test(
      'leaves an acknowledged send recoverable at a platform deadline',
      () async {
        var now = DateTime.utc(2026, 8, 20, 12);
        final executionDeadline = now.add(const Duration(seconds: 5));
        final repository = _MemoryQueueRepository();
        await repository.enqueue(_pointRecord(_id(1), now));
        final coordinator = SendQueueDeliveryCoordinator(
          repository: repository,
          deviceDirectory: _FakeDeviceDirectory([_readyDevice]),
          sendGateway: _FakeSendGateway.success(requiresAcknowledgement: true),
          acknowledgementGateway: _FakeAcknowledgementGateway(),
          clock: () => now,
          delay: (_) async {
            now = executionDeadline;
          },
        );

        await coordinator.start();
        final result = await coordinator.requestDrain(
          QueueDrainTrigger.background,
          deadline: executionDeadline,
        );

        expect(
          (await repository.readAll()).single.status,
          SendQueueStatus.sending,
        );
        expect(result.hasRetryableWork, isTrue);
        await coordinator.dispose();
      },
    );
  });

  group('SendQueueDeliveryService', () {
    test(
      'foreground hydration recovers failed startup before draining',
      () async {
        final now = DateTime.utc(2026, 8, 20, 12);
        final repository = _MemoryQueueRepository();
        await repository.enqueue(_pointRecord(_id(1), now));
        final directory = _FakeDeviceDirectory(
          [_unknownDevice],
          hydrationResults: [
            const DeviceRefreshFailure(
              GarminDiscoveryError(
                GarminDiscoveryErrorCode.sdkUnavailable,
                'SDK unavailable during startup.',
              ),
            ),
            const DeviceRefreshSuccess([_readyDevice]),
          ],
        );
        expect(await directory.hydrateTransport(), isA<DeviceRefreshFailure>());
        final acknowledgements = _FakeAcknowledgementGateway();
        final sendGateway = _FakeSendGateway((deviceId, message) async {
          scheduleMicrotask(() {
            acknowledgements.add(
              _ack(message.id, WatchAcknowledgementStatus.accepted),
            );
          });
          return const GarminSendResult(
            status: GarminSendStatus.deliveredToTransport,
            requiresAcknowledgement: true,
          );
        });
        final service = SendQueueDeliveryService(
          repository: repository,
          controller: SendQueueController(repository),
          coordinator: _coordinator(
            repository: repository,
            directory: directory,
            sendGateway: sendGateway,
            acknowledgements: acknowledgements,
            now: () => now,
          ),
          deviceDirectory: directory,
          backgroundScheduler: _FakeBackgroundScheduler(),
          clock: () => now,
        );

        await service.initialize();
        expect(sendGateway.callCount, 0);
        expect(
          (await repository.readAll()).single.status,
          SendQueueStatus.pending,
        );

        await Future.wait([
          service.trigger(QueueDrainTrigger.foreground),
          service.trigger(QueueDrainTrigger.foreground),
        ]);

        expect(directory.hydrationCallCount, 2);
        expect(sendGateway.callCount, 1);
        expect(
          (await repository.readAll()).single.status,
          SendQueueStatus.sent,
        );
        await service.disposeService();
        await acknowledgements.close();
      },
    );

    test(
      'readiness changes bypass backoff through the shared drain path',
      () async {
        final now = DateTime.utc(2026, 8, 20, 12);
        final repository = _MemoryQueueRepository();
        await repository.enqueue(_pointRecord(_id(1), now));
        final directory = _FakeDeviceDirectory([_offlineDevice]);
        final acknowledgements = _FakeAcknowledgementGateway();
        final coordinator = _coordinator(
          repository: repository,
          directory: directory,
          sendGateway: _FakeSendGateway((deviceId, message) async {
            scheduleMicrotask(() {
              acknowledgements.add(
                _ack(message.id, WatchAcknowledgementStatus.accepted),
              );
            });
            return const GarminSendResult(
              status: GarminSendStatus.deliveredToTransport,
              requiresAcknowledgement: true,
            );
          }),
          acknowledgements: acknowledgements,
          now: () => now,
        );
        final scheduler = _FakeBackgroundScheduler();
        final service = SendQueueDeliveryService(
          repository: repository,
          controller: SendQueueController(repository),
          coordinator: coordinator,
          deviceDirectory: directory,
          backgroundScheduler: scheduler,
          clock: () => now,
        );

        await service.initialize();
        expect(
          (await repository.readAll()).single.status,
          SendQueueStatus.pending,
        );
        expect((await repository.readAll()).single.nextAttemptAt, isNotNull);

        directory.replaceDevices([_readyDevice]);
        await pumpEventQueue(times: 20);

        expect(
          (await repository.readAll()).single.status,
          SendQueueStatus.sent,
        );
        expect(scheduler.reconcileCount, greaterThanOrEqualTo(2));
        await service.disposeService();
        await acknowledgements.close();
      },
    );

    test('submission and explicit retry retain the same message id', () async {
      final now = DateTime.utc(2026, 8, 20, 12);
      final repository = _MemoryQueueRepository();
      final directory = _FakeDeviceDirectory([_readyDevice]);
      final acknowledgements = _FakeAcknowledgementGateway();
      final service = SendQueueDeliveryService(
        repository: repository,
        controller: SendQueueController(repository),
        coordinator: _coordinator(
          repository: repository,
          directory: directory,
          sendGateway: _FakeSendGateway((deviceId, message) async {
            scheduleMicrotask(() {
              acknowledgements.add(
                _ack(message.id, WatchAcknowledgementStatus.accepted),
              );
            });
            return const GarminSendResult(
              status: GarminSendStatus.deliveredToTransport,
              requiresAcknowledgement: true,
            );
          }),
          acknowledgements: acknowledgements,
          now: () => now,
        ),
        deviceDirectory: directory,
        backgroundScheduler: _FakeBackgroundScheduler(),
        clock: () => now,
      );

      await service.initialize();
      final sent = await service.submit(_pointRecord(_id(1), now));
      expect(sent.status, SendQueueStatus.sent);
      repository.seed(
        sent.copyWith(
          status: SendQueueStatus.failed,
          failure: const SendQueueFailure(
            code: SendQueueFailureCode.deliveryOutcomeUnknown,
            message: 'Unknown.',
            isTransient: false,
          ),
        ),
      );
      final retried = await service.retry(sent.id);

      expect(retried.id, sent.id);
      expect(retried.status, SendQueueStatus.sent);
      await service.disposeService();
      await acknowledgements.close();
    });
  });

  test('retry policy caps exponential delays', () {
    const policy = DeliveryRetryPolicy(
      initialBackoff: Duration(seconds: 10),
      maximumBackoff: Duration(seconds: 40),
    );

    expect(policy.backoffForAttempt(1), const Duration(seconds: 10));
    expect(policy.backoffForAttempt(2), const Duration(seconds: 20));
    expect(policy.backoffForAttempt(3), const Duration(seconds: 40));
    expect(policy.backoffForAttempt(20), const Duration(seconds: 40));
  });
}

SendQueueDeliveryCoordinator _coordinator({
  required _MemoryQueueRepository repository,
  required _FakeDeviceDirectory directory,
  required GarminSendGateway sendGateway,
  required GarminAcknowledgementGateway acknowledgements,
  required DateTime Function() now,
}) {
  return SendQueueDeliveryCoordinator(
    repository: repository,
    deviceDirectory: directory,
    sendGateway: sendGateway,
    acknowledgementGateway: acknowledgements,
    clock: now,
    delay: (_) => Completer<void>().future,
  );
}

class _MemoryQueueRepository implements SendQueueRepository {
  final Map<String, SendQueueRecord> _records = {};

  void seed(SendQueueRecord record) => _records[record.id] = record;

  @override
  List<QueueStorageDiagnostic> get diagnostics => const [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<SendQueueRecord> enqueue(SendQueueRecord record) async {
    if (_records.containsKey(record.id)) {
      throw const QueueStorageException(
        QueueStorageErrorCode.duplicateMessageId,
        'Duplicate.',
      );
    }
    _records[record.id] = record;
    return record;
  }

  @override
  Future<List<SendQueueRecord>> readAll() async {
    final records = _records.values.toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return List.unmodifiable(records);
  }

  @override
  Future<void> removeQuarantinedRows(
    Set<QueueStorageDiagnosticId> diagnosticIds,
  ) async {}

  @override
  Future<SendQueueRecord?> findById(String messageId) async =>
      _records[messageId];

  @override
  Future<SendQueueRecord?> claimNextEligible(DateTime now) async {
    final eligible =
        _records.values
            .where(
              (record) =>
                  record.status == SendQueueStatus.pending &&
                  (record.nextAttemptAt == null ||
                      !record.nextAttemptAt!.isAfter(now)),
            )
            .toList()
          ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    if (eligible.isEmpty) return null;
    return claimPending(eligible.first.id, now);
  }

  @override
  Future<SendQueueRecord?> claimPending(
    String messageId,
    DateTime now, {
    bool ignoreSchedule = false,
  }) async {
    final record = _records[messageId];
    if (record == null || record.status != SendQueueStatus.pending) return null;
    if (!ignoreSchedule && record.nextAttemptAt?.isAfter(now) == true) {
      return null;
    }
    final claimed = record.copyWith(
      status: SendQueueStatus.sending,
      updatedAt: now,
      attemptCount: record.attemptCount + 1,
      clearNextAttemptAt: true,
    );
    _records[messageId] = claimed;
    return claimed;
  }

  @override
  Future<SendQueueRecord> saveTransition(
    SendQueueRecord record, {
    required Set<SendQueueStatus> expectedStatuses,
  }) async {
    final current = _records[record.id];
    if (current == null || !expectedStatuses.contains(current.status)) {
      throw const QueueStorageException(
        QueueStorageErrorCode.invalidTransition,
        'Invalid transition.',
      );
    }
    _records[record.id] = record;
    return record;
  }

  @override
  Future<SendQueueRecord> retryFailed(String messageId, DateTime now) async {
    final record = _records[messageId];
    if (record == null || record.status != SendQueueStatus.failed) {
      throw const QueueStorageException(
        QueueStorageErrorCode.invalidTransition,
        'Not failed.',
      );
    }
    final retried = record.copyWith(
      status: SendQueueStatus.pending,
      updatedAt: now,
      clearFailure: true,
      clearNextAttemptAt: true,
      clearAcknowledgementDeadline: true,
    );
    _records[messageId] = retried;
    return retried;
  }
}

class _FakeDeviceDirectory extends ChangeNotifier
    implements DeviceDirectoryController {
  _FakeDeviceDirectory(
    this._devices, {
    List<DeviceRefreshResult> hydrationResults = const [],
  }) : _hydrationResults = List.of(hydrationResults);

  List<GarminDevice> _devices;
  final List<DeviceRefreshResult> _hydrationResults;
  var hydrationCallCount = 0;

  void replaceDevices(List<GarminDevice> devices) {
    _devices = devices;
    notifyListeners();
  }

  @override
  List<GarminDevice> get devices => List.unmodifiable(_devices);

  @override
  GarminDeviceId? get defaultDeviceId => _devices.firstOrNull?.id;

  @override
  DeviceDirectoryEmptyReason? get emptyReason => null;

  @override
  GarminDiscoveryError? get lastRefreshError => null;

  @override
  Future<DeviceRefreshResult> hydrateTransport() async {
    hydrationCallCount += 1;
    final result = _hydrationResults.isEmpty
        ? DeviceRefreshSuccess(devices)
        : _hydrationResults.removeAt(0);
    if (result is DeviceRefreshSuccess) {
      replaceDevices(result.devices);
    }
    return result;
  }

  @override
  Future<DeviceRefreshResult> refreshDevices() async =>
      DeviceRefreshSuccess(devices);

  @override
  SendTargetResolution resolveSendTarget() =>
      _devices.firstOrNull?.isReady == true
      ? SendTargetReady(_devices.first)
      : const SendTargetUnavailable(
          SendTargetUnavailableReason.defaultDeviceOffline,
        );

  @override
  Future<void> setDefaultDevice(GarminDeviceId id) async {}
}

class _FakeSendGateway implements GarminSendGateway {
  _FakeSendGateway(this._send);

  factory _FakeSendGateway.success({bool requiresAcknowledgement = false}) {
    return _FakeSendGateway((deviceId, message) async {
      return GarminSendResult(
        status: GarminSendStatus.deliveredToTransport,
        requiresAcknowledgement: requiresAcknowledgement,
      );
    });
  }

  final Future<GarminSendResult> Function(
    GarminDeviceId deviceId,
    MessageEnvelope message,
  )
  _send;
  var callCount = 0;

  @override
  Future<GarminSendResult> sendMessage({
    required GarminDeviceId deviceId,
    required MessageEnvelope message,
  }) {
    callCount += 1;
    return _send(deviceId, message);
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
  Stream<GarminAcknowledgementEvent> get events =>
      acknowledgements.map(GarminAcknowledgementReceived.new);
}

class _FakeBackgroundScheduler implements BackgroundSendScheduler {
  var reconcileCount = 0;

  @override
  BackgroundSchedulingError? get lastError => null;

  @override
  BackgroundSendPlatform get platform => BackgroundSendPlatform.android;

  @override
  Future<BackgroundSchedulingResult> initialize() async =>
      const BackgroundSchedulingResult.cancelled();

  @override
  Future<BackgroundSchedulingResult> reconcile({
    required bool hasRetryableWork,
    required DateTime? nextWakeUpAt,
    required DateTime now,
  }) async {
    reconcileCount += 1;
    return hasRetryableWork
        ? const BackgroundSchedulingResult.scheduled()
        : const BackgroundSchedulingResult.cancelled();
  }
}

SendQueueRecord _pointRecord(
  String id,
  DateTime now, {
  GarminDeviceId deviceId = const GarminDeviceId('physical:123'),
}) {
  return SendQueueRecord.pending(
    message: MessageEnvelope(
      id: id,
      kind: MessageKind.point,
      createdAt: now,
      payload: const PointPayload(
        intent: PointIntent.navigate,
        latitude: 52.52,
        longitude: 13.405,
        label: 'Point',
      ),
    ),
    createdAt: now,
    deviceId: deviceId,
  );
}

WatchAcknowledgement _ack(
  String messageId,
  WatchAcknowledgementStatus status, {
  String acknowledgementId = '01HX7Y8Z9ABCDEFGHJKMNPQS9X',
}) {
  return WatchAcknowledgement(
    id: acknowledgementId,
    ackFor: messageId,
    status: status,
    receivedAt: DateTime.utc(2026, 8, 20, 12, 0, 1),
    reason: status == WatchAcknowledgementStatus.retryable ? 'Busy.' : null,
  );
}

String _id(int suffix) => '01HX7Y8Z9ABCDEFGHJKMNPQS${suffix}X';

const _readyDevice = GarminDevice(
  id: GarminDeviceId('physical:123'),
  name: 'Ready watch',
  reachability: DeviceReachability.reachable,
  companionInstallState: CompanionInstallState.installed,
);

const _unknownDevice = GarminDevice(
  id: GarminDeviceId('physical:123'),
  name: 'Known watch awaiting hydration',
  reachability: DeviceReachability.unknown,
  companionInstallState: CompanionInstallState.installed,
);

const _offlineDevice = GarminDevice(
  id: GarminDeviceId('physical:123'),
  name: 'Offline watch',
  reachability: DeviceReachability.offline,
  companionInstallState: CompanionInstallState.installed,
);

const _missingCompanionDevice = GarminDevice(
  id: GarminDeviceId('physical:456'),
  name: 'Missing companion',
  reachability: DeviceReachability.reachable,
  companionInstallState: CompanionInstallState.missing,
);
