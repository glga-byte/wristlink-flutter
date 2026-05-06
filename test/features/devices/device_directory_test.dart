import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/developer_tools/domain/emulator_device_settings.dart';
import 'package:wristlink_flutter/features/devices/data/in_memory_device_settings_store.dart';
import 'package:wristlink_flutter/features/devices/data/local_device_directory.dart';
import 'package:wristlink_flutter/features/devices/domain/device_directory.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/devices/test_fixtures/device_fixtures.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_device_discovery_gateway.dart';

void main() {
  test('composes physical devices and resolves ready default target', () async {
    final directory = LocalDeviceDirectory(
      store: InMemoryDeviceSettingsStore(
        defaultDeviceId: fixtureReadyDevice.id,
        authorizedDevices: const [
          fixtureReadyDevice,
          fixtureSetupDevice,
          fixtureOfflineDevice,
        ],
      ),
    );

    await directory.load();

    expect(directory.devices, hasLength(3));
    final resolution = directory.resolveSendTarget();
    expect(resolution, isA<SendTargetReady>());
  });

  test('emulator overrides physical devices while enabled', () async {
    final directory = LocalDeviceDirectory(
      store: InMemoryDeviceSettingsStore(
        defaultDeviceId: fixtureReadyDevice.id,
        authorizedDevices: const [fixtureReadyDevice],
        emulatorSettings: const EmulatorDeviceSettings(enabled: true),
      ),
    );

    await directory.load();

    expect(directory.devices, hasLength(1));
    expect(directory.devices.single.source, DeviceSource.emulator);
    expect(directory.resolveSendTarget(), isA<SendTargetUnavailable>());

    await directory.updateEmulatorSettings(
      const EmulatorDeviceSettings(
        enabled: true,
        reachability: DeviceReachability.reachable,
        companionInstallState: CompanionInstallState.installed,
      ),
    );

    expect(directory.resolveSendTarget(), isA<SendTargetReady>());
  });

  test('preserves stale default but does not resolve it as sendable', () async {
    final directory = LocalDeviceDirectory(
      store: InMemoryDeviceSettingsStore(
        defaultDeviceId: const GarminDeviceId('physical:missing'),
        authorizedDevices: const [fixtureReadyDevice],
      ),
    );

    await directory.load();

    expect(
      directory.resolveSendTarget(),
      isA<SendTargetUnavailable>().having(
        (result) => result.reason,
        'reason',
        SendTargetUnavailableReason.defaultDeviceMissing,
      ),
    );
  });

  test('returns no-devices reason when directory is empty', () async {
    final directory = LocalDeviceDirectory(
      store: InMemoryDeviceSettingsStore(authorizedDevices: const []),
    );

    await directory.load();

    expect(directory.devices, isEmpty);
    expect(
      directory.resolveSendTarget(),
      isA<SendTargetUnavailable>().having(
        (result) => result.reason,
        'reason',
        SendTargetUnavailableReason.noDevices,
      ),
    );
  });

  test(
    'refresh replaces authorized devices and keeps previous list on error',
    () async {
      final store = InMemoryDeviceSettingsStore(
        defaultDeviceId: fixtureReadyDevice.id,
        authorizedDevices: const [fixtureReadyDevice],
      );
      final gateway = _SequenceGateway([
        const [fixtureSetupDevice],
        const GarminDiscoveryError(
          GarminDiscoveryErrorCode.timeout,
          'Timed out',
        ),
      ]);
      final directory = LocalDeviceDirectory(
        store: store,
        discoveryGateway: gateway,
      );

      await directory.load();

      final success = await directory.refreshDevices();
      expect(success, isA<DeviceRefreshSuccess>());
      expect(directory.devices.single.id, fixtureSetupDevice.id);

      final failure = await directory.refreshDevices();
      expect(failure, isA<DeviceRefreshFailure>());
      expect(directory.devices.single.id, fixtureSetupDevice.id);
    },
  );
}

class _SequenceGateway implements GarminDeviceDiscoveryGateway {
  _SequenceGateway(this.results);

  final List<Object> results;
  var _index = 0;

  @override
  Future<List<GarminDevice>> discoverDevices() async {
    final result = results[_index++];
    if (result is GarminDiscoveryError) {
      throw result;
    }
    return result as List<GarminDevice>;
  }
}
