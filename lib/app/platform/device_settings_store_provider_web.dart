import '../../features/devices/data/device_settings_store.dart';
import '../../features/devices/data/web_device_settings_store.dart';

DeviceSettingsStore createDeviceSettingsStore() {
  return const WebDeviceSettingsStore();
}
