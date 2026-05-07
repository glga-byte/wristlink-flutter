@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/app/platform/device_settings_store_provider.dart';
import 'package:wristlink_flutter/features/devices/data/unsupported_device_settings_store.dart';

void main() {
  test('uses explicit unsupported store on non-mobile IO platforms', () {
    expect(createDeviceSettingsStore(), isA<UnsupportedDeviceSettingsStore>());
  });
}
