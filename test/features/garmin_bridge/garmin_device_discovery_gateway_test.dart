import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/devices/domain/device_directory.dart';
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
}
