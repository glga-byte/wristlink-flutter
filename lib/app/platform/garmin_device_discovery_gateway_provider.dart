import '../../features/garmin_bridge/garmin_device_discovery_gateway.dart';
import 'garmin_device_discovery_gateway_provider_stub.dart'
    if (dart.library.io) 'garmin_device_discovery_gateway_provider_io.dart'
    if (dart.library.html) 'garmin_device_discovery_gateway_provider_web.dart'
    as platform;

GarminDeviceDiscoveryGateway createGarminDeviceDiscoveryGateway() {
  return platform.createGarminDeviceDiscoveryGateway();
}
