import 'package:flutter/material.dart';

import '../features/devices/data/device_settings_store.dart';
import '../features/garmin_bridge/garmin_device_discovery_gateway.dart';
import 'wristlink_app_shell.dart';

class WristLinkApp extends StatelessWidget {
  const WristLinkApp({
    super.key,
    this.deviceSettingsStore,
    this.discoveryGateway,
  });

  final DeviceSettingsStore? deviceSettingsStore;
  final GarminDeviceDiscoveryGateway? discoveryGateway;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WristLink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006B5F),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: WristLinkAppShell(
        deviceSettingsStore: deviceSettingsStore,
        discoveryGateway: discoveryGateway,
      ),
    );
  }
}
