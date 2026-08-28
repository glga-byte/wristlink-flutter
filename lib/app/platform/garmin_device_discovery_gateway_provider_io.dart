import 'dart:io';

import '../../features/garmin_bridge/garmin_device_discovery_gateway.dart';

GarminDeviceDiscoveryGateway createGarminDeviceDiscoveryGateway() {
  return createGarminDeviceDiscoveryGatewayForPlatform(
    isAndroid: Platform.isAndroid,
    isIOS: Platform.isIOS,
  );
}

GarminDeviceDiscoveryGateway createGarminDeviceDiscoveryGatewayForPlatform({
  required bool isAndroid,
  required bool isIOS,
  GarminDeviceDiscoveryGateway Function()? mobileGatewayFactory,
}) {
  if (isAndroid || isIOS) {
    return (mobileGatewayFactory ??
        MethodChannelGarminDeviceDiscoveryGateway.new)();
  }
  return const UnsupportedGarminDeviceDiscoveryGateway();
}
