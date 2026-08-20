import 'dart:async';

import 'package:wristlink_flutter/features/send_point/application/point_queue_actions.dart';
import 'package:wristlink_flutter/features/send_point/data/google_maps_short_link_resolver.dart';
import 'package:wristlink_flutter/features/send_queue/data/send_queue_repository.dart';
import 'package:wristlink_flutter/features/send_queue/domain/send_queue_record.dart';

class MemorySendQueueRepository implements SendQueueRepository {
  final Map<String, SendQueueRecord> _records = {};
  var initialized = false;

  @override
  List<QueueStorageDiagnostic> get diagnostics => const [];

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<SendQueueRecord> enqueue(SendQueueRecord record) async {
    if (_records.containsKey(record.id)) {
      throw const QueueStorageException(
        QueueStorageErrorCode.duplicateMessageId,
        'Duplicate message id.',
      );
    }
    _records[record.id] = record;
    return record;
  }

  @override
  Future<List<SendQueueRecord>> readAll() async {
    final values = _records.values.toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return values;
  }

  @override
  Future<SendQueueRecord?> findById(String messageId) async =>
      _records[messageId];

  @override
  Future<SendQueueRecord?> claimNextEligible(DateTime now) async {
    final pending =
        _records.values
            .where((record) => record.status == SendQueueStatus.pending)
            .toList()
          ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    if (pending.isEmpty) return null;
    return claimPending(pending.first.id, now);
  }

  @override
  Future<SendQueueRecord?> claimPending(
    String messageId,
    DateTime now, {
    bool ignoreSchedule = false,
  }) async {
    final record = _records[messageId];
    if (record == null || record.status != SendQueueStatus.pending) return null;
    if (!ignoreSchedule &&
        record.nextAttemptAt != null &&
        record.nextAttemptAt!.isAfter(now)) {
      return null;
    }
    final claimed = record.copyWith(
      status: SendQueueStatus.sending,
      updatedAt: now,
      attemptCount: record.attemptCount + 1,
      clearFailure: true,
    );
    _records[messageId] = claimed;
    return claimed;
  }

  @override
  Future<SendQueueRecord> saveTransition(
    SendQueueRecord record, {
    required Set<SendQueueStatus> expectedStatuses,
  }) async {
    final current = _records[record.id];
    if (current == null || !expectedStatuses.contains(current.status)) {
      throw const QueueStorageException(
        QueueStorageErrorCode.invalidTransition,
        'Invalid transition.',
      );
    }
    _records[record.id] = record;
    return record;
  }

  @override
  Future<SendQueueRecord> retryFailed(String messageId, DateTime now) async {
    final record = _records[messageId];
    if (record == null || record.status != SendQueueStatus.failed) {
      throw const QueueStorageException(
        QueueStorageErrorCode.invalidTransition,
        'Only failed records can be retried.',
      );
    }
    final retried = record.copyWith(
      status: SendQueueStatus.pending,
      updatedAt: now,
      clearFailure: true,
      clearNextAttemptAt: true,
      clearAcknowledgementDeadline: true,
    );
    _records[messageId] = retried;
    return retried;
  }

  @override
  Future<void> close() async {}

  void replace(SendQueueRecord record) => _records[record.id] = record;
}

class FakePointQueueActions implements PointQueueActions {
  FakePointQueueActions({this.resultStatus = SendQueueStatus.pending});

  final SendQueueStatus resultStatus;
  final List<SendQueueRecord> submissions = [];
  final List<String> retries = [];

  @override
  Future<SendQueueRecord> submit(SendQueueRecord record) async {
    submissions.add(record);
    return record.copyWith(status: resultStatus);
  }

  @override
  Future<SendQueueRecord> retry(String messageId) async {
    retries.add(messageId);
    throw UnimplementedError('Provide repository-backed retry when needed.');
  }
}

class FixedShortLinkResolver implements GoogleMapsShortLinkResolver {
  const FixedShortLinkResolver({this.destination});

  final Uri? destination;

  @override
  Future<Uri> resolve(Uri shortLink) async =>
      destination ?? Uri.parse('https://google.com/maps/@47.3769,8.5417,15z');
}

class SequencedShortLinkResolver implements GoogleMapsShortLinkResolver {
  SequencedShortLinkResolver(this.results);

  final List<Object> results;
  var calls = 0;

  @override
  Future<Uri> resolve(Uri shortLink) async {
    final result = results[calls++];
    if (result is Uri) return result;
    throw result;
  }
}
