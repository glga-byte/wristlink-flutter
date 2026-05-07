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
         authorizedDevices ?? const <GarminDevice>[],
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
