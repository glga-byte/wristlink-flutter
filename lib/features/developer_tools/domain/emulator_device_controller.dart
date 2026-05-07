import 'package:flutter/foundation.dart';

import 'emulator_device_settings.dart';

abstract interface class EmulatorDeviceController implements Listenable {
  EmulatorDeviceSettings get emulatorSettings;

  Future<void> updateEmulatorSettings(EmulatorDeviceSettings settings);
}
