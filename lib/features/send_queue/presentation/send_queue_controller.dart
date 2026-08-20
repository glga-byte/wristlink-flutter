import 'package:flutter/foundation.dart';

import '../data/send_queue_repository.dart';
import '../domain/send_queue_record.dart';

enum QueuePresentationStatus { queued, sending, sent, failed }

QueuePresentationStatus queuePresentationStatus(SendQueueRecord record) =>
    switch (record.status) {
      SendQueueStatus.pending => QueuePresentationStatus.queued,
      SendQueueStatus.sending => QueuePresentationStatus.sending,
      SendQueueStatus.sent => QueuePresentationStatus.sent,
      SendQueueStatus.failed => QueuePresentationStatus.failed,
    };

class SendQueueController extends ChangeNotifier {
  SendQueueController(this._repository);

  final SendQueueRepository _repository;
  List<SendQueueRecord> _records = const [];
  QueueStorageException? _storageError;
  var _isInitialized = false;

  List<SendQueueRecord> get records => _records;
  QueueStorageException? get storageError => _storageError;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      await _repository.initialize();
      await refresh();
      _isInitialized = true;
    } on QueueStorageException catch (error) {
      _storageError = error;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<SendQueueRecord> enqueue(SendQueueRecord record) async {
    try {
      final stored = await _repository.enqueue(record);
      await refresh();
      return stored;
    } on QueueStorageException catch (error) {
      _storageError = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refresh() async {
    try {
      _records = List.unmodifiable(await _repository.readAll());
      _storageError = null;
      notifyListeners();
    } on QueueStorageException catch (error) {
      _storageError = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disposeRepository() => _repository.close();
}
