import '../../developer_tools/domain/emulator_device_settings.dart';
import '../domain/garmin_device.dart';
import 'device_settings_store.dart';

class UnsupportedDeviceSettingsStore implements DeviceSettingsStore {
  const UnsupportedDeviceSettingsStore();

  Never _throwUnsupported() {
    throw UnsupportedError(
      'Device settings storage is not supported on this platform.',
    );
  }

  @override
  Future<GarminDeviceId?> readDefaultDeviceId() async => _throwUnsupported();

  @override
  Future<void> writeDefaultDeviceId(GarminDeviceId id) async {
    _throwUnsupported();
  }

  @override
  Future<List<GarminDevice>> readAuthorizedDevices() async =>
      _throwUnsupported();

  @override
  Future<void> replaceAuthorizedDevices(List<GarminDevice> devices) async {
    _throwUnsupported();
  }

  @override
  Future<EmulatorDeviceSettings> readEmulatorSettings() async =>
      _throwUnsupported();

  @override
  Future<void> writeEmulatorSettings(EmulatorDeviceSettings settings) async {
    _throwUnsupported();
  }
}
