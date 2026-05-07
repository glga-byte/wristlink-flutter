import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/devices/data/method_channel_device_settings_store.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/device_settings');
  final values = <String, String>{};

  setUp(() {
    values.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = call.arguments as Map<Object?, Object?>?;
          final key = arguments?['key'] as String?;
          switch (call.method) {
            case 'readString':
              return values[key];
            case 'writeString':
              values[key!] = arguments?['value'] as String;
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('ignores malformed authorized-device JSON', () async {
    values['authorizedDevices'] = '{bad json';
    final store = MethodChannelDeviceSettingsStore(channel: channel);

    expect(await store.readAuthorizedDevices(), isEmpty);
  });

  test('skips stored devices with missing ids', () async {
    values['authorizedDevices'] =
        '[{"name":"Missing id"},{"id":"","name":"Empty id"},{"id":"physical:ok","name":"Forerunner","source":"physical","reachability":"reachable","companionInstallState":"installed"}]';
    final store = MethodChannelDeviceSettingsStore(channel: channel);

    final devices = await store.readAuthorizedDevices();

    expect(devices, hasLength(1));
    expect(devices.single.id, const GarminDeviceId('physical:ok'));
  });

  test('falls back for unknown stored enum values', () async {
    values['authorizedDevices'] =
        '[{"id":"physical:unknown","name":"Unknown","source":"unexpected","reachability":"unexpected","companionInstallState":"unexpected"}]';
    values['emulatorSettings'] =
        '{"enabled":true,"reachability":"unexpected","companionInstallState":"unexpected"}';
    final store = MethodChannelDeviceSettingsStore(channel: channel);

    final devices = await store.readAuthorizedDevices();
    final emulatorSettings = await store.readEmulatorSettings();

    expect(devices.single.source, DeviceSource.physical);
    expect(devices.single.reachability, DeviceReachability.unknown);
    expect(devices.single.companionInstallState, CompanionInstallState.unknown);
    expect(emulatorSettings.enabled, isTrue);
    expect(emulatorSettings.reachability, DeviceReachability.reachable);
    expect(
      emulatorSettings.companionInstallState,
      CompanionInstallState.installed,
    );
  });
}
