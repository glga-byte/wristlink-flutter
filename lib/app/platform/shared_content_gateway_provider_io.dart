import 'dart:io';

import '../../features/send_point/share/shared_content_gateway.dart';

SharedContentGateway createSharedContentGateway() {
  if (Platform.isAndroid || Platform.isIOS) {
    return MethodChannelSharedContentGateway();
  }
  return const UnsupportedSharedContentGateway();
}
