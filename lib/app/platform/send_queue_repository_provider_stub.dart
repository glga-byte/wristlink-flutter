import '../../features/send_queue/data/send_queue_repository.dart';

Future<SendQueueRepository> createSendQueueRepository() async =>
    const UnsupportedSendQueueRepository();
