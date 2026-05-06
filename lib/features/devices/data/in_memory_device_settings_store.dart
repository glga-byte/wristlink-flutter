import 'package:flutter/material.dart';

import '../../developer_tools/domain/emulator_device_settings.dart';
import '../domain/garmin_device.dart';
import 'device_settings_store.dart';

class InMemoryDeviceSettingsStore implements DeviceSettingsStore {
  InMemoryDeviceSettingsStore({
    GarminDeviceId? defaultDeviceId,
    List<GarminDevice>? authorizedDevices,
    EmulatorDeviceSettings emulatorSettings = const EmulatorDeviceSettings(),
  }) : _defaultDeviceId = defaultDeviceId,
       _authorizedDevices = List<GarminDevice>.of(
         authorizedDevices ?? samplePhysicalDevices,
       ),
       _emulatorSettings = emulatorSettings;

  GarminDeviceId? _defaultDeviceId;
  List<GarminDevice> _authorizedDevices;
  EmulatorDeviceSettings _emulatorSettings;

  @override
  Future<GarminDeviceId?> readDefaultDeviceId() async => _defaultDeviceId;

  @override
  Future<void> writeDefaultDeviceId(GarminDeviceId id) async {
    _defaultDeviceId = id;
  }

  @override
  Future<List<GarminDevice>> readAuthorizedDevices() async {
    return List<GarminDevice>.of(_authorizedDevices);
  }

  @override
  Future<void> replaceAuthorizedDevices(List<GarminDevice> devices) async {
    _authorizedDevices = List<GarminDevice>.of(devices);
  }

  @override
  Future<EmulatorDeviceSettings> readEmulatorSettings() async {
    return _emulatorSettings;
  }

  @override
  Future<void> writeEmulatorSettings(EmulatorDeviceSettings settings) async {
    _emulatorSettings = settings;
  }
}

const sampleDefaultDeviceId = GarminDeviceId('physical:forerunner-965');

final samplePhysicalDevices = <GarminDevice>[
  const GarminDevice(
    id: sampleDefaultDeviceId,
    name: 'Forerunner 965',
    source: DeviceSource.physical,
    reachability: DeviceReachability.reachable,
    companionInstallState: CompanionInstallState.installed,
    isDefault: true,
    metadata: GarminDeviceMetadata(modelName: 'Forerunner 965'),
    accentColor: Color(0xFF111111),
  ),
  GarminDevice(
    id: const GarminDeviceId('physical:fenix-7'),
    name: 'Fenix 7',
    source: DeviceSource.physical,
    reachability: DeviceReachability.nearby,
    companionInstallState: CompanionInstallState.missing,
    metadata: GarminDeviceMetadata(
      modelName: 'Fenix 7',
      lastSeen: DateTime.utc(2026, 5, 5),
    ),
    accentColor: const Color(0xFF2F7D80),
  ),
  GarminDevice(
    id: const GarminDeviceId('physical:venu-3'),
    name: 'Venu 3',
    source: DeviceSource.physical,
    reachability: DeviceReachability.offline,
    companionInstallState: CompanionInstallState.unknown,
    metadata: GarminDeviceMetadata(
      modelName: 'Venu 3',
      lastSeen: DateTime.utc(2026, 5, 5),
    ),
    accentColor: const Color(0xFFD6D6D1),
  ),
];
