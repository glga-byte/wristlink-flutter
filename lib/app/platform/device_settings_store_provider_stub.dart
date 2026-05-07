import '../../features/devices/data/device_settings_store.dart';
import '../../features/devices/data/unsupported_device_settings_store.dart';

DeviceSettingsStore createDeviceSettingsStore() {
  return const UnsupportedDeviceSettingsStore();
}
