import '../../features/garmin_bridge/garmin_acknowledgement_gateway.dart';
import '../../features/garmin_bridge/garmin_send_gateway.dart';
import 'garmin_delivery_gateway_provider_stub.dart'
    if (dart.library.io) 'garmin_delivery_gateway_provider_io.dart'
    as platform;

GarminSendGateway createGarminSendGateway() {
  return platform.createGarminSendGateway();
}

GarminAcknowledgementGateway createGarminAcknowledgementGateway() {
  return platform.createGarminAcknowledgementGateway();
}
