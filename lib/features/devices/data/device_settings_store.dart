import '../domain/garmin_device.dart';
import '../../developer_tools/domain/emulator_device_settings.dart';

abstract interface class DeviceSettingsStore {
  Future<GarminDeviceId?> readDefaultDeviceId();

  Future<void> writeDefaultDeviceId(GarminDeviceId id);

  Future<List<GarminDevice>> readAuthorizedDevices();

  Future<void> replaceAuthorizedDevices(List<GarminDevice> devices);

  Future<EmulatorDeviceSettings> readEmulatorSettings();

  Future<void> writeEmulatorSettings(EmulatorDeviceSettings settings);
}
