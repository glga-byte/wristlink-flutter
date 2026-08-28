import '../domain/send_queue_record.dart';

enum QueueStorageErrorCode {
  unsupportedPlatform,
  unavailable,
  duplicateMessageId,
  invalidTransition,
  corruptedRow,
}

class QueueStorageException implements Exception {
  const QueueStorageException(this.code, this.message, {this.cause});

  final QueueStorageErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'QueueStorageException($code, $message)';
}

class QueueStorageDiagnostic {
  const QueueStorageDiagnostic({
    required this.id,
    required this.recordId,
    required this.message,
  });

  final QueueStorageDiagnosticId id;
  final String? recordId;
  final String message;
}

class QueueStorageDiagnosticId {
  const QueueStorageDiagnosticId(this.value);

  final int value;

  @override
  bool operator ==(Object other) =>
      other is QueueStorageDiagnosticId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'QueueStorageDiagnosticId($value)';
}

abstract interface class SendQueueRepository {
  List<QueueStorageDiagnostic> get diagnostics;

  Future<void> initialize();

  Future<SendQueueRecord> enqueue(SendQueueRecord record);

  Future<List<SendQueueRecord>> readAll();

  Future<void> removeQuarantinedRows(
    Set<QueueStorageDiagnosticId> diagnosticIds,
  );

  Future<SendQueueRecord?> findById(String messageId);

  Future<SendQueueRecord?> claimNextEligible(DateTime now);

  Future<SendQueueRecord?> claimPending(
    String messageId,
    DateTime now, {
    bool ignoreSchedule = false,
  });

  Future<SendQueueRecord> saveTransition(
    SendQueueRecord record, {
    required Set<SendQueueStatus> expectedStatuses,
  });

  Future<SendQueueRecord> retryFailed(String messageId, DateTime now);

  Future<void> close();
}

class UnsupportedSendQueueRepository implements SendQueueRepository {
  const UnsupportedSendQueueRepository();

  Never _unsupported() => throw const QueueStorageException(
    QueueStorageErrorCode.unsupportedPlatform,
    'Durable send queue storage is unavailable on this platform.',
  );

  @override
  List<QueueStorageDiagnostic> get diagnostics => const [];

  @override
  Future<SendQueueRecord?> claimNextEligible(DateTime now) async =>
      _unsupported();

  @override
  Future<SendQueueRecord?> claimPending(
    String messageId,
    DateTime now, {
    bool ignoreSchedule = false,
  }) async => _unsupported();

  @override
  Future<void> close() async {}

  @override
  Future<SendQueueRecord> enqueue(SendQueueRecord record) async =>
      _unsupported();

  @override
  Future<SendQueueRecord?> findById(String messageId) async => _unsupported();

  @override
  Future<void> initialize() async => _unsupported();

  @override
  Future<List<SendQueueRecord>> readAll() async => _unsupported();

  @override
  Future<void> removeQuarantinedRows(
    Set<QueueStorageDiagnosticId> diagnosticIds,
  ) async => _unsupported();

  @override
  Future<SendQueueRecord> retryFailed(String messageId, DateTime now) async =>
      _unsupported();

  @override
  Future<SendQueueRecord> saveTransition(
    SendQueueRecord record, {
    required Set<SendQueueStatus> expectedStatuses,
  }) async => _unsupported();
}
