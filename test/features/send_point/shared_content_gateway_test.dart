import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/send_point/share/shared_content_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/shared_content');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('drains typed pending records and acknowledges ids', () async {
    MethodCall? acknowledgement;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'drainPending') {
        return <Object?>[
          <String, Object?>{
            'id': 'share-1',
            'receivedAt': '2026-08-20T10:00:00.000Z',
            'platform': 'ios',
            'content': 'geo:1,2',
          },
        ];
      }
      acknowledgement = call;
      return true;
    });
    final gateway = MethodChannelSharedContentGateway(
      methodChannel: channel,
      eventChannel: const EventChannel('test/shared_content_events'),
    );

    final records = await gateway.drainPending();
    expect(records.single.platform, SharedContentPlatform.ios);
    expect(records.single.content, 'geo:1,2');
    await gateway.acknowledge('share-1');
    expect(acknowledgement?.method, 'acknowledge');
    expect(acknowledgement?.arguments, {'id': 'share-1'});
  });

  test(
    'rejects malformed native records and empty acknowledgement ids',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => <Object?>[42]);
      final gateway = MethodChannelSharedContentGateway(
        methodChannel: channel,
        eventChannel: const EventChannel('test/shared_content_events'),
      );
      await expectLater(
        gateway.drainPending(),
        throwsA(isA<FormatException>()),
      );
      expect(() => gateway.acknowledge(''), throwsArgumentError);
    },
  );

  test(
    'fake gateway supports pending, live, and acknowledgement behavior',
    () async {
      final record = SharedContentRecord(
        id: 'share-1',
        receivedAt: DateTime.utc(2026, 8, 20),
        platform: SharedContentPlatform.android,
        content: 'x' * 9000,
      );
      final gateway = FakeSharedContentGateway([record]);
      expect((await gateway.drainPending()).single.content.length, 8192);
      expectLater(gateway.liveRecords, emits(record));
      gateway.emit(record);
      await gateway.acknowledge(record.id);
      expect(gateway.acknowledgedIds, contains(record.id));
      await gateway.dispose();
    },
  );
}
