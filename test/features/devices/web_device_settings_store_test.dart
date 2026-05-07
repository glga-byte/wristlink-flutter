@TestOn('browser')
library;

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/app/platform/device_settings_store_provider.dart';
import 'package:wristlink_flutter/features/devices/data/string_device_settings_store.dart';
import 'package:wristlink_flutter/features/devices/data/web_device_settings_store.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';

void main() {
  const store = WebDeviceSettingsStore();

  setUp(() {
    html.window.localStorage.remove(StringDeviceSettingsStore.defaultDeviceKey);
    html.window.localStorage.remove(
      StringDeviceSettingsStore.authorizedDevicesKey,
    );
  });

  test('platform provider uses web store in browser tests', () {
    expect(createDeviceSettingsStore(), isA<WebDeviceSettingsStore>());
  });

  test('persists default device id in browser storage', () async {
    await store.writeDefaultDeviceId(const GarminDeviceId('physical:web'));

    expect(
      html.window.localStorage[StringDeviceSettingsStore.defaultDeviceKey],
      'physical:web',
    );
    expect(
      await store.readDefaultDeviceId(),
      const GarminDeviceId('physical:web'),
    );
  });

  test('persists authorized devices and filters unsafe metadata', () async {
    const device = GarminDevice(
      id: GarminDeviceId('physical:web-ready'),
      name: 'Web Ready',
      reachability: DeviceReachability.reachable,
      companionInstallState: CompanionInstallState.installed,
      metadata: GarminDeviceMetadata(
        nativePayload: {
          'safe': 'value',
          'unsafe': <String, Object?>{'nested': true},
        },
      ),
    );

    await store.replaceAuthorizedDevices(const [device]);

    final raw = html
        .window
        .localStorage[StringDeviceSettingsStore.authorizedDevicesKey]!;
    final decoded = jsonDecode(raw) as List<Object?>;
    final json = (decoded.single as Map).cast<String, Object?>();
    final metadata = (json['metadata'] as Map).cast<String, Object?>();
    final nativePayload = (metadata['nativePayload'] as Map)
        .cast<String, Object?>();

    final devices = await store.readAuthorizedDevices();

    expect(devices, hasLength(1));
    expect(devices.single.id, device.id);
    expect(devices.single.name, device.name);
    expect(devices.single.metadata.nativePayload, {'safe': 'value'});
    expect(nativePayload, {'safe': 'value'});
  });

  test('handles malformed payloads and unknown enum values', () async {
    await store.writeString(
      StringDeviceSettingsStore.authorizedDevicesKey,
      '{bad json',
    );
    expect(await store.readAuthorizedDevices(), isEmpty);

    await store.writeString(
      StringDeviceSettingsStore.authorizedDevicesKey,
      '[{"id":"physical:unknown","name":"Unknown","source":"unexpected","reachability":"unexpected","companionInstallState":"unexpected"}]',
    );

    final devices = await store.readAuthorizedDevices();

    expect(devices.single.reachability, DeviceReachability.unknown);
    expect(devices.single.companionInstallState, CompanionInstallState.unknown);
  });
}
