import '../../features/garmin_bridge/garmin_acknowledgement_gateway.dart';
import '../../features/garmin_bridge/garmin_send_gateway.dart';

GarminSendGateway createGarminSendGateway() {
  return const UnsupportedGarminSendGateway();
}

GarminAcknowledgementGateway createGarminAcknowledgementGateway() {
  return const UnsupportedGarminAcknowledgementGateway();
}
