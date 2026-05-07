import 'package:flutter/foundation.dart';

import '../../developer_tools/domain/emulator_device_settings.dart';
import '../domain/device_directory.dart';
import '../domain/garmin_device.dart';
import 'device_send_target_resolution.dart';

const emulatorGarminDeviceId = GarminDeviceId('emulator:wristlink-dev-watch');

class EmulatedDeviceDirectory extends ChangeNotifier
    implements DeviceDirectoryController {
  EmulatedDeviceDirectory({
    EmulatorDeviceSettings settings = const EmulatorDeviceSettings(),
  }) : _settings = settings {
    _recompose();
  }

  EmulatorDeviceSettings _settings;
  late List<GarminDevice> _devices;

  EmulatorDeviceSettings get settings => _settings;

  @override
  List<GarminDevice> get devices => List<GarminDevice>.unmodifiable(_devices);

  @override
  GarminDeviceId get defaultDeviceId => emulatorGarminDeviceId;

  @override
  GarminDiscoveryError? get lastRefreshError => null;

  @override
  DeviceDirectoryEmptyReason? get emptyReason => null;

  void updateSettings(EmulatorDeviceSettings settings, {bool notify = true}) {
    _settings = settings;
    _recompose();
    if (notify) {
      notifyListeners();
    }
  }

  @override
  Future<DeviceRefreshResult> refreshDevices() async {
    return DeviceRefreshSuccess(devices);
  }

  @override
  Future<void> setDefaultDevice(GarminDeviceId id) async {
    if (id != emulatorGarminDeviceId) {
      return;
    }
    _recompose();
    notifyListeners();
  }

  @override
  SendTargetResolution resolveSendTarget() {
    return resolveDeviceSendTarget(
      devices: devices,
      defaultDeviceId: defaultDeviceId,
    );
  }

  void _recompose() {
    _devices = <GarminDevice>[_emulatorDevice];
  }

  GarminDevice get _emulatorDevice {
    return GarminDevice(
      id: emulatorGarminDeviceId,
      name: 'WristLink Emulator',
      source: DeviceSource.emulator,
      reachability: _settings.reachability,
      companionInstallState: _settings.companionInstallState,
      isDefault: true,
      metadata: const GarminDeviceMetadata(
        modelName: 'Connect IQ Emulator',
        family: 'Developer Tools',
      ),
    );
  }
}
