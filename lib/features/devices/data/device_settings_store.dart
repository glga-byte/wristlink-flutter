import '../domain/garmin_device.dart';

abstract interface class DeviceSettingsStore {
  Future<GarminDeviceId?> readDefaultDeviceId();

  Future<void> writeDefaultDeviceId(GarminDeviceId id);

  Future<List<GarminDevice>> readAuthorizedDevices();

  Future<void> replaceAuthorizedDevices(List<GarminDevice> devices);
}
