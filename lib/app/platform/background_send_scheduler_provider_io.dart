import 'dart:io';

import '../../features/send_queue/background/background_send_scheduler.dart';
import '../../features/send_queue/background/workmanager_background_send_scheduler.dart';

BackgroundSendScheduler createBackgroundSendScheduler({
  required Function callbackDispatcher,
}) {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return const UnsupportedBackgroundSendScheduler();
  }
  return WorkmanagerBackgroundSendScheduler(
    platform: Platform.isAndroid
        ? BackgroundSendPlatform.android
        : BackgroundSendPlatform.ios,
    callbackDispatcher: callbackDispatcher,
  );
}
