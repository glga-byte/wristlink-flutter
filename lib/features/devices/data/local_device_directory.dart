import 'package:flutter/material.dart';

import '../../developer_tools/domain/emulator_device_settings.dart';
import '../../garmin_bridge/garmin_device_discovery_gateway.dart';
import '../domain/device_directory.dart';
import '../domain/garmin_device.dart';
import 'device_settings_store.dart';
import 'in_memory_device_settings_store.dart';

class LocalDeviceDirectory extends ChangeNotifier implements DeviceDirectory {
  LocalDeviceDirectory({
    required DeviceSettingsStore store,
    GarminDeviceDiscoveryGateway discoveryGateway =
        const UnsupportedGarminDeviceDiscoveryGateway(),
  }) : _store = store,
       _discoveryGateway = discoveryGateway {
    _defaultDeviceId = sampleDefaultDeviceId;
    _physicalDevices = samplePhysicalDevices;
    _recompose();
  }

  final DeviceSettingsStore _store;
  final GarminDeviceDiscoveryGateway _discoveryGateway;

  GarminDeviceId? _defaultDeviceId;
  List<GarminDevice> _physicalDevices = const <GarminDevice>[];
  EmulatorDeviceSettings _emulatorSettings = const EmulatorDeviceSettings();
  List<GarminDevice> _devices = const <GarminDevice>[];
  GarminDiscoveryError? _lastRefreshError;

  @override
  List<GarminDevice> get devices => List<GarminDevice>.unmodifiable(_devices);

  @override
  GarminDeviceId? get defaultDeviceId => _defaultDeviceId;

  EmulatorDeviceSettings get emulatorSettings => _emulatorSettings;

  @override
  GarminDiscoveryError? get lastRefreshError => _lastRefreshError;

  Future<void> load() async {
    _defaultDeviceId = await _store.readDefaultDeviceId();
    _physicalDevices = await _store.readAuthorizedDevices();
    _emulatorSettings = await _store.readEmulatorSettings();

    if (_defaultDeviceId == null && _physicalDevices.isNotEmpty) {
      _defaultDeviceId = _physicalDevices.first.id;
    }

    _recompose();
    notifyListeners();
  }

  @override
  Future<DeviceRefreshResult> refreshDevices() async {
    try {
      final discoveredDevices = await _discoveryGateway.discoverDevices();
      await _store.replaceAuthorizedDevices(discoveredDevices);
      _physicalDevices = discoveredDevices;
      _lastRefreshError = null;
      _recompose();
      notifyListeners();
      return DeviceRefreshSuccess(devices);
    } on GarminDiscoveryError catch (error) {
      _lastRefreshError = error;
      notifyListeners();
      return DeviceRefreshFailure(error);
    }
  }

  @override
  Future<void> setDefaultDevice(GarminDeviceId id) async {
    _defaultDeviceId = id;
    await _store.writeDefaultDeviceId(id);
    _recompose();
    notifyListeners();
  }

  Future<void> updateEmulatorSettings(EmulatorDeviceSettings settings) async {
    _emulatorSettings = settings;
    await _store.writeEmulatorSettings(settings);

    if (settings.enabled) {
      _defaultDeviceId = _emulatorDevice.id;
      await _store.writeDefaultDeviceId(_emulatorDevice.id);
    } else if (_physicalDevices.isNotEmpty &&
        _defaultDeviceId == _emulatorDevice.id) {
      _defaultDeviceId = _physicalDevices.first.id;
      await _store.writeDefaultDeviceId(_physicalDevices.first.id);
    }

    _recompose();
    notifyListeners();
  }

  @override
  SendTargetResolution resolveSendTarget() {
    if (_devices.isEmpty) {
      return const SendTargetUnavailable(SendTargetUnavailableReason.noDevices);
    }

    final defaultId = _defaultDeviceId;
    if (defaultId == null) {
      return const SendTargetUnavailable(
        SendTargetUnavailableReason.noDefaultDevice,
      );
    }

    final defaultDevice = _devices.where((device) => device.id == defaultId);
    if (defaultDevice.isEmpty) {
      return const SendTargetUnavailable(
        SendTargetUnavailableReason.defaultDeviceMissing,
      );
    }

    final device = defaultDevice.first;
    if (device.isReady) {
      return SendTargetReady(device);
    }

    if (device.companionInstallState == CompanionInstallState.missing) {
      return SendTargetUnavailable(
        SendTargetUnavailableReason.companionMissing,
        device: device,
      );
    }

    if (device.reachability == DeviceReachability.offline ||
        device.reachability == DeviceReachability.unknown) {
      return SendTargetUnavailable(
        SendTargetUnavailableReason.defaultDeviceOffline,
        device: device,
      );
    }

    return SendTargetUnavailable(
      SendTargetUnavailableReason.deviceNotReady,
      device: device,
    );
  }

  void _recompose() {
    final effectiveDevices = _emulatorSettings.enabled
        ? <GarminDevice>[_emulatorDevice]
        : _physicalDevices;
    _devices = effectiveDevices
        .map((device) {
          return device.copyWith(isDefault: device.id == _defaultDeviceId);
        })
        .toList(growable: false);
  }

  GarminDevice get _emulatorDevice {
    return GarminDevice(
      id: const GarminDeviceId('emulator:wristlink-dev-watch'),
      name: 'WristLink Emulator',
      source: DeviceSource.emulator,
      reachability: _emulatorSettings.reachability,
      companionInstallState: _emulatorSettings.companionInstallState,
      metadata: const GarminDeviceMetadata(
        modelName: 'Connect IQ Emulator',
        family: 'Developer Tools',
      ),
      accentColor: const Color(0xFFFFCF33),
    );
  }
}
