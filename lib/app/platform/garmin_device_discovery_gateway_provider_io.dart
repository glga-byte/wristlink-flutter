import 'dart:io';

import '../../features/garmin_bridge/garmin_device_discovery_gateway.dart';

GarminDeviceDiscoveryGateway createGarminDeviceDiscoveryGateway() {
  if (Platform.isAndroid || Platform.isIOS) {
    return MethodChannelGarminDeviceDiscoveryGateway();
  }
  return const UnsupportedGarminDeviceDiscoveryGateway();
}
