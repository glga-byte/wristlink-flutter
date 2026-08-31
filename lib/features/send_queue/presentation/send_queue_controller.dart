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
  List<QueueStorageDiagnostic> _storageDiagnostics = const [];
  QueueStorageException? _storageError;
  var _isInitialized = false;
  var _isRemovingQuarantinedRows = false;

  List<SendQueueRecord> get records => _records;
  List<QueueStorageDiagnostic> get storageDiagnostics => _storageDiagnostics;
  QueueStorageException? get storageError => _storageError;
  bool get isInitialized => _isInitialized;
  bool get isRemovingQuarantinedRows => _isRemovingQuarantinedRows;

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
      _storageDiagnostics = List.unmodifiable(_repository.diagnostics);
      _storageError = null;
      notifyListeners();
    } on QueueStorageException catch (error) {
      _storageError = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeQuarantinedRows() async {
    if (_storageDiagnostics.isEmpty || _isRemovingQuarantinedRows) return;
    _isRemovingQuarantinedRows = true;
    notifyListeners();
    try {
      await _repository.removeQuarantinedRows(
        _storageDiagnostics.map((diagnostic) => diagnostic.id).toSet(),
      );
      await refresh();
    } on QueueStorageException catch (error) {
      _storageError = error;
      notifyListeners();
      rethrow;
    } finally {
      _isRemovingQuarantinedRows = false;
      notifyListeners();
    }
  }

  Future<void> disposeRepository() => _repository.close();
}
