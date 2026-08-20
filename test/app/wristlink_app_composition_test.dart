import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/app/wristlink_app_composition.dart';
import 'package:wristlink_flutter/features/devices/data/in_memory_device_settings_store.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/devices/test_fixtures/device_fixtures.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_acknowledgement_gateway.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_device_discovery_gateway.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_send_gateway.dart';
import 'package:wristlink_flutter/features/payloads/message_contract.dart';
import 'package:wristlink_flutter/features/send_queue/background/background_send_scheduler.dart';
import 'package:wristlink_flutter/features/send_queue/domain/send_queue_record.dart';

import '../support/send_point_ui_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deviceChannel = MethodChannel(
    'wristlink/app_composition_test/garmin_devices',
  );
  const sendChannel = MethodChannel(
    'wristlink/app_composition_test/garmin_send',
  );

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(deviceChannel, null);
    messenger.setMockMethodCallHandler(sendChannel, null);
  });

  test(
    'hydrates persisted transport before creating the delivery service',
    () async {
      final gateway = _PendingHydrationGateway();
      var repositoryFactoryCalls = 0;
      final composition = WristLinkAppComposition(
        navigatorKey: GlobalKey<NavigatorState>(),
        selectedTab: ValueNotifier<int>(0),
        dependencies: WristLinkAppDependencies(
          deviceSettingsStore: InMemoryDeviceSettingsStore(
            defaultDeviceId: fixtureReadyDevice.id,
            authorizedDevices: const [fixtureReadyDevice],
          ),
          discoveryGateway: gateway,
          sendQueueRepositoryFactory: () async {
            repositoryFactoryCalls += 1;
            return MemorySendQueueRepository();
          },
          sendGateway: const UnsupportedGarminSendGateway(),
          acknowledgementGateway:
              const UnsupportedGarminAcknowledgementGateway(),
          backgroundScheduler: const UnsupportedBackgroundSendScheduler(),
        ),
      );

      final initialization = composition.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(gateway.hydrationCalls, 1);
      expect(repositoryFactoryCalls, 0);
      expect(
        composition.deviceDirectory.devices.single.reachability,
        DeviceReachability.unknown,
      );

      gateway.complete(const [fixtureReadyDevice]);
      await initialization;

      expect(repositoryFactoryCalls, 1);
      expect(composition.deliveryService.isInitialized, isTrue);
      await composition.dispose();
    },
  );

  group('cold-process delivery', () {
    for (final platform in ['android', 'ios']) {
      test(
        '$platform hydrates before startup drain and sends by raw id without discovery',
        () async {
          final fixture = await _loadRoundTripFixture(platform);
          final persistedDevice = mapNativeDevice(fixture.discoveryPayload);
          final repository = MemorySendQueueRepository()
            ..replace(_pendingRecord(_persistedMessageId, persistedDevice.id));
          final acknowledgements = _FakeAcknowledgementGateway();
          final hydrationMayComplete = Completer<void>();
          final events = <String>[];
          final nativeDeviceCache = <String>{};
          var discoveryCalls = 0;

          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(deviceChannel, (call) async {
            if (call.method == 'discoverDevices') {
              discoveryCalls += 1;
              return <Object?>[];
            }
            expect(call.method, 'hydrateTransport');
            events.add('hydrate');
            final arguments = (call.arguments! as Map<Object?, Object?>);
            final descriptors = (arguments['devices']! as List<Object?>)
                .cast<Map<Object?, Object?>>();
            expect(descriptors, hasLength(1));
            expect(descriptors.single['id'], fixture.rawDeviceId);
            expect(descriptors.single['id'], isNot(startsWith('physical:')));
            await hydrationMayComplete.future;
            nativeDeviceCache.add(fixture.rawDeviceId);
            return <Object?>[fixture.discoveryPayload];
          });
          messenger.setMockMethodCallHandler(sendChannel, (call) async {
            expect(call.method, 'sendMessage');
            final arguments = call.arguments! as Map<Object?, Object?>;
            final rawDeviceId = arguments['deviceId']! as String;
            events.add('send:$rawDeviceId');
            if (!nativeDeviceCache.contains(rawDeviceId)) {
              throw PlatformException(
                code: 'deviceUnavailable',
                message: 'Raw native device cache lookup failed.',
              );
            }
            final message = arguments['message']! as Map<Object?, Object?>;
            scheduleMicrotask(() {
              acknowledgements.accept(message['id']! as String);
            });
            return null;
          });

          final composition = WristLinkAppComposition(
            navigatorKey: GlobalKey<NavigatorState>(),
            selectedTab: ValueNotifier<int>(0),
            dependencies: WristLinkAppDependencies(
              deviceSettingsStore: InMemoryDeviceSettingsStore(
                defaultDeviceId: persistedDevice.id,
                authorizedDevices: [persistedDevice],
              ),
              discoveryGateway: _ChannelHydrationGateway(deviceChannel),
              sendQueueRepositoryFactory: () async => repository,
              sendGateway: MethodChannelGarminSendGateway(channel: sendChannel),
              acknowledgementGateway: acknowledgements,
              backgroundScheduler: const UnsupportedBackgroundSendScheduler(),
            ),
          );

          final initialization = composition.initialize();
          await Future<void>.delayed(Duration.zero);

          expect(events, ['hydrate']);
          expect(repository.initialized, isFalse);
          expect(
            (await repository.findById(_persistedMessageId))!.status,
            SendQueueStatus.pending,
          );
          expect(
            (await repository.findById(_persistedMessageId))!.attemptCount,
            0,
          );

          hydrationMayComplete.complete();
          await initialization;

          expect(
            (await repository.findById(_persistedMessageId))!.status,
            SendQueueStatus.sent,
          );
          expect(events, ['hydrate', 'send:${fixture.rawDeviceId}']);
          expect(discoveryCalls, 0);

          final submitted = await composition.deliveryService.submit(
            _pendingRecord(_submittedMessageId, persistedDevice.id),
          );

          expect(submitted.status, SendQueueStatus.sent);
          expect(events, [
            'hydrate',
            'send:${fixture.rawDeviceId}',
            'send:${fixture.rawDeviceId}',
          ]);
          expect(discoveryCalls, 0);

          await composition.dispose();
          await acknowledgements.close();
        },
      );

      test(
        '$platform keeps formerly-ready work unclaimed when hydration is unavailable',
        () async {
          final fixture = await _loadRoundTripFixture(platform);
          final persistedDevice = mapNativeDevice(fixture.discoveryPayload);
          final repository = MemorySendQueueRepository()
            ..replace(_pendingRecord(_persistedMessageId, persistedDevice.id));
          var sendCalls = 0;
          var discoveryCalls = 0;
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(deviceChannel, (call) async {
            if (call.method == 'discoverDevices') {
              discoveryCalls += 1;
              return <Object?>[];
            }
            throw PlatformException(
              code: 'sdkUnavailable',
              message: 'Native transport hydration is unavailable.',
            );
          });
          messenger.setMockMethodCallHandler(sendChannel, (call) async {
            sendCalls += 1;
            return null;
          });
          final composition = WristLinkAppComposition(
            navigatorKey: GlobalKey<NavigatorState>(),
            selectedTab: ValueNotifier<int>(0),
            dependencies: WristLinkAppDependencies(
              deviceSettingsStore: InMemoryDeviceSettingsStore(
                defaultDeviceId: persistedDevice.id,
                authorizedDevices: [persistedDevice],
              ),
              discoveryGateway: _ChannelHydrationGateway(deviceChannel),
              sendQueueRepositoryFactory: () async => repository,
              sendGateway: MethodChannelGarminSendGateway(channel: sendChannel),
              acknowledgementGateway:
                  const UnsupportedGarminAcknowledgementGateway(),
              backgroundScheduler: const UnsupportedBackgroundSendScheduler(),
            ),
          );

          await composition.initialize();

          final stored = (await repository.findById(_persistedMessageId))!;
          expect(stored.status, SendQueueStatus.pending);
          expect(stored.attemptCount, 0);
          expect(
            composition.deviceDirectory.devices.single.reachability,
            DeviceReachability.unknown,
          );
          expect(sendCalls, 0);
          expect(discoveryCalls, 0);

          await composition.dispose();
        },
      );
    }
  });
}

class _PendingHydrationGateway implements GarminDeviceDiscoveryGateway {
  final _completion = Completer<List<GarminDevice>>();
  var hydrationCalls = 0;

  @override
  Stream<GarminDevice> get deviceUpdates => const Stream.empty();

  @override
  Future<List<GarminDevice>> discoverDevices() async => const [];

  @override
  Future<List<GarminDevice>> hydrateTransport(
    List<GarminDevice> authorizedDevices,
  ) {
    hydrationCalls += 1;
    return _completion.future;
  }

  void complete(List<GarminDevice> devices) => _completion.complete(devices);
}

class _ChannelHydrationGateway implements GarminDeviceDiscoveryGateway {
  _ChannelHydrationGateway(MethodChannel channel)
    : _delegate = MethodChannelGarminDeviceDiscoveryGateway(channel: channel);

  final MethodChannelGarminDeviceDiscoveryGateway _delegate;

  @override
  Stream<GarminDevice> get deviceUpdates => const Stream.empty();

  @override
  Future<List<GarminDevice>> discoverDevices() => _delegate.discoverDevices();

  @override
  Future<List<GarminDevice>> hydrateTransport(
    List<GarminDevice> authorizedDevices,
  ) => _delegate.hydrateTransport(authorizedDevices);
}

class _FakeAcknowledgementGateway implements GarminAcknowledgementGateway {
  final _controller = StreamController<WatchAcknowledgement>.broadcast();

  void accept(String messageId) {
    _controller.add(
      WatchAcknowledgement(
        id: _acknowledgementId,
        ackFor: messageId,
        status: WatchAcknowledgementStatus.accepted,
        receivedAt: _now,
      ),
    );
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

Future<_RoundTripFixture> _loadRoundTripFixture(String platform) async {
  final root =
      jsonDecode(
            await File(
              'test/fixtures/garmin_device_id_round_trip.json',
            ).readAsString(),
          )
          as Map<String, Object?>;
  final fixture = (root['cases']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .singleWhere((item) => item['platform'] == platform);
  return _RoundTripFixture(
    rawDeviceId: fixture['rawDeviceId']! as String,
    discoveryPayload: (fixture['discoveryPayload']! as Map<String, Object?>)
        .cast<Object?, Object?>(),
  );
}

class _RoundTripFixture {
  const _RoundTripFixture({
    required this.rawDeviceId,
    required this.discoveryPayload,
  });

  final String rawDeviceId;
  final Map<Object?, Object?> discoveryPayload;
}

SendQueueRecord _pendingRecord(String messageId, GarminDeviceId deviceId) {
  return SendQueueRecord.pending(
    message: MessageEnvelope(
      id: messageId,
      kind: MessageKind.point,
      createdAt: _now,
      payload: const PointPayload(
        intent: PointIntent.navigate,
        latitude: 52.52,
        longitude: 13.405,
        label: 'Cold process point',
      ),
    ),
    createdAt: _now,
    deviceId: deviceId,
  );
}

final _now = DateTime.utc(2026, 8, 28, 12);
const _persistedMessageId = '01HX7Y8Z9ABCDEFGHJKMNPQS6X';
const _submittedMessageId = '01HX7Y8Z9ABCDEFGHJKMNPQS7X';
const _acknowledgementId = '01HX7Y8Z9ABCDEFGHJKMNPQS8X';
