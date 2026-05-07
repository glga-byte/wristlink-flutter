import 'package:flutter/services.dart';

import 'string_device_settings_store.dart';

class MethodChannelDeviceSettingsStore extends StringDeviceSettingsStore {
  MethodChannelDeviceSettingsStore({
    MethodChannel channel = const MethodChannel('wristlink/device_settings'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<String?> readString(String key) {
    return _channel.invokeMethod<String>('readString', {'key': key});
  }

  @override
  Future<void> writeString(String key, String value) async {
    await _channel.invokeMethod<void>('writeString', {
      'key': key,
      'value': value,
    });
  }
}
