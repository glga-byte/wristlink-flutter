import '../../send_queue/application/send_queue_delivery_service.dart';
import '../../send_queue/domain/send_queue_record.dart';

abstract interface class PointQueueActions {
  Future<SendQueueRecord> submit(SendQueueRecord record);

  Future<SendQueueRecord> retry(String messageId);
}

class DeliveryPointQueueActions implements PointQueueActions {
  const DeliveryPointQueueActions(this._service);

  final SendQueueDeliveryService _service;

  @override
  Future<SendQueueRecord> retry(String messageId) => _service.retry(messageId);

  @override
  Future<SendQueueRecord> submit(SendQueueRecord record) =>
      _service.submit(record);
}
