import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/payloads/message_contract.dart';
import 'package:wristlink_flutter/features/send_queue/data/send_queue_repository.dart';
import 'package:wristlink_flutter/features/send_queue/data/sqlite_send_queue_repository.dart';
import 'package:wristlink_flutter/features/send_queue/domain/send_queue_record.dart';
import 'package:wristlink_flutter/features/send_queue/presentation/send_queue_controller.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporaryDirectory;
  late String databasePath;
  late SqliteSendQueueRepository repository;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'wristlink-queue-test-',
    );
    databasePath = path.join(temporaryDirectory.path, 'queue.db');
    repository = SqliteSendQueueRepository(
      path: databasePath,
      databaseFactory: databaseFactoryFfi,
    );
    await repository.initialize();
  });

  tearDown(() async {
    await repository.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'round-trips full records and restores them after process reopen',
    () async {
      final now = DateTime.utc(2026, 8, 20, 10);
      final record = _pending('01HX7Y8Z9ABCDEFGHJKMNPQS6X', now).copyWith(
        failure: const SendQueueFailure(
          code: SendQueueFailureCode.targetOffline,
          message: 'Watch is offline.',
          isTransient: true,
        ),
        nextAttemptAt: now.add(const Duration(minutes: 2)),
      );
      await repository.enqueue(record);
      await repository.close();

      repository = SqliteSendQueueRepository(
        path: databasePath,
        databaseFactory: databaseFactoryFfi,
      );
      await repository.initialize();
      final restored = (await repository.readAll()).single;

      expect(restored.toJson(), record.toJson());
      expect(restored.failure?.code, SendQueueFailureCode.targetOffline);
    },
  );

  test('schema version 1 upgrades with durable quarantine storage', () async {
    await repository.close();
    await databaseFactoryFfi.deleteDatabase(databasePath);
    final legacy = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          await database.execute(
            'CREATE TABLE send_queue (message_id TEXT PRIMARY KEY)',
          );
        },
      ),
    );
    await legacy.close();

    repository = SqliteSendQueueRepository(
      path: databasePath,
      databaseFactory: databaseFactoryFfi,
    );
    await repository.initialize();

    final verify = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final tables = await verify.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table' AND name = ?",
      whereArgs: ['send_queue_quarantine'],
    );
    expect(tables, hasLength(1));
    expect(repository.diagnostics, isEmpty);
    await verify.close();
  });

  test('unique ids and guarded transitions are enforced', () async {
    final record = _pending(
      '01HX7Y8Z9ABCDEFGHJKMNPQS6X',
      DateTime.utc(2026, 8, 20),
    );
    await repository.enqueue(record);
    await expectLater(
      repository.enqueue(record),
      throwsA(
        isA<QueueStorageException>().having(
          (error) => error.code,
          'code',
          QueueStorageErrorCode.duplicateMessageId,
        ),
      ),
    );
    await expectLater(
      repository.saveTransition(
        record.copyWith(status: SendQueueStatus.sent),
        expectedStatuses: const {SendQueueStatus.sending},
      ),
      throwsA(
        isA<QueueStorageException>().having(
          (error) => error.code,
          'code',
          QueueStorageErrorCode.invalidTransition,
        ),
      ),
    );
  });

  test('concurrent claims can claim a record only once', () async {
    final now = DateTime.utc(2026, 8, 20, 10);
    await repository.enqueue(_pending('01HX7Y8Z9ABCDEFGHJKMNPQS6X', now));

    final claims = await Future.wait([
      repository.claimNextEligible(now),
      repository.claimNextEligible(now),
    ]);

    expect(claims.whereType<SendQueueRecord>(), hasLength(1));
    expect(claims.whereType<SendQueueRecord>().single.attemptCount, 1);
    expect(
      claims.whereType<SendQueueRecord>().single.status,
      SendQueueStatus.sending,
    );
  });

  test(
    'message-specific claims honor and can bypass retry scheduling',
    () async {
      final now = DateTime.utc(2026, 8, 20, 10);
      final delayed = _pending(
        '01HX7Y8Z9ABCDEFGHJKMNPQS6X',
        now,
      ).copyWith(nextAttemptAt: now.add(const Duration(minutes: 5)));
      await repository.enqueue(delayed);

      expect(await repository.claimPending(delayed.id, now), isNull);
      final claimed = await repository.claimPending(
        delayed.id,
        now,
        ignoreSchedule: true,
      );

      expect(claimed?.status, SendQueueStatus.sending);
      expect(claimed?.attemptCount, 1);
      expect(claimed?.nextAttemptAt, isNull);
    },
  );

  test(
    'sorts by update time and preserves unaffected rows when one is corrupt',
    () async {
      final first = _pending(
        '01HX7Y8Z9ABCDEFGHJKMNPQS6X',
        DateTime.utc(2026, 8, 20, 9),
      );
      final second = _pending(
        '01HX7Y8Z9ABCDEFGHJKMNPQS7X',
        DateTime.utc(2026, 8, 20, 10),
      );
      await repository.enqueue(first);
      await repository.enqueue(second);
      expect((await repository.readAll()).map((record) => record.id), [
        second.id,
        first.id,
      ]);

      final raw = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await raw.update(
        'send_queue',
        {'envelope_json': '{broken'},
        where: 'message_id = ?',
        whereArgs: [first.id],
      );
      await raw.close();
      final records = await repository.readAll();
      expect(records.map((record) => record.id), [second.id]);
      final diagnostic = repository.diagnostics.single;
      expect(diagnostic.id.value, greaterThan(0));
      expect(diagnostic.recordId, first.id);
      expect(diagnostic.message, contains('isolated'));
    },
  );

  test(
    'corrupted rows are quarantined before claims and healthy work remains eligible',
    () async {
      final corrupt = _pending(
        '01HX7Y8Z9ABCDEFGHJKMNPQS6X',
        DateTime.utc(2026, 8, 20, 9),
      );
      final healthy = _pending(
        '01HX7Y8Z9ABCDEFGHJKMNPQS7X',
        DateTime.utc(2026, 8, 20, 10),
      );
      await repository.enqueue(corrupt);
      await repository.enqueue(healthy);
      final raw = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await raw.update(
        'send_queue',
        {'envelope_json': '{broken'},
        where: 'message_id = ?',
        whereArgs: [corrupt.id],
      );
      await raw.close();

      final claimed = await repository.claimNextEligible(
        DateTime.utc(2026, 8, 20, 11),
      );

      expect(claimed?.id, healthy.id);
      expect(claimed?.status, SendQueueStatus.sending);
      expect(await repository.findById(corrupt.id), isNull);
      expect(repository.diagnostics.single.recordId, corrupt.id);
      expect((await repository.readAll()).map((record) => record.id), [
        healthy.id,
      ]);
    },
  );

  test(
    'controller keeps quarantine diagnostics until explicit removal',
    () async {
      final corrupt = _pending(
        '01HX7Y8Z9ABCDEFGHJKMNPQS6X',
        DateTime.utc(2026, 8, 20, 9),
      );
      final healthy = _pending(
        '01HX7Y8Z9ABCDEFGHJKMNPQS7X',
        DateTime.utc(2026, 8, 20, 10),
      );
      await repository.enqueue(corrupt);
      await repository.enqueue(healthy);
      final raw = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await raw.update(
        'send_queue',
        {'envelope_json': '{broken'},
        where: 'message_id = ?',
        whereArgs: [corrupt.id],
      );
      await raw.close();
      await repository.readAll();
      await repository.close();

      repository = SqliteSendQueueRepository(
        path: databasePath,
        databaseFactory: databaseFactoryFfi,
      );
      await repository.initialize();
      expect(repository.diagnostics.single.recordId, corrupt.id);

      final controller = SendQueueController(repository);
      await controller.initialize();
      expect(controller.records.single.id, healthy.id);
      expect(controller.storageDiagnostics.single.recordId, corrupt.id);
      await controller.refresh();
      expect(controller.storageDiagnostics, hasLength(1));

      await controller.removeQuarantinedRows();

      expect(controller.storageDiagnostics, isEmpty);
      expect(controller.records.single.id, healthy.id);
      expect(repository.diagnostics, isEmpty);
      final verify = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      expect(await verify.query('send_queue_quarantine'), isEmpty);
      expect(
        (await verify.query('send_queue')).single['message_id'],
        healthy.id,
      );
      await verify.close();
    },
  );

  test(
    'explicit retry keeps the message id and clears terminal metadata',
    () async {
      final now = DateTime.utc(2026, 8, 20, 10);
      final failed = _pending('01HX7Y8Z9ABCDEFGHJKMNPQS6X', now).copyWith(
        status: SendQueueStatus.failed,
        failure: const SendQueueFailure(
          code: SendQueueFailureCode.deliveryOutcomeUnknown,
          message: 'Delivery outcome is unknown.',
          isTransient: false,
        ),
        acknowledgementDeadline: now,
      );
      await repository.enqueue(
        failed.copyWith(status: SendQueueStatus.pending),
      );
      await repository.saveTransition(
        failed,
        expectedStatuses: const {SendQueueStatus.pending},
      );

      final retried = await repository.retryFailed(
        failed.id,
        now.add(const Duration(minutes: 1)),
      );
      expect(retried.id, failed.id);
      expect(retried.status, SendQueueStatus.pending);
      expect(retried.failure, isNull);
      expect(retried.acknowledgementDeadline, isNull);
    },
  );

  test('a failed schema downgrade leaves the newer database intact', () async {
    await repository.close();
    final newer = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: SqliteSendQueueRepository.schemaVersion + 1,
        onUpgrade: (database, oldVersion, newVersion) async {
          await database.execute(
            'CREATE TABLE migration_sentinel(value TEXT NOT NULL)',
          );
          await database.insert('migration_sentinel', {'value': 'preserved'});
        },
      ),
    );
    await newer.close();

    repository = SqliteSendQueueRepository(
      path: databasePath,
      databaseFactory: databaseFactoryFfi,
    );
    await expectLater(
      repository.initialize(),
      throwsA(isA<QueueStorageException>()),
    );
    final verify = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: SqliteSendQueueRepository.schemaVersion + 1,
      ),
    );
    expect(
      (await verify.query('migration_sentinel')).single['value'],
      'preserved',
    );
    await verify.close();
  });

  test(
    'controller publishes immutable snapshots and surfaces storage errors',
    () async {
      final controller = SendQueueController(repository);
      await controller.initialize();
      await controller.enqueue(
        _pending('01HX7Y8Z9ABCDEFGHJKMNPQS6X', DateTime.utc(2026, 8, 20)),
      );
      expect(controller.records, hasLength(1));
      expect(
        () => controller.records.add(controller.records.single),
        throwsUnsupportedError,
      );
      expect(
        queuePresentationStatus(controller.records.single),
        QueuePresentationStatus.queued,
      );

      final unsupported = SendQueueController(
        const UnsupportedSendQueueRepository(),
      );
      await unsupported.initialize();
      expect(
        unsupported.storageError?.code,
        QueueStorageErrorCode.unsupportedPlatform,
      );
    },
  );
}

SendQueueRecord _pending(String id, DateTime now) {
  return SendQueueRecord.pending(
    message: MessageEnvelope(
      id: id,
      kind: MessageKind.point,
      createdAt: now,
      payload: const PointPayload(
        intent: PointIntent.navigate,
        latitude: 52.5,
        longitude: 13.4,
        label: 'Point',
      ),
    ),
    createdAt: now,
    deviceId: const GarminDeviceId('watch-1'),
  );
}
