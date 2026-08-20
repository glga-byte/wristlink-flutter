import '../../features/send_queue/background/background_send_scheduler.dart';

BackgroundSendScheduler createBackgroundSendScheduler({
  required Function callbackDispatcher,
}) {
  return const UnsupportedBackgroundSendScheduler();
}
