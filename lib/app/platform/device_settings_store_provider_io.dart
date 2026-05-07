import 'dart:io';

import '../../features/devices/data/device_settings_store.dart';
import '../../features/devices/data/method_channel_device_settings_store.dart';
import '../../features/devices/data/unsupported_device_settings_store.dart';

DeviceSettingsStore createDeviceSettingsStore() {
  if (Platform.isAndroid || Platform.isIOS) {
    return MethodChannelDeviceSettingsStore();
  }
  return const UnsupportedDeviceSettingsStore();
}
