import '../domain/garmin_device.dart';
import 'device_settings_store.dart';

class InMemoryDeviceSettingsStore implements DeviceSettingsStore {
  InMemoryDeviceSettingsStore({
    GarminDeviceId? defaultDeviceId,
    List<GarminDevice>? authorizedDevices,
  }) : _defaultDeviceId = defaultDeviceId,
       _authorizedDevices = List<GarminDevice>.of(
         authorizedDevices ?? const <GarminDevice>[],
       );

  GarminDeviceId? _defaultDeviceId;
  List<GarminDevice> _authorizedDevices;

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
}
