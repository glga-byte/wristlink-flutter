import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/app/wristlink_app.dart';
import 'package:wristlink_flutter/app/wristlink_app_composition.dart';
import 'package:wristlink_flutter/features/devices/data/in_memory_device_settings_store.dart';
import 'package:wristlink_flutter/features/devices/data/local_device_directory.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/devices/test_fixtures/device_fixtures.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_acknowledgement_gateway.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_send_gateway.dart';
import 'package:wristlink_flutter/features/payloads/message_contract.dart';
import 'package:wristlink_flutter/features/send_point/application/point_envelope_factory.dart';
import 'package:wristlink_flutter/features/send_point/data/point_draft_parser.dart';
import 'package:wristlink_flutter/features/send_point/data/shared_point_parser.dart';
import 'package:wristlink_flutter/features/send_point/domain/point_draft.dart';
import 'package:wristlink_flutter/features/send_point/domain/point_parse_result.dart';
import 'package:wristlink_flutter/features/send_point/presentation/manual_point_picker_screen.dart';
import 'package:wristlink_flutter/features/send_point/presentation/point_confirmation_screen.dart';
import 'package:wristlink_flutter/features/send_point/presentation/point_parse_recovery_screen.dart';
import 'package:wristlink_flutter/features/send_point/presentation/point_status_screen.dart';
import 'package:wristlink_flutter/features/send_point/share/shared_content_gateway.dart';
import 'package:wristlink_flutter/features/send_queue/domain/send_queue_record.dart';
import 'package:wristlink_flutter/features/send_queue/presentation/queue_screen.dart';
import 'package:wristlink_flutter/features/send_queue/presentation/send_queue_controller.dart';

import '../../support/send_point_ui_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'manual picker follows camera center and returns a manual draft',
    (tester) async {
      PointDraft? result;
      await _pumpRoute<PointDraft>(
        tester,
        ManualPointPickerScreen(mapViewBuilder: _fakeMapBuilder),
        onResult: (value) => result = value,
      );

      await tester.tap(find.byKey(const Key('move-map')));
      await tester.pump();
      expect(find.text('12.3457, -45.6789'), findsOneWidget);

      await tester.tap(find.text('Use this point'));
      await tester.pumpAndSettle();

      expect(result?.source, PointDraftSource.manualMap);
      expect(result?.latitude, closeTo(12.34567, 0.00001));
      expect(result?.longitude, closeTo(-45.67891, 0.00001));
      expect(result?.label, 'Dropped pin');
    },
  );

  testWidgets('manual picker remains usable after location permission denial', (
    tester,
  ) async {
    await _pumpRoute<PointDraft>(
      tester,
      ManualPointPickerScreen(
        mapViewBuilder: _fakeMapBuilder,
        currentLocationGateway: const _DeniedLocationGateway(),
      ),
    );

    await tester.tap(find.byTooltip('Use current location'));
    await tester.pumpAndSettle();
    expect(find.textContaining('permission was denied'), findsOneWidget);
    expect(find.text('Use this point'), findsOneWidget);
  });

  testWidgets('manual picker uses iOS-native actions on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _pumpRoute<PointDraft>(
      tester,
      ManualPointPickerScreen(mapViewBuilder: _fakeMapBuilder),
    );

    expect(find.widgetWithText(CupertinoButton, 'Cancel'), findsOneWidget);
    expect(
      find.widgetWithText(CupertinoButton, 'Use this point'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('confirmation edits the name and creates Save waypoint intent', (
    tester,
  ) async {
    final directory = await _directory(
      defaultDevice: fixtureReadyDevice,
      devices: const [fixtureReadyDevice],
    );
    final actions = FakePointQueueActions(resultStatus: SendQueueStatus.sent);
    SendQueueRecord? result;
    await _pumpRoute<SendQueueRecord>(
      tester,
      PointConfirmationScreen(
        draft: _draft,
        deviceDirectory: directory,
        envelopeFactory: PointEnvelopeFactory(idFactory: (_) => _messageId),
        queueActions: actions,
        onOpenDevices: () {},
      ),
      onResult: (value) => result = value,
    );

    await tester.enterText(
      find.byKey(const Key('point-name-field')),
      'Edited trailhead',
    );
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.text('Save waypoint'));
    final submitButton = find.byKey(const Key('point-submit-button')).last;
    await tester.ensureVisible(submitButton);
    await tester.drag(find.byType(ListView).last, const Offset(0, -100));
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(submitButton) + const Offset(100, 8));
    await tester.pumpAndSettle();

    final payload = result?.message.payload as PointPayload?;
    expect(payload?.intent, PointIntent.saveWaypoint);
    expect(payload?.label, 'Edited trailhead');
    expect(actions.submissions, hasLength(1));
    directory.dispose();
  });

  testWidgets('confirmation supports Navigate and all readiness variants', (
    tester,
  ) async {
    final offline = fixtureOfflineDevice.copyWith(
      companionInstallState: CompanionInstallState.installed,
    );
    final directory = await _directory(
      defaultDevice: offline,
      devices: [offline],
    );
    final actions = FakePointQueueActions();
    await _pumpRoute<SendQueueRecord>(
      tester,
      PointConfirmationScreen(
        draft: _draft,
        deviceDirectory: directory,
        envelopeFactory: PointEnvelopeFactory(idFactory: (_) => _messageId),
        queueActions: actions,
        onOpenDevices: () {},
      ),
    );

    expect(find.text('Queue point'), findsOneWidget);
    final queueSubmitButton = find.byKey(const Key('point-submit-button')).last;
    await tester.ensureVisible(queueSubmitButton);
    await tester.pump();
    expect(
      find.textContaining('retry when the watch reconnects'),
      findsOneWidget,
    );
    await tester.tap(queueSubmitButton);
    await tester.pumpAndSettle();
    expect(
      (actions.submissions.single.message.payload as PointPayload).intent,
      PointIntent.navigate,
    );
    directory.dispose();

    final noDefault = await _directory(devices: const [fixtureReadyDevice]);
    await _pumpRoute<SendQueueRecord>(
      tester,
      PointConfirmationScreen(
        draft: _draft,
        deviceDirectory: noDefault,
        envelopeFactory: PointEnvelopeFactory(),
        queueActions: FakePointQueueActions(),
        onOpenDevices: () {},
      ),
    );
    expect(find.text('Choose default watch'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pump();
    final disabledSubmit = find.byKey(const Key('point-submit-button')).last;
    await tester.ensureVisible(disabledSubmit);
    await tester.pump();
    expect(tester.widget<FilledButton>(disabledSubmit).onPressed, isNull);
    noDefault.dispose();
  });

  testWidgets('confirmation rejects empty and over-budget names', (
    tester,
  ) async {
    final directory = await _directory(
      defaultDevice: fixtureReadyDevice,
      devices: const [fixtureReadyDevice],
    );
    final actions = FakePointQueueActions();
    await _pumpRoute<SendQueueRecord>(
      tester,
      PointConfirmationScreen(
        draft: _draft,
        deviceDirectory: directory,
        envelopeFactory: PointEnvelopeFactory(idFactory: (_) => _messageId),
        queueActions: actions,
        onOpenDevices: () {},
      ),
    );

    await tester.enterText(find.byKey(const Key('point-name-field')), '   ');
    tester.testTextInput.hide();
    await tester.pump();
    final submitButton = find.byKey(const Key('point-submit-button')).last;
    await tester.ensureVisible(submitButton);
    await tester.drag(find.byType(ListView).last, const Offset(0, -100));
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(submitButton) + const Offset(100, 8));
    await tester.pump();
    expect(find.text('Enter a point name.'), findsOneWidget);

    await _pumpRoute<SendQueueRecord>(
      tester,
      PointConfirmationScreen(
        draft: _draft.copyWith(label: List.filled(1200, 'x').join()),
        deviceDirectory: directory,
        envelopeFactory: PointEnvelopeFactory(idFactory: (_) => _messageId),
        queueActions: actions,
        onOpenDevices: () {},
      ),
    );
    final oversizedSubmit = find.byKey(const Key('point-submit-button')).last;
    await tester.ensureVisible(oversizedSubmit);
    await tester.pump();
    await tester.tapAt(
      tester.getTopLeft(oversizedSubmit) + const Offset(100, 8),
    );
    await tester.pump();
    expect(find.textContaining('too large to send'), findsOneWidget);
    expect(actions.submissions, isEmpty);
    directory.dispose();
  });

  testWidgets(
    'parse recovery copies text, validates, and returns manual coordinates',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
      PointDraft? result;
      const original = 'Cafe near the lake — see this place on Maps';
      await _pumpRoute<PointDraft>(
        tester,
        PointParseRecoveryScreen(
          failure: const PointParseFailure(
            code: PointParseErrorCode.noCoordinates,
            originalText: original,
            message: 'No coordinates found.',
          ),
          parser: const SharedPointParser(
            directParser: PointDraftParser(),
            shortLinkResolver: FixedShortLinkResolver(),
          ),
        ),
        onResult: (value) => result = value,
      );

      await tester.tap(find.text('Copy shared text'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Shared text copied.'), findsOneWidget);
      await tester.tap(find.text('Enter coordinates manually'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('manual-latitude-field')),
        '91',
      );
      await tester.enterText(
        find.byKey(const Key('manual-longitude-field')),
        '8.5',
      );
      tester.testTextInput.hide();
      await tester.pump();
      final continueButton = find.byKey(
        const Key('manual-coordinate-continue'),
      );
      await tester.ensureVisible(continueButton.last);
      await tester.drag(find.byType(ListView).last, const Offset(0, -100));
      await tester.pump();
      await tester.ensureVisible(continueButton.last);
      await tester.pump();
      await tester.tap(continueButton.last);
      await tester.pump();
      expect(find.textContaining('Latitude must be between'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('manual-latitude-field')),
        '47.3',
      );
      await tester.enterText(
        find.byKey(const Key('manual-name-field')),
        'Lake cafe',
      );
      tester.testTextInput.hide();
      await tester.pump();
      await tester.ensureVisible(continueButton.last);
      await tester.drag(find.byType(ListView).last, const Offset(0, -100));
      await tester.pump();
      await tester.tap(continueButton.last);
      await tester.pumpAndSettle();
      expect(result?.source, PointDraftSource.manualCoordinates);
      expect(result?.originalText, original);
      expect(result?.label, 'Lake cafe');
    },
  );

  testWidgets('short-link recovery retries into the common draft flow', (
    tester,
  ) async {
    PointDraft? result;
    await _pumpRoute<PointDraft>(
      tester,
      PointParseRecoveryScreen(
        failure: const PointParseFailure(
          code: PointParseErrorCode.shortLinkTimeout,
          originalText: 'Trail https://maps.app.goo.gl/redacted',
          message: 'The link timed out.',
        ),
        parser: const SharedPointParser(
          directParser: PointDraftParser(),
          shortLinkResolver: FixedShortLinkResolver(),
        ),
      ),
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Retry link'));
    await tester.pumpAndSettle();
    expect(result?.source, PointDraftSource.googleMapsShare);
    expect(result?.latitude, closeTo(47.3769, 0.00001));
  });

  testWidgets('queue and point status render persisted status changes', (
    tester,
  ) async {
    final repository = MemorySendQueueRepository();
    final controller = SendQueueController(repository);
    await controller.initialize();
    final pending = _record(status: SendQueueStatus.pending);
    await controller.enqueue(pending);

    await tester.pumpWidget(
      MaterialApp(
        home: QueueScreen(controller: controller, onRecordTap: (_) {}),
      ),
    );
    expect(find.text('Trailhead parking'), findsOneWidget);
    expect(find.text('queued'), findsNWidgets(2));

    final directory = await _directory(
      defaultDevice: fixtureReadyDevice,
      devices: const [fixtureReadyDevice],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PointStatusScreen(
          messageId: pending.id,
          queueController: controller,
          queueActions: FakePointQueueActions(),
          deviceDirectory: directory,
          onOpenDevices: () {},
        ),
      ),
    );
    expect(find.text('Point queued'), findsOneWidget);

    repository.replace(
      pending.copyWith(
        status: SendQueueStatus.sent,
        updatedAt: DateTime.utc(2026, 8, 20, 13),
      ),
    );
    await controller.refresh();
    await tester.pump();
    expect(find.text('Point sent'), findsOneWidget);
    directory.dispose();
  });

  testWidgets('failed status exposes typed setup and retry recovery actions', (
    tester,
  ) async {
    final repository = MemorySendQueueRepository();
    final controller = SendQueueController(repository);
    await controller.initialize();
    final failed = _record(
      status: SendQueueStatus.failed,
      failure: const SendQueueFailure(
        code: SendQueueFailureCode.deliveryOutcomeUnknown,
        message: 'Delivery may have reached the watch.',
        isTransient: false,
      ),
    );
    await controller.enqueue(failed);
    final directory = await _directory(
      defaultDevice: fixtureReadyDevice,
      devices: const [fixtureReadyDevice],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PointStatusScreen(
          messageId: failed.id,
          queueController: controller,
          queueActions: FakePointQueueActions(),
          deviceDirectory: directory,
          onOpenDevices: () {},
        ),
      ),
    );
    expect(find.text('Delivery outcome is unknown.'), findsOneWidget);
    expect(find.text('Retry same point'), findsOneWidget);
    directory.dispose();
  });

  testWidgets('payload failures offer point editing instead of blind retry', (
    tester,
  ) async {
    final repository = MemorySendQueueRepository();
    final controller = SendQueueController(repository);
    await controller.initialize();
    final failed = _record(
      status: SendQueueStatus.failed,
      failure: const SendQueueFailure(
        code: SendQueueFailureCode.payloadTooLarge,
        message: 'The native transport rejected the message size.',
        isTransient: false,
      ),
    );
    await controller.enqueue(failed);
    final directory = await _directory(
      defaultDevice: fixtureReadyDevice,
      devices: const [fixtureReadyDevice],
    );
    var editCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PointStatusScreen(
          messageId: failed.id,
          queueController: controller,
          queueActions: FakePointQueueActions(),
          deviceDirectory: directory,
          onOpenDevices: () {},
          onEditPoint: () => editCalls += 1,
        ),
      ),
    );
    await tester.tap(find.text('Edit point'));
    expect(editCalls, 1);
    expect(find.text('Retry delivery'), findsNothing);
    directory.dispose();
  });

  testWidgets('root share flow restores the selected Queue tab', (
    tester,
  ) async {
    final offline = fixtureOfflineDevice.copyWith(
      companionInstallState: CompanionInstallState.installed,
    );
    final shared = FakeSharedContentGateway();
    final repository = MemorySendQueueRepository();
    final fakeSend = _FakeGarminSendGateway();
    await tester.pumpWidget(
      WristLinkApp(
        dependencies: WristLinkAppDependencies(
          deviceSettingsStore: InMemoryDeviceSettingsStore(
            defaultDeviceId: offline.id,
            authorizedDevices: [offline],
          ),
          sharedContentGateway: shared,
          sharedPointParser: const SharedPointParser(
            directParser: PointDraftParser(),
            shortLinkResolver: FixedShortLinkResolver(),
          ),
          sendQueueRepositoryFactory: () async => repository,
          sendGateway: fakeSend,
          acknowledgementGateway:
              const UnsupportedGarminAcknowledgementGateway(),
          mapViewBuilder: _fakeMapBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    shared.emit(
      SharedContentRecord(
        id: 'share-1',
        receivedAt: DateTime.utc(2026, 8, 20),
        platform: SharedContentPlatform.android,
        content: 'Trailhead 47.3769, 8.5417',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Send this point?'), findsOneWidget);
    expect(shared.acknowledgedIds, contains('share-1'));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing in the queue'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(fakeSend.messages, isEmpty);
    await shared.dispose();
  });

  testWidgets('manual flow restores the selected Send tab', (tester) async {
    final repository = MemorySendQueueRepository();
    await tester.pumpWidget(
      WristLinkApp(
        dependencies: WristLinkAppDependencies(
          deviceSettingsStore: InMemoryDeviceSettingsStore(),
          sendQueueRepositoryFactory: () async => repository,
          sharedPointParser: const SharedPointParser(
            directParser: PointDraftParser(),
            shortLinkResolver: FixedShortLinkResolver(),
          ),
          mapViewBuilder: _fakeMapBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Manual point'), 160);
    await tester.tap(find.text('Manual point'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Selected point pin'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker remains usable with large accessibility text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: ManualPointPickerScreen(mapViewBuilder: _fakeMapBuilder),
      ),
    );
    expect(find.text('Dropped pin'), findsOneWidget);
    expect(find.text('Use this point'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _messageId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _draft = PointDraft(
  latitude: 47.3769,
  longitude: 8.5417,
  label: 'Trailhead parking',
  source: PointDraftSource.googleMapsShare,
);

Widget _fakeMapBuilder(
  BuildContext context,
  PointMapCoordinate initialTarget,
  PointMapViewportController viewportController,
  ValueChanged<PointMapCoordinate> onCameraChanged,
) {
  return ColoredBox(
    color: const Color(0xFFE8F3F1),
    child: Align(
      alignment: Alignment.topLeft,
      child: SafeArea(
        child: FilledButton(
          key: const Key('move-map'),
          onPressed: () =>
              onCameraChanged(const PointMapCoordinate(12.34567, -45.67891)),
          child: const Text('Move map'),
        ),
      ),
    ),
  );
}

class _DeniedLocationGateway implements CurrentLocationGateway {
  const _DeniedLocationGateway();

  @override
  Future<PointMapCoordinate> currentLocation() async {
    throw const LocationAccessException(
      'Location permission was denied. You can still choose a point manually.',
    );
  }
}

class _FakeGarminSendGateway implements GarminSendGateway {
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

Future<LocalDeviceDirectory> _directory({
  GarminDevice? defaultDevice,
  List<GarminDevice> devices = const [],
}) async {
  final directory = LocalDeviceDirectory(
    store: InMemoryDeviceSettingsStore(
      defaultDeviceId: defaultDevice?.id,
      authorizedDevices: devices,
    ),
  );
  await directory.load();
  return directory;
}

SendQueueRecord _record({
  required SendQueueStatus status,
  SendQueueFailure? failure,
}) {
  final createdAt = DateTime.utc(2026, 8, 20, 12);
  final message = PointEnvelopeFactory(idFactory: (_) => _messageId).create(
    draft: _draft,
    intent: PointIntent.navigate,
    editedLabel: _draft.label,
    createdAt: createdAt,
  );
  return SendQueueRecord(
    message: message,
    status: status,
    createdAt: createdAt,
    updatedAt: createdAt,
    attemptCount: status == SendQueueStatus.pending ? 0 : 1,
    deviceId: fixtureReadyDevice.id,
    failure: failure,
  );
}

Future<void> _pumpRoute<T>(
  WidgetTester tester,
  Widget route, {
  ValueChanged<T?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      home: _RouteLauncher<T>(route: route, onResult: onResult),
    ),
  );
  await tester.tap(find.text('Open test route'));
  await tester.pumpAndSettle();
}

class _RouteLauncher<T> extends StatelessWidget {
  const _RouteLauncher({required this.route, this.onResult});

  final Widget route;
  final ValueChanged<T?>? onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final result = await Navigator.of(
              context,
            ).push<T>(MaterialPageRoute<T>(builder: (_) => route));
            onResult?.call(result);
          },
          child: const Text('Open test route'),
        ),
      ),
    );
  }
}
