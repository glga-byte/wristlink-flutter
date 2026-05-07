// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'string_device_settings_store.dart';

class WebDeviceSettingsStore extends StringDeviceSettingsStore {
  const WebDeviceSettingsStore();

  @override
  Future<String?> readString(String key) async {
    return html.window.localStorage[key];
  }

  @override
  Future<void> writeString(String key, String value) async {
    html.window.localStorage[key] = value;
  }
}
