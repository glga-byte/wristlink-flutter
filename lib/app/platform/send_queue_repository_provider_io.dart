import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../features/send_queue/data/send_queue_repository.dart';
import '../../features/send_queue/data/sqlite_send_queue_repository.dart';

Future<SendQueueRepository> createSendQueueRepository() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return const UnsupportedSendQueueRepository();
  }
  final databaseDirectory = await getDatabasesPath();
  return SqliteSendQueueRepository(
    path: path.join(
      databaseDirectory,
      SqliteSendQueueRepository.defaultDatabaseName,
    ),
  );
}
