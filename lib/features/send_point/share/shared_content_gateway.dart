import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/point_parse_result.dart';

enum SharedContentPlatform { android, ios }

class SharedContentRecord {
  SharedContentRecord({
    required this.id,
    required this.receivedAt,
    required this.platform,
    required String content,
  }) : content = boundSharedContent(content);

  factory SharedContentRecord.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final receivedAt = DateTime.tryParse(json['receivedAt'] as String? ?? '');
    final platformName = json['platform'];
    final content = json['content'];
    if (id is! String ||
        id.isEmpty ||
        receivedAt == null ||
        content is! String ||
        content.isEmpty) {
      throw const FormatException('Malformed shared-content record.');
    }
    final platform = SharedContentPlatform.values
        .where((value) => value.name == platformName)
        .firstOrNull;
    if (platform == null) {
      throw const FormatException('Unsupported shared-content platform.');
    }
    return SharedContentRecord(
      id: id,
      receivedAt: receivedAt.toUtc(),
      platform: platform,
      content: content,
    );
  }

  final String id;
  final DateTime receivedAt;
  final SharedContentPlatform platform;
  final String content;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'receivedAt': receivedAt.toUtc().toIso8601String(),
    'platform': platform.name,
    'content': content,
  };
}

abstract interface class SharedContentGateway {
  Future<List<SharedContentRecord>> drainPending();

  Stream<SharedContentRecord> get liveRecords;

  Future<void> acknowledge(String id);
}

class MethodChannelSharedContentGateway implements SharedContentGateway {
  MethodChannelSharedContentGateway({
    MethodChannel methodChannel = const MethodChannel(
      'wristlink/shared_content',
    ),
    EventChannel eventChannel = const EventChannel(
      'wristlink/shared_content_events',
    ),
  }) : _methodChannel = methodChannel,
       _eventChannel = eventChannel;

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  @override
  Future<List<SharedContentRecord>> drainPending() async {
    final raw = await _methodChannel.invokeListMethod<Object?>('drainPending');
    return (raw ?? const <Object?>[])
        .map(_recordFromRaw)
        .toList(growable: false);
  }

  @override
  late final Stream<SharedContentRecord> liveRecords = _eventChannel
      .receiveBroadcastStream()
      .map(_recordFromRaw);

  @override
  Future<void> acknowledge(String id) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Acknowledgement id is required.');
    }
    return _methodChannel.invokeMethod<void>('acknowledge', {'id': id});
  }

  static SharedContentRecord _recordFromRaw(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Shared-content channel value is not a map.');
    }
    return SharedContentRecord.fromJson(raw.cast<String, Object?>());
  }
}

class UnsupportedSharedContentGateway implements SharedContentGateway {
  const UnsupportedSharedContentGateway();

  @override
  Future<void> acknowledge(String id) async {
    throw UnsupportedError('Shared content is unavailable on this platform.');
  }

  @override
  Future<List<SharedContentRecord>> drainPending() async =>
      const <SharedContentRecord>[];

  @override
  Stream<SharedContentRecord> get liveRecords => const Stream.empty();
}

class FakeSharedContentGateway implements SharedContentGateway {
  FakeSharedContentGateway([Iterable<SharedContentRecord> pending = const []])
    : _pending = List.of(pending);

  final List<SharedContentRecord> _pending;
  final StreamController<SharedContentRecord> _live =
      StreamController.broadcast();
  final Set<String> acknowledgedIds = <String>{};

  @override
  Future<void> acknowledge(String id) async {
    acknowledgedIds.add(id);
    _pending.removeWhere((record) => record.id == id);
  }

  @override
  Future<List<SharedContentRecord>> drainPending() async =>
      List.unmodifiable(_pending);

  @override
  Stream<SharedContentRecord> get liveRecords => _live.stream;

  void emit(SharedContentRecord record) => _live.add(record);

  Future<void> dispose() => _live.close();
}
