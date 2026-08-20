import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/devices/domain/device_directory.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_device_discovery_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('wristlink/garmin_devices_test');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('times out when native discovery never completes', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) => Completer<Object?>().future);

    final gateway = MethodChannelGarminDeviceDiscoveryGateway(
      channel: channel,
      timeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      gateway.discoverDevices(),
      throwsA(
        isA<GarminDiscoveryError>().having(
          (error) => error.code,
          'code',
          GarminDiscoveryErrorCode.timeout,
        ),
      ),
    );
  });

  test(
    'coalesces in-flight hydration then refreshes native readiness',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return [
              {
                'id': '123456789',
                'name': 'Forerunner 965',
                'modelName': 'Forerunner 965',
                'family': '006-B4444-00',
                'unitId': '123456789',
                'reachability': 'reachable',
                'companionInstallState': 'installed',
              },
            ];
          });
      final gateway = MethodChannelGarminDeviceDiscoveryGateway(
        channel: channel,
      );

      final results = await Future.wait([
        gateway.hydrateTransport(const [persistedDevice]),
        gateway.hydrateTransport(const [persistedDevice]),
      ]);
      final repeated = await gateway.hydrateTransport(const [persistedDevice]);

      expect(results.expand((devices) => devices), hasLength(2));
      expect(repeated.single.id, persistedDevice.id);
      expect(calls, hasLength(2));
      expect(calls.every((call) => call.method == 'hydrateTransport'), isTrue);
      expect(calls.first.arguments, {
        'devices': [
          {
            'id': '123456789',
            'name': 'Forerunner 965',
            'modelName': 'Forerunner 965',
            'partNumber': '006-B4444-00',
            'unitId': '123456789',
          },
        ],
      });
    },
  );

  test(
    'maps unavailable Android hydration and retries a later request',
    () async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls += 1;
            if (calls == 1) {
              throw PlatformException(
                code: 'sdkUnavailable',
                message: 'Garmin SDK is not ready.',
              );
            }
            return [
              {
                'id': '123456789',
                'name': 'Forerunner 965',
                'modelName': 'Forerunner 965',
                'family': '006-B4444-00',
                'unitId': '123456789',
                'reachability': 'offline',
                'companionInstallState': 'installed',
              },
            ];
          });
      final gateway = MethodChannelGarminDeviceDiscoveryGateway(
        channel: channel,
      );

      await expectLater(
        gateway.hydrateTransport(const [persistedDevice]),
        throwsA(
          isA<GarminDiscoveryError>().having(
            (error) => error.code,
            'code',
            GarminDiscoveryErrorCode.sdkUnavailable,
          ),
        ),
      );

      final devices = await gateway.hydrateTransport(const [persistedDevice]);

      expect(calls, 2);
      expect(devices.single.reachability, DeviceReachability.offline);
      expect(
        devices.single.companionInstallState,
        CompanionInstallState.installed,
      );
    },
  );
}

const persistedDevice = GarminDevice(
  id: GarminDeviceId('physical:123456789'),
  name: 'Forerunner 965',
  reachability: DeviceReachability.reachable,
  companionInstallState: CompanionInstallState.installed,
  metadata: GarminDeviceMetadata(
    modelName: 'Forerunner 965',
    family: '006-B4444-00',
    unitId: '123456789',
  ),
);
