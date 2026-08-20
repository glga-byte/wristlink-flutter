import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wristlink_flutter/app/wristlink_app.dart';
import 'package:wristlink_flutter/app/wristlink_app_composition.dart';
import 'package:wristlink_flutter/features/devices/data/in_memory_device_settings_store.dart';
import 'package:wristlink_flutter/features/devices/data/local_device_directory.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/devices/test_fixtures/device_fixtures.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_acknowledgement_gateway.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_device_discovery_gateway.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_send_gateway.dart';
import 'package:wristlink_flutter/features/payloads/message_contract.dart';
import 'package:wristlink_flutter/features/send_point/application/point_envelope_factory.dart';
import 'package:wristlink_flutter/features/send_point/data/point_draft_parser.dart';
import 'package:wristlink_flutter/features/send_point/data/shared_point_parser.dart';
import 'package:wristlink_flutter/features/send_point/domain/point_draft.dart';
import 'package:wristlink_flutter/features/send_point/presentation/manual_point_picker_screen.dart';
import 'package:wristlink_flutter/features/send_queue/application/send_queue_delivery_coordinator.dart';
import 'package:wristlink_flutter/features/send_queue/application/send_queue_delivery_service.dart';
import 'package:wristlink_flutter/features/send_queue/background/background_send_scheduler.dart';
import 'package:wristlink_flutter/features/send_queue/data/send_queue_repository.dart';
import 'package:wristlink_flutter/features/send_queue/data/sqlite_send_queue_repository.dart';
import 'package:wristlink_flutter/features/send_queue/domain/send_queue_record.dart';
import 'package:wristlink_flutter/features/send_queue/presentation/send_queue_controller.dart';

import '../support/send_point_ui_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  for (final intent in PointIntent.values) {
    testWidgets(
      'manual point creates and sends an accepted ${intent.wireName} envelope',
      (tester) async {
        final acknowledgements = _FakeAcknowledgementGateway();
        final sendGateway = _AcceptingSendGateway(acknowledgements);
        final repository = MemorySendQueueRepository();

        await tester.pumpWidget(
          WristLinkApp(
            dependencies: _dependencies(
              store: InMemoryDeviceSettingsStore(
                defaultDeviceId: fixtureReadyDevice.id,
                authorizedDevices: const [fixtureReadyDevice],
              ),
              repositoryFactory: () async => repository,
              sendGateway: sendGateway,
              acknowledgements: acknowledgements,
              messageId: _messageId(intent),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _openManualConfirmation(tester);
        if (intent == PointIntent.saveWaypoint) {
          await tester.tap(find.text('Save waypoint'));
          await tester.pump();
        }
        await tester.enterText(
          find.byKey(const Key('point-name-field')),
          'Integration trailhead',
        );
        await _submitPoint(tester, 'Send to watch');

        expect(sendGateway.messages, hasLength(1));
        final envelope = sendGateway.messages.single;
        final payload = envelope.payload as PointPayload;
        expect(envelope.id, _messageId(intent));
        expect(payload.intent, intent);
        expect(payload.latitude, closeTo(12.34567, 0.000001));
        expect(payload.longitude, closeTo(-45.67891, 0.000001));
        expect(payload.label, 'Integration trailhead');
        expect(
          (await repository.readAll()).single.status,
          SendQueueStatus.sent,
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('Point sent'), findsOneWidget);

        // Future.any does not cancel the coordinator's acknowledgement timeout
        // timer after an acknowledgement wins the race.
        await tester.pump(const Duration(seconds: 31));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await acknowledgements.close();
      },
    );
  }

  test(
    'offline point survives SQLite reopen and sends after reconnect',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'wristlink-point-e2e-',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      final databasePath = path.join(temporaryDirectory.path, 'queue.db');
      final firstNow = DateTime.utc(2026, 8, 20, 12);
      final offlineDevice = fixtureReadyDevice.copyWith(
        reachability: DeviceReachability.offline,
      );
      final firstRepository = SqliteSendQueueRepository(
        path: databasePath,
        databaseFactory: databaseFactoryFfi,
      );
      final firstSendGateway = _RecordingSendGateway();
      final offlineDirectory = LocalDeviceDirectory(
        store: InMemoryDeviceSettingsStore(
          defaultDeviceId: offlineDevice.id,
          authorizedDevices: [offlineDevice],
        ),
      );
      await offlineDirectory.load();
      final firstService = _deliveryService(
        repository: firstRepository,
        directory: offlineDirectory,
        sendGateway: firstSendGateway,
        acknowledgements: const UnsupportedGarminAcknowledgementGateway(),
        now: () => firstNow,
      );
      await firstService.initialize();
      final envelope = PointEnvelopeFactory(idFactory: (_) => _offlineMessageId)
          .create(
            draft: const PointDraft(
              latitude: 12.34567,
              longitude: -45.67891,
              label: 'Durable trailhead',
              source: PointDraftSource.manualMap,
            ),
            intent: PointIntent.navigate,
            editedLabel: 'Durable trailhead',
            createdAt: firstNow,
          );
      final submitted = await firstService.submit(
        SendQueueRecord.pending(
          message: envelope,
          createdAt: firstNow,
          deviceId: offlineDevice.id,
        ),
      );

      expect(submitted.status, SendQueueStatus.pending);
      expect(firstSendGateway.messages, isEmpty);
      final queued = (await firstRepository.readAll()).single;
      expect(queued.id, _offlineMessageId);
      expect(queued.status, SendQueueStatus.pending);
      expect(queued.deviceId, fixtureReadyDevice.id);
      await firstService.disposeService();
      offlineDirectory.dispose();

      final acknowledgements = _FakeAcknowledgementGateway();
      final reconnectGateway = _AcceptingSendGateway(acknowledgements);
      final restoredRepository = SqliteSendQueueRepository(
        path: databasePath,
        databaseFactory: databaseFactoryFfi,
      );
      final readyDirectory = LocalDeviceDirectory(
        store: InMemoryDeviceSettingsStore(
          defaultDeviceId: fixtureReadyDevice.id,
          authorizedDevices: const [fixtureReadyDevice],
        ),
      );
      await readyDirectory.load();
      final restoredService = _deliveryService(
        repository: restoredRepository,
        directory: readyDirectory,
        sendGateway: reconnectGateway,
        acknowledgements: acknowledgements,
        now: () => firstNow.add(const Duration(minutes: 1)),
      );
      await restoredService.initialize();

      final restored = (await restoredRepository.readAll()).single;
      expect(restored.id, queued.id);
      expect(restored.message.toJson(), queued.message.toJson());
      expect(restored.status, SendQueueStatus.sent);
      expect(restored.attemptCount, 1);
      expect(reconnectGateway.messages.single.id, queued.id);

      await restoredService.disposeService();
      readyDirectory.dispose();
      await acknowledgements.close();
    },
  );
}

SendQueueDeliveryService _deliveryService({
  required SendQueueRepository repository,
  required LocalDeviceDirectory directory,
  required GarminSendGateway sendGateway,
  required GarminAcknowledgementGateway acknowledgements,
  required DateTime Function() now,
}) {
  final controller = SendQueueController(repository);
  return SendQueueDeliveryService(
    repository: repository,
    controller: controller,
    coordinator: SendQueueDeliveryCoordinator(
      repository: repository,
      deviceDirectory: directory,
      sendGateway: sendGateway,
      acknowledgementGateway: acknowledgements,
      clock: now,
      delay: (_) => Completer<void>().future,
    ),
    deviceDirectory: directory,
    backgroundScheduler: const _NoOpBackgroundScheduler(),
    clock: now,
  );
}

WristLinkAppDependencies _dependencies({
  required InMemoryDeviceSettingsStore store,
  required SendQueueRepositoryFactory repositoryFactory,
  required GarminSendGateway sendGateway,
  required GarminAcknowledgementGateway acknowledgements,
  required String messageId,
}) {
  return WristLinkAppDependencies(
    deviceSettingsStore: store,
    discoveryGateway: const _ReadyHydrationGateway(),
    sendQueueRepositoryFactory: repositoryFactory,
    sendGateway: sendGateway,
    acknowledgementGateway: acknowledgements,
    backgroundScheduler: const _NoOpBackgroundScheduler(),
    sharedPointParser: const SharedPointParser(
      directParser: PointDraftParser(),
      shortLinkResolver: FixedShortLinkResolver(),
    ),
    envelopeFactory: PointEnvelopeFactory(idFactory: (_) => messageId),
    mapViewBuilder: _fakeMapBuilder,
  );
}

Future<void> _openManualConfirmation(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Manual point'), 160);
  await tester.tap(find.text('Manual point'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('move-map')));
  await tester.pump();
  await tester.tap(find.text('Use this point'));
  await tester.pumpAndSettle();
  expect(find.text('Send this point?'), findsOneWidget);
}

Future<void> _submitPoint(WidgetTester tester, String label) async {
  tester.testTextInput.hide();
  await tester.pump();
  final button = find.byKey(const Key('point-submit-button')).last;
  await tester.ensureVisible(button);
  await tester.drag(find.byType(ListView).last, const Offset(0, -100));
  await tester.pump();
  expect(find.descendant(of: button, matching: find.text(label)), findsOne);
  await tester.tapAt(tester.getTopLeft(button) + const Offset(100, 8));
  for (var index = 0; index < 10; index += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

class _ReadyHydrationGateway implements GarminDeviceDiscoveryGateway {
  const _ReadyHydrationGateway();

  @override
  Stream<GarminDevice> get deviceUpdates => const Stream.empty();

  @override
  Future<List<GarminDevice>> discoverDevices() async => const [];

  @override
  Future<List<GarminDevice>> hydrateTransport(
    List<GarminDevice> authorizedDevices,
  ) async => authorizedDevices;
}

Widget _fakeMapBuilder(
  BuildContext context,
  PointMapCoordinate initialTarget,
  PointMapViewportController viewportController,
  ValueChanged<PointMapCoordinate> onCameraChanged,
) {
  return Align(
    alignment: Alignment.topLeft,
    child: SafeArea(
      child: FilledButton(
        key: const Key('move-map'),
        onPressed: () =>
            onCameraChanged(const PointMapCoordinate(12.34567, -45.67891)),
        child: const Text('Move map'),
      ),
    ),
  );
}

class _AcceptingSendGateway implements GarminSendGateway {
  _AcceptingSendGateway(this.acknowledgements);

  final _FakeAcknowledgementGateway acknowledgements;
  final List<MessageEnvelope> messages = [];

  @override
  Future<GarminSendResult> sendMessage({
    required GarminDeviceId deviceId,
    required MessageEnvelope message,
  }) async {
    messages.add(message);
    scheduleMicrotask(() {
      acknowledgements.add(
        WatchAcknowledgement(
          id: _acknowledgementId,
          ackFor: message.id,
          status: WatchAcknowledgementStatus.accepted,
          receivedAt: DateTime.utc(2026, 8, 20, 12, 0, 1),
        ),
      );
    });
    return const GarminSendResult(
      status: GarminSendStatus.deliveredToTransport,
      requiresAcknowledgement: true,
    );
  }
}

class _RecordingSendGateway implements GarminSendGateway {
  final List<MessageEnvelope> messages = [];

  @override
  Future<GarminSendResult> sendMessage({
    required GarminDeviceId deviceId,
    required MessageEnvelope message,
  }) async {
    messages.add(message);
    return const GarminSendResult(
      status: GarminSendStatus.deliveredToTransport,
      requiresAcknowledgement: true,
    );
  }
}

class _FakeAcknowledgementGateway implements GarminAcknowledgementGateway {
  final StreamController<GarminAcknowledgementEvent> _events =
      StreamController.broadcast();

  void add(WatchAcknowledgement acknowledgement) {
    _events.add(GarminAcknowledgementReceived(acknowledgement));
  }

  Future<void> close() => _events.close();

  @override
  Stream<WatchAcknowledgement> get acknowledgements => _events.stream
      .where((event) => event is GarminAcknowledgementReceived)
      .cast<GarminAcknowledgementReceived>()
      .map((event) => event.acknowledgement);

  @override
  Stream<GarminAcknowledgementDiagnostic> get diagnostics => _events.stream
      .where((event) => event is GarminAcknowledgementDiagnostic)
      .cast<GarminAcknowledgementDiagnostic>();

  @override
  Stream<GarminAcknowledgementEvent> get events => _events.stream;
}

class _NoOpBackgroundScheduler implements BackgroundSendScheduler {
  const _NoOpBackgroundScheduler();

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
  }) async => hasRetryableWork
      ? const BackgroundSchedulingResult.scheduled()
      : const BackgroundSchedulingResult.cancelled();
}

String _messageId(PointIntent intent) => switch (intent) {
  PointIntent.navigate => '01ARZ3NDEKTSV4RRFFQ69G5FAV',
  PointIntent.saveWaypoint => '01ARZ3NDEKTSV4RRFFQ69G5FAW',
};

const _offlineMessageId = '01ARZ3NDEKTSV4RRFFQ69G5FAX';
const _acknowledgementId = '01ARZ3NDEKTSV4RRFFQ69G5FAZ';
