import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../devices/domain/garmin_device.dart';
import '../../payloads/message_contract.dart';
import '../domain/send_queue_record.dart';
import 'send_queue_repository.dart';

class SqliteSendQueueRepository implements SendQueueRepository {
  SqliteSendQueueRepository({
    required this.path,
    DatabaseFactory? databaseFactory,
  }) : _databaseFactory = databaseFactory ?? databaseFactorySqflitePlugin;

  static const schemaVersion = 2;
  static const defaultDatabaseName = 'wristlink-send-queue.db';

  final String path;
  final DatabaseFactory _databaseFactory;
  Database? _database;
  final List<QueueStorageDiagnostic> _diagnostics = [];

  @override
  List<QueueStorageDiagnostic> get diagnostics =>
      List.unmodifiable(_diagnostics);

  @override
  Future<void> initialize() async {
    if (_database != null) return;
    try {
      _database = await _databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onCreate: (database, version) async {
            await _createQueueTable(database);
            await _createQuarantineTable(database);
          },
          onUpgrade: (database, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await _createQuarantineTable(database);
            }
          },
          onDowngrade: (database, oldVersion, newVersion) async {
            throw StateError(
              'Refusing to downgrade send queue schema from '
              '$oldVersion to $newVersion.',
            );
          },
        ),
      );
      await _refreshDiagnostics();
    } catch (error) {
      throw QueueStorageException(
        QueueStorageErrorCode.unavailable,
        'The durable send queue could not be opened.',
        cause: error,
      );
    }
  }

  static Future<void> _createQueueTable(Database database) async {
    await database.execute('''
CREATE TABLE send_queue (
  message_id TEXT PRIMARY KEY,
  envelope_json TEXT NOT NULL,
  device_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('pending','sending','sent','failed')),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  failure_code TEXT,
  failure_message TEXT,
  failure_is_transient INTEGER,
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK(attempt_count >= 0),
  next_attempt_at INTEGER,
  acknowledgement_deadline INTEGER
)
''');
    await database.execute(
      'CREATE INDEX send_queue_eligible_idx '
      'ON send_queue(status, next_attempt_at, created_at)',
    );
  }

  static Future<void> _createQuarantineTable(Database database) =>
      database.execute('''
CREATE TABLE send_queue_quarantine (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  record_id TEXT,
  reason TEXT NOT NULL,
  row_json TEXT NOT NULL,
  quarantined_at INTEGER NOT NULL
)
''');

  Future<void> _refreshDiagnostics() async {
    final rows = await _db.query('send_queue_quarantine', orderBy: 'id ASC');
    _diagnostics
      ..clear()
      ..addAll(
        rows.map(
          (row) => QueueStorageDiagnostic(
            id: QueueStorageDiagnosticId(row['id']! as int),
            recordId: row['record_id'] as String?,
            message: row['reason']! as String,
          ),
        ),
      );
  }

  Database get _db {
    final database = _database;
    if (database == null) {
      throw const QueueStorageException(
        QueueStorageErrorCode.unavailable,
        'The durable send queue has not been initialized.',
      );
    }
    return database;
  }

  @override
  Future<SendQueueRecord> enqueue(SendQueueRecord record) async {
    if (record.status != SendQueueStatus.pending || record.deviceId == null) {
      throw const QueueStorageException(
        QueueStorageErrorCode.invalidTransition,
        'Only targeted pending records can be enqueued.',
      );
    }
    record.message.validate();
    try {
      await _db.transaction((transaction) async {
        await transaction.insert(
          'send_queue',
          _row(record),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      });
      return record;
    } on DatabaseException catch (error) {
      final duplicate = error.isUniqueConstraintError();
      throw QueueStorageException(
        duplicate
            ? QueueStorageErrorCode.duplicateMessageId
            : QueueStorageErrorCode.unavailable,
        duplicate
            ? 'A queue record already exists for ${record.id}.'
            : 'The point could not be durably queued.',
        cause: error,
      );
    }
  }

  @override
  Future<List<SendQueueRecord>> readAll() async {
    final records = await _db.transaction((transaction) async {
      final rows = await transaction.rawQuery(
        'SELECT rowid AS queue_rowid, * FROM send_queue '
        'ORDER BY updated_at DESC, created_at DESC',
      );
      final validRecords = <SendQueueRecord>[];
      for (final row in rows) {
        try {
          validRecords.add(_record(row));
        } catch (error) {
          await _quarantineRow(transaction, row, error);
        }
      }
      return validRecords;
    });
    await _refreshDiagnostics();
    return List.unmodifiable(records);
  }

  @override
  Future<void> removeQuarantinedRows(
    Set<QueueStorageDiagnosticId> diagnosticIds,
  ) async {
    if (diagnosticIds.isEmpty) return;
    try {
      final placeholders = List.filled(diagnosticIds.length, '?').join(',');
      await _db.delete(
        'send_queue_quarantine',
        where: 'id IN ($placeholders)',
        whereArgs: diagnosticIds.map((id) => id.value).toList(growable: false),
      );
      await _refreshDiagnostics();
    } on DatabaseException catch (error) {
      throw QueueStorageException(
        QueueStorageErrorCode.unavailable,
        'The corrupted queue data could not be removed.',
        cause: error,
      );
    }
  }

  Future<void> _quarantineRow(
    DatabaseExecutor database,
    Map<String, Object?> row,
    Object error,
  ) async {
    final queueRowId = row['queue_rowid']! as int;
    final recordId = row['message_id'] as String?;
    await database.insert('send_queue_quarantine', <String, Object?>{
      'record_id': recordId,
      'reason': 'A corrupted queue item was isolated: $error',
      'row_json': jsonEncode(
        Map<String, Object?>.of(row)..remove('queue_rowid'),
      ),
      'quarantined_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    });
    await database.delete(
      'send_queue',
      where: 'rowid = ?',
      whereArgs: [queueRowId],
    );
  }

  @override
  Future<SendQueueRecord?> findById(String messageId) async {
    final record = await _db.transaction((transaction) async {
      final rows = await transaction.rawQuery(
        'SELECT rowid AS queue_rowid, * FROM send_queue '
        'WHERE message_id = ? LIMIT 1',
        [messageId],
      );
      if (rows.isEmpty) return null;
      try {
        return _record(rows.single);
      } catch (error) {
        await _quarantineRow(transaction, rows.single, error);
        return null;
      }
    });
    await _refreshDiagnostics();
    return record;
  }

  @override
  Future<SendQueueRecord?> claimNextEligible(DateTime now) async {
    final nowUtc = now.toUtc();
    final claimed = await _db.transaction((transaction) async {
      final rows = await transaction.rawQuery(
        'SELECT rowid AS queue_rowid, * FROM send_queue '
        "WHERE status = 'pending' "
        'AND (next_attempt_at IS NULL OR next_attempt_at <= ?) '
        'ORDER BY created_at ASC',
        [nowUtc.millisecondsSinceEpoch],
      );
      for (final row in rows) {
        try {
          _record(row);
        } catch (error) {
          await _quarantineRow(transaction, row, error);
          continue;
        }
        final id = row['message_id']! as String;
        final count = await transaction.rawUpdate(
          "UPDATE send_queue SET status = 'sending', updated_at = ?, "
          'attempt_count = attempt_count + 1, next_attempt_at = NULL '
          "WHERE message_id = ? AND status = 'pending'",
          [nowUtc.millisecondsSinceEpoch, id],
        );
        if (count != 1) continue;
        final claimedRows = await transaction.query(
          'send_queue',
          where: 'message_id = ?',
          whereArgs: [id],
          limit: 1,
        );
        return _record(claimedRows.single);
      }
      return null;
    });
    await _refreshDiagnostics();
    return claimed;
  }

  @override
  Future<SendQueueRecord?> claimPending(
    String messageId,
    DateTime now, {
    bool ignoreSchedule = false,
  }) async {
    final nowUtc = now.toUtc();
    final claimed = await _db.transaction((transaction) async {
      final scheduleClause = ignoreSchedule
          ? ''
          : ' AND (next_attempt_at IS NULL OR next_attempt_at <= ?)';
      final whereArgs = <Object?>[
        messageId,
        if (!ignoreSchedule) nowUtc.millisecondsSinceEpoch,
      ];
      final rows = await transaction.rawQuery(
        'SELECT rowid AS queue_rowid, * FROM send_queue '
        "WHERE message_id = ? AND status = 'pending'$scheduleClause LIMIT 1",
        whereArgs,
      );
      if (rows.isEmpty) return null;
      try {
        _record(rows.single);
      } catch (error) {
        await _quarantineRow(transaction, rows.single, error);
        return null;
      }
      final count = await transaction.rawUpdate(
        "UPDATE send_queue SET status = 'sending', updated_at = ?, "
        'attempt_count = attempt_count + 1, next_attempt_at = NULL '
        "WHERE message_id = ? AND status = 'pending'$scheduleClause",
        <Object?>[
          nowUtc.millisecondsSinceEpoch,
          messageId,
          if (!ignoreSchedule) nowUtc.millisecondsSinceEpoch,
        ],
      );
      if (count != 1) return null;
      final claimedRows = await transaction.query(
        'send_queue',
        where: 'message_id = ?',
        whereArgs: [messageId],
        limit: 1,
      );
      return _record(claimedRows.single);
    });
    await _refreshDiagnostics();
    return claimed;
  }

  @override
  Future<SendQueueRecord> saveTransition(
    SendQueueRecord record, {
    required Set<SendQueueStatus> expectedStatuses,
  }) async {
    if (expectedStatuses.isEmpty) {
      throw const QueueStorageException(
        QueueStorageErrorCode.invalidTransition,
        'At least one expected queue status is required.',
      );
    }
    final placeholders = List.filled(expectedStatuses.length, '?').join(',');
    final count = await _db.update(
      'send_queue',
      _row(record)..remove('message_id'),
      where: 'message_id = ? AND status IN ($placeholders)',
      whereArgs: [record.id, ...expectedStatuses.map((status) => status.name)],
    );
    if (count != 1) {
      throw QueueStorageException(
        QueueStorageErrorCode.invalidTransition,
        'Queue record ${record.id} was not in an expected state.',
      );
    }
    return record;
  }

  @override
  Future<SendQueueRecord> retryFailed(String messageId, DateTime now) async {
    final current = await findById(messageId);
    if (current == null || current.status != SendQueueStatus.failed) {
      throw QueueStorageException(
        QueueStorageErrorCode.invalidTransition,
        'Only failed queue records can be explicitly retried.',
      );
    }
    return saveTransition(
      current.copyWith(
        status: SendQueueStatus.pending,
        updatedAt: now.toUtc(),
        clearFailure: true,
        clearNextAttemptAt: true,
        clearAcknowledgementDeadline: true,
      ),
      expectedStatuses: const {SendQueueStatus.failed},
    );
  }

  @override
  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }

  Map<String, Object?> _row(SendQueueRecord record) => <String, Object?>{
    'message_id': record.id,
    'envelope_json': jsonEncode(record.message.toJson()),
    'device_id': record.deviceId?.value,
    'status': record.status.name,
    'created_at': record.createdAt.toUtc().millisecondsSinceEpoch,
    'updated_at': record.updatedAt.toUtc().millisecondsSinceEpoch,
    'failure_code': record.failure?.code.name,
    'failure_message': record.failure?.message,
    'failure_is_transient': record.failure == null
        ? null
        : record.failure!.isTransient
        ? 1
        : 0,
    'attempt_count': record.attemptCount,
    'next_attempt_at': record.nextAttemptAt?.toUtc().millisecondsSinceEpoch,
    'acknowledgement_deadline': record.acknowledgementDeadline
        ?.toUtc()
        .millisecondsSinceEpoch,
  };

  SendQueueRecord _record(Map<String, Object?> row) {
    final rawEnvelope = jsonDecode(row['envelope_json']! as String);
    final rawFailureCode = row['failure_code'] as String?;
    final failureCode = rawFailureCode == null
        ? null
        : SendQueueFailureCode.values
              .where((value) => value.name == rawFailureCode)
              .firstOrNull;
    if (rawFailureCode != null && failureCode == null) {
      throw const FormatException('Unknown queue failure code.');
    }
    return SendQueueRecord(
      message: MessageEnvelope.fromJson(
        (rawEnvelope! as Map).cast<String, Object?>(),
      ),
      status: SendQueueStatus.values.singleWhere(
        (status) => status.name == row['status'],
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at']! as int,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at']! as int,
        isUtc: true,
      ),
      deviceId: GarminDeviceId(row['device_id']! as String),
      attemptCount: row['attempt_count']! as int,
      failure: failureCode == null
          ? null
          : SendQueueFailure(
              code: failureCode,
              message: row['failure_message']! as String,
              isTransient: (row['failure_is_transient']! as int) == 1,
            ),
      nextAttemptAt: _dateFromMillis(row['next_attempt_at']),
      acknowledgementDeadline: _dateFromMillis(row['acknowledgement_deadline']),
    );
  }

  DateTime? _dateFromMillis(Object? value) => value is int
      ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
      : null;
}
