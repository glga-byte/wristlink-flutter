import 'dart:io';

import '../../features/garmin_bridge/garmin_acknowledgement_gateway.dart';
import '../../features/garmin_bridge/garmin_send_gateway.dart';

GarminSendGateway createGarminSendGateway() {
  if (Platform.isAndroid || Platform.isIOS) {
    return MethodChannelGarminSendGateway();
  }
  return const UnsupportedGarminSendGateway();
}

GarminAcknowledgementGateway createGarminAcknowledgementGateway() {
  if (Platform.isAndroid || Platform.isIOS) {
    return EventChannelGarminAcknowledgementGateway();
  }
  return const UnsupportedGarminAcknowledgementGateway();
}
