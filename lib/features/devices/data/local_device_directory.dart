import 'package:flutter/foundation.dart';

import '../../developer_tools/domain/emulator_device_controller.dart';
import '../../developer_tools/domain/emulator_device_settings.dart';
import '../../garmin_bridge/garmin_device_discovery_gateway.dart';
import '../domain/device_directory.dart';
import '../domain/garmin_device.dart';
import 'device_settings_store.dart';
import 'emulated_device_directory.dart';
import 'physical_device_directory.dart';

class LocalDeviceDirectory extends ChangeNotifier
    implements DeviceDirectoryController, EmulatorDeviceController {
  LocalDeviceDirectory({
    required DeviceSettingsStore store,
    GarminDeviceDiscoveryGateway discoveryGateway =
        const UnsupportedGarminDeviceDiscoveryGateway(),
  }) : _store = store,
       _physicalDirectory = PhysicalDeviceDirectory(
         store: store,
         discoveryGateway: discoveryGateway,
       ),
       _emulatedDirectory = EmulatedDeviceDirectory() {
    _physicalDirectory.addListener(_handlePhysicalDirectoryChanged);
    _emulatedDirectory.addListener(_handleEmulatedDirectoryChanged);
  }

  final DeviceSettingsStore _store;
  final PhysicalDeviceDirectory _physicalDirectory;
  final EmulatedDeviceDirectory _emulatedDirectory;

  EmulatorDeviceSettings _emulatorSettings = const EmulatorDeviceSettings();

  @override
  List<GarminDevice> get devices => _activeDirectory.devices;

  @override
  GarminDeviceId? get defaultDeviceId => _activeDirectory.defaultDeviceId;

  @override
  EmulatorDeviceSettings get emulatorSettings => _emulatorSettings;

  @override
  GarminDiscoveryError? get lastRefreshError =>
      _activeDirectory.lastRefreshError;

  @override
  DeviceDirectoryEmptyReason? get emptyReason => _activeDirectory.emptyReason;

  Future<void> load() async {
    _emulatorSettings = await _store.readEmulatorSettings();
    _emulatedDirectory.updateSettings(_emulatorSettings, notify: false);
    await _physicalDirectory.load();
    notifyListeners();
  }

  @override
  Future<DeviceRefreshResult> refreshDevices() async {
    return _activeDirectory.refreshDevices();
  }

  @override
  Future<void> setDefaultDevice(GarminDeviceId id) async {
    return _activeDirectory.setDefaultDevice(id);
  }

  @override
  void dispose() {
    _physicalDirectory.removeListener(_handlePhysicalDirectoryChanged);
    _emulatedDirectory.removeListener(_handleEmulatedDirectoryChanged);
    _physicalDirectory.dispose();
    _emulatedDirectory.dispose();
    super.dispose();
  }

  @override
  Future<void> updateEmulatorSettings(EmulatorDeviceSettings settings) async {
    _emulatorSettings = settings;
    await _store.writeEmulatorSettings(settings);
    _emulatedDirectory.updateSettings(settings, notify: false);
    notifyListeners();
  }

  @override
  SendTargetResolution resolveSendTarget() {
    return _activeDirectory.resolveSendTarget();
  }

  DeviceDirectoryController get _activeDirectory {
    return _emulatorSettings.enabled ? _emulatedDirectory : _physicalDirectory;
  }

  void _handlePhysicalDirectoryChanged() {
    if (!_emulatorSettings.enabled) {
      notifyListeners();
    }
  }

  void _handleEmulatedDirectoryChanged() {
    if (_emulatorSettings.enabled) {
      notifyListeners();
    }
  }
}
