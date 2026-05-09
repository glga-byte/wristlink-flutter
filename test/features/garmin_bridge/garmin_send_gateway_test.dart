import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_send_gateway.dart';
import 'package:wristlink_flutter/features/payloads/message_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('wristlink/garmin_send_test');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends validated contract maps through the platform channel', () async {
    final message = _message(
      MessageKind.note,
      const NotePayload(body: 'Hello'),
    );
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });

    final gateway = MethodChannelGarminSendGateway(channel: channel);
    final result = await gateway.sendMessage(
      deviceId: const GarminDeviceId('physical:123'),
      message: message,
    );

    expect(result.status, GarminSendStatus.deliveredToTransport);
    expect(result.requiresAcknowledgement, isFalse);
    expect(calls.single.method, 'sendMessage');
    expect(calls.single.arguments, <String, Object?>{
      'deviceId': 'physical:123',
      'message': message.toJson(),
    });
  });

  test('rejects oversized messages before native transport', () async {
    var invoked = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          invoked = true;
          return null;
        });

    final gateway = MethodChannelGarminSendGateway(channel: channel);
    await expectLater(
      gateway.sendMessage(
        deviceId: const GarminDeviceId('physical:123'),
        message: _message(
          MessageKind.note,
          NotePayload(body: 'x' * v1SerializedMessageBudgetBytes),
        ),
      ),
      throwsA(
        isA<ContractError>().having(
          (error) => error.code,
          'code',
          ContractErrorCode.payloadTooLarge,
        ),
      ),
    );
    expect(invoked, isFalse);
  });

  test('rejects malformed outbound messages before native transport', () async {
    var invoked = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          invoked = true;
          return null;
        });

    final gateway = MethodChannelGarminSendGateway(channel: channel);
    await expectLater(
      gateway.sendMessage(
        deviceId: const GarminDeviceId('physical:123'),
        message: MessageEnvelope(
          id: 'not-a-ulid',
          kind: MessageKind.note,
          createdAt: DateTime.utc(2026, 5, 9, 12),
          payload: const NotePayload(body: 'Hello'),
        ),
      ),
      throwsA(
        isA<ContractError>().having(
          (error) => error.code,
          'code',
          ContractErrorCode.malformedPayload,
        ),
      ),
    );
    expect(invoked, isFalse);
  });

  test(
    'maps native too-large failures to payload-too-large contract errors',
    () {
      final mapped = mapGarminSendPlatformException(
        PlatformException(
          code: 'BLE_REQUEST_TOO_LARGE',
          message: 'Too large for BLE request.',
        ),
      );

      expect(mapped, isA<ContractError>());
      expect((mapped as ContractError).code, ContractErrorCode.payloadTooLarge);
    },
  );
}

MessageEnvelope _message(MessageKind kind, ContractPayload payload) {
  return MessageEnvelope(
    id: '01HX7Y8Z9ABCDEFGHJKMNPQS8X',
    kind: kind,
    createdAt: DateTime.utc(2026, 5, 9, 12),
    payload: payload,
  );
}
