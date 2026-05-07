import '../../features/devices/data/device_settings_store.dart';
import 'device_settings_store_provider_stub.dart'
    if (dart.library.io) 'device_settings_store_provider_io.dart'
    if (dart.library.html) 'device_settings_store_provider_web.dart'
    as platform;

DeviceSettingsStore createDeviceSettingsStore() {
  return platform.createDeviceSettingsStore();
}
