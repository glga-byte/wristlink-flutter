import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/developer_tools/domain/emulator_device_settings.dart';
import 'package:wristlink_flutter/features/devices/data/emulated_device_directory.dart';
import 'package:wristlink_flutter/features/devices/data/in_memory_device_settings_store.dart';
import 'package:wristlink_flutter/features/devices/data/local_device_directory.dart';
import 'package:wristlink_flutter/features/devices/data/physical_device_directory.dart';
import 'package:wristlink_flutter/features/devices/domain/device_directory.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/devices/test_fixtures/device_fixtures.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_device_discovery_gateway.dart';

void main() {
  group('PhysicalDeviceDirectory', () {
    test(
      'composes physical devices and resolves ready default target',
      () async {
        final directory = PhysicalDeviceDirectory(
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
        expect(directory.defaultDeviceId, fixtureReadyDevice.id);
        expect(directory.resolveSendTarget(), isA<SendTargetReady>());
      },
    );

    test('preserves stale physical default but does not resolve it', () async {
      final directory = PhysicalDeviceDirectory(
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
      final directory = PhysicalDeviceDirectory(
        store: InMemoryDeviceSettingsStore(authorizedDevices: const []),
      );

      await directory.load();

      expect(directory.devices, isEmpty);
      expect(
        directory.emptyReason,
        DeviceDirectoryEmptyReason.noAuthorizedDevices,
      );
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
            GarminDiscoveryErrorCode.garminConnectMissing,
            'Garmin Connect missing',
          ),
        ]);
        final directory = PhysicalDeviceDirectory(
          store: store,
          discoveryGateway: gateway,
        );

        await directory.load();

        final success = await directory.refreshDevices();
        expect(success, isA<DeviceRefreshSuccess>());
        expect(directory.devices.single.id, fixtureSetupDevice.id);
        expect(
          (await store.readAuthorizedDevices()).single.id,
          fixtureSetupDevice.id,
        );

        final failure = await directory.refreshDevices();
        expect(failure, isA<DeviceRefreshFailure>());
        expect(directory.devices.single.id, fixtureSetupDevice.id);
      },
    );

    test('refresh timeout uses cached devices when available', () async {
      final directory = PhysicalDeviceDirectory(
        store: InMemoryDeviceSettingsStore(
          defaultDeviceId: fixtureReadyDevice.id,
          authorizedDevices: const [fixtureReadyDevice],
        ),
        discoveryGateway: _SequenceGateway([
          const GarminDiscoveryError(
            GarminDiscoveryErrorCode.timeout,
            'Timed out',
          ),
        ]),
      );

      await directory.load();

      final result = await directory.refreshDevices();

      expect(result, isA<DeviceRefreshSuccess>());
      expect(directory.devices.single.id, fixtureReadyDevice.id);
      expect(directory.lastRefreshError, isNull);
    });

    test('native status updates refresh cached physical devices', () async {
      final gateway = _EventGateway();
      final store = InMemoryDeviceSettingsStore(
        defaultDeviceId: fixtureOfflineDevice.id,
        authorizedDevices: const [fixtureOfflineDevice],
      );
      final directory = PhysicalDeviceDirectory(
        store: store,
        discoveryGateway: gateway,
      );

      await directory.load();
      expect(directory.resolveSendTarget(), isA<SendTargetUnavailable>());

      gateway.add(
        fixtureOfflineDevice.copyWith(
          reachability: DeviceReachability.reachable,
          companionInstallState: CompanionInstallState.installed,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        directory.devices.single.reachability,
        DeviceReachability.reachable,
      );
      expect(directory.devices.single.isDefault, isTrue);
      expect(directory.resolveSendTarget(), isA<SendTargetReady>());
      expect(
        (await store.readAuthorizedDevices()).single.reachability,
        DeviceReachability.reachable,
      );

      await gateway.close();
      directory.dispose();
    });

    test('ignores non-physical native status updates', () async {
      final gateway = _EventGateway();
      final directory = PhysicalDeviceDirectory(
        store: InMemoryDeviceSettingsStore(
          defaultDeviceId: fixtureOfflineDevice.id,
          authorizedDevices: const [fixtureOfflineDevice],
        ),
        discoveryGateway: gateway,
      );

      await directory.load();

      gateway.add(
        fixtureOfflineDevice.copyWith(
          source: DeviceSource.emulator,
          reachability: DeviceReachability.reachable,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(directory.devices.single.reachability, DeviceReachability.offline);

      await gateway.close();
      directory.dispose();
    });

    test(
      'refresh maps unexpected gateway failures to typed failures',
      () async {
        final directory = PhysicalDeviceDirectory(
          store: InMemoryDeviceSettingsStore(authorizedDevices: const []),
          discoveryGateway: const _UnexpectedErrorGateway(),
        );

        await directory.load();

        final result = await directory.refreshDevices();

        expect(
          result,
          isA<DeviceRefreshFailure>().having(
            (failure) => failure.error.code,
            'code',
            GarminDiscoveryErrorCode.nativeFailure,
          ),
        );
        expect(
          directory.lastRefreshError?.code,
          GarminDiscoveryErrorCode.nativeFailure,
        );
      },
    );

    test(
      'repairs stale emulator default id when physical devices exist',
      () async {
        final store = InMemoryDeviceSettingsStore(
          defaultDeviceId: emulatorGarminDeviceId,
          authorizedDevices: const [fixtureReadyDevice],
        );
        final directory = PhysicalDeviceDirectory(store: store);

        await directory.load();

        expect(directory.defaultDeviceId, fixtureReadyDevice.id);
        expect(await store.readDefaultDeviceId(), fixtureReadyDevice.id);
        expect(directory.resolveSendTarget(), isA<SendTargetReady>());
      },
    );

    test(
      'ignores stale emulator default id when no physical devices exist',
      () async {
        final directory = PhysicalDeviceDirectory(
          store: InMemoryDeviceSettingsStore(
            defaultDeviceId: emulatorGarminDeviceId,
            authorizedDevices: const [],
          ),
        );

        await directory.load();

        expect(directory.defaultDeviceId, isNull);
        expect(
          directory.resolveSendTarget(),
          isA<SendTargetUnavailable>().having(
            (result) => result.reason,
            'reason',
            SendTargetUnavailableReason.noDevices,
          ),
        );
      },
    );
  });

  group('EmulatedDeviceDirectory', () {
    test('composes stable emulator device and resolves ready target', () {
      final directory = EmulatedDeviceDirectory();

      expect(directory.devices, hasLength(1));
      expect(directory.devices.single.id, emulatorGarminDeviceId);
      expect(directory.devices.single.source, DeviceSource.emulator);
      expect(directory.devices.single.isDefault, isTrue);
      expect(directory.defaultDeviceId, emulatorGarminDeviceId);
      expect(directory.resolveSendTarget(), isA<SendTargetReady>());
    });

    test('updates emulator state and send-target readiness', () {
      final directory = EmulatedDeviceDirectory();

      directory.updateSettings(
        const EmulatorDeviceSettings(
          enabled: true,
          reachability: DeviceReachability.offline,
          companionInstallState: CompanionInstallState.installed,
        ),
      );

      expect(directory.devices.single.reachability, DeviceReachability.offline);
      expect(
        directory.resolveSendTarget(),
        isA<SendTargetUnavailable>().having(
          (result) => result.reason,
          'reason',
          SendTargetUnavailableReason.defaultDeviceOffline,
        ),
      );
    });

    test(
      'refresh is a no-op that returns the current emulator device',
      () async {
        final directory = EmulatedDeviceDirectory(
          settings: const EmulatorDeviceSettings(
            reachability: DeviceReachability.sending,
          ),
        );

        final result = await directory.refreshDevices();

        expect(
          result,
          isA<DeviceRefreshSuccess>().having(
            (success) => success.devices.single.reachability,
            'reachability',
            DeviceReachability.sending,
          ),
        );
        expect(directory.lastRefreshError, isNull);
        expect(directory.emptyReason, isNull);
      },
    );
  });

  group('LocalDeviceDirectory facade', () {
    test(
      'delegates to physical directory while emulator is disabled',
      () async {
        final gateway = _CountingGateway(devices: const [fixtureSetupDevice]);
        final directory = LocalDeviceDirectory(
          store: InMemoryDeviceSettingsStore(
            defaultDeviceId: fixtureReadyDevice.id,
            authorizedDevices: const [fixtureReadyDevice],
          ),
          discoveryGateway: gateway,
        );

        await directory.load();

        final result = await directory.refreshDevices();

        expect(result, isA<DeviceRefreshSuccess>());
        expect(gateway.discoveryCallCount, 1);
        expect(directory.devices.single.id, fixtureSetupDevice.id);
      },
    );

    test(
      'emulator mode exposes emulator default without persisting it',
      () async {
        final store = InMemoryDeviceSettingsStore(
          defaultDeviceId: fixtureReadyDevice.id,
          authorizedDevices: const [fixtureReadyDevice],
          emulatorSettings: const EmulatorDeviceSettings(enabled: true),
        );
        final directory = LocalDeviceDirectory(store: store);

        await directory.load();

        expect(directory.devices.single.source, DeviceSource.emulator);
        expect(directory.defaultDeviceId, emulatorGarminDeviceId);
        expect(await store.readDefaultDeviceId(), fixtureReadyDevice.id);
        expect(directory.resolveSendTarget(), isA<SendTargetReady>());
      },
    );

    test('preserves physical default while toggling emulator mode', () async {
      final store = InMemoryDeviceSettingsStore(
        defaultDeviceId: fixtureSetupDevice.id,
        authorizedDevices: const [fixtureReadyDevice, fixtureSetupDevice],
      );
      final directory = LocalDeviceDirectory(store: store);

      await directory.load();
      await directory.updateEmulatorSettings(
        const EmulatorDeviceSettings(enabled: true),
      );

      expect(directory.defaultDeviceId, emulatorGarminDeviceId);
      expect(await store.readDefaultDeviceId(), fixtureSetupDevice.id);

      await directory.updateEmulatorSettings(const EmulatorDeviceSettings());

      expect(directory.defaultDeviceId, fixtureSetupDevice.id);
      expect(
        directory.devices.singleWhere((device) => device.isDefault).id,
        fixtureSetupDevice.id,
      );
      expect(await store.readDefaultDeviceId(), fixtureSetupDevice.id);
    });

    test('refresh in emulator mode avoids native discovery', () async {
      final gateway = _CountingGateway(devices: const [fixtureReadyDevice]);
      final directory = LocalDeviceDirectory(
        store: InMemoryDeviceSettingsStore(
          emulatorSettings: const EmulatorDeviceSettings(enabled: true),
        ),
        discoveryGateway: gateway,
      );

      await directory.load();

      final result = await directory.refreshDevices();

      expect(result, isA<DeviceRefreshSuccess>());
      expect(gateway.discoveryCallCount, 0);
      expect(directory.devices.single.source, DeviceSource.emulator);
    });

    test(
      'native physical events are isolated while emulator mode is active',
      () async {
        final gateway = _EventGateway();
        final store = InMemoryDeviceSettingsStore(
          defaultDeviceId: fixtureOfflineDevice.id,
          authorizedDevices: const [fixtureOfflineDevice],
          emulatorSettings: const EmulatorDeviceSettings(enabled: true),
        );
        final directory = LocalDeviceDirectory(
          store: store,
          discoveryGateway: gateway,
        );

        await directory.load();
        final initialActiveDevices = directory.devices;

        gateway.add(
          fixtureOfflineDevice.copyWith(
            reachability: DeviceReachability.reachable,
            companionInstallState: CompanionInstallState.installed,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(directory.devices, initialActiveDevices);
        expect(
          (await store.readAuthorizedDevices()).single.reachability,
          DeviceReachability.reachable,
        );

        await directory.updateEmulatorSettings(const EmulatorDeviceSettings());

        expect(
          directory.devices.single.reachability,
          DeviceReachability.reachable,
        );

        await gateway.close();
        directory.dispose();
      },
    );

    test(
      'notifies listeners on mode switches and active emulator updates',
      () async {
        final directory = LocalDeviceDirectory(
          store: InMemoryDeviceSettingsStore(
            authorizedDevices: const [fixtureReadyDevice],
          ),
        );
        var notifications = 0;

        await directory.load();
        directory.addListener(() {
          notifications += 1;
        });

        await directory.updateEmulatorSettings(
          const EmulatorDeviceSettings(enabled: true),
        );
        await directory.updateEmulatorSettings(
          const EmulatorDeviceSettings(
            enabled: true,
            reachability: DeviceReachability.offline,
          ),
        );

        expect(notifications, 2);
        expect(
          directory.devices.single.reachability,
          DeviceReachability.offline,
        );
      },
    );
  });
}

class _SequenceGateway implements GarminDeviceDiscoveryGateway {
  _SequenceGateway(this.results);

  final List<Object> results;
  var _index = 0;

  @override
  Stream<GarminDevice> get deviceUpdates => const Stream<GarminDevice>.empty();

  @override
  Future<List<GarminDevice>> discoverDevices() async {
    final result = results[_index++];
    if (result is GarminDiscoveryError) {
      throw result;
    }
    return result as List<GarminDevice>;
  }
}

class _CountingGateway implements GarminDeviceDiscoveryGateway {
  _CountingGateway({required this.devices});

  final List<GarminDevice> devices;
  var discoveryCallCount = 0;

  @override
  Stream<GarminDevice> get deviceUpdates => const Stream<GarminDevice>.empty();

  @override
  Future<List<GarminDevice>> discoverDevices() async {
    discoveryCallCount += 1;
    return devices;
  }
}

class _UnexpectedErrorGateway implements GarminDeviceDiscoveryGateway {
  const _UnexpectedErrorGateway();

  @override
  Stream<GarminDevice> get deviceUpdates => const Stream<GarminDevice>.empty();

  @override
  Future<List<GarminDevice>> discoverDevices() async {
    throw StateError('stuck native refresh');
  }
}

class _EventGateway implements GarminDeviceDiscoveryGateway {
  final _controller = StreamController<GarminDevice>.broadcast();

  @override
  Stream<GarminDevice> get deviceUpdates => _controller.stream;

  @override
  Future<List<GarminDevice>> discoverDevices() async {
    return const <GarminDevice>[];
  }

  void add(GarminDevice device) {
    _controller.add(device);
  }

  Future<void> close() {
    return _controller.close();
  }
}
