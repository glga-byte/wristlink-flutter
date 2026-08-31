import '../../features/send_queue/background/background_send_scheduler.dart';
import 'background_send_scheduler_provider_stub.dart'
    if (dart.library.io) 'background_send_scheduler_provider_io.dart'
    as platform;

BackgroundSendScheduler createBackgroundSendScheduler({
  required Function callbackDispatcher,
}) {
  return platform.createBackgroundSendScheduler(
    callbackDispatcher: callbackDispatcher,
  );
}
