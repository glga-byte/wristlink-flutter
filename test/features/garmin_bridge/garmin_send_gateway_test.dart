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
      'deviceId': '123',
      'message': message.toJson(),
    });
  });

  test('rejects invalid device ids before native transport', () async {
    var invocationCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          invocationCount += 1;
          return null;
        });

    final gateway = MethodChannelGarminSendGateway(channel: channel);
    for (final deviceId in <String>[
      '',
      'physical:',
      'physical:watch 123',
      'physical:physical:123',
      'emulator:123',
    ]) {
      await expectLater(
        gateway.sendMessage(
          deviceId: GarminDeviceId(deviceId),
          message: _message(MessageKind.note, const NotePayload(body: 'Hello')),
        ),
        throwsA(
          isA<GarminSendError>().having(
            (error) => error.code,
            'code',
            GarminSendErrorCode.invalidDeviceId,
          ),
        ),
        reason: deviceId,
      );
    }

    expect(invocationCount, 0);
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

  test('maps every native transport failure to a typed Dart error', () {
    final expectedCodes = <String, GarminSendErrorCode>{
      'sdkUnavailable': GarminSendErrorCode.sdkUnavailable,
      'deviceUnavailable': GarminSendErrorCode.deviceUnavailable,
      'appNotInstalled': GarminSendErrorCode.appNotInstalled,
      'transportTimeout': GarminSendErrorCode.transportTimeout,
      'unsupportedPlatform': GarminSendErrorCode.unsupportedPlatform,
      'nativeFailure': GarminSendErrorCode.nativeFailure,
      'unexpectedNativeCode': GarminSendErrorCode.nativeFailure,
    };

    for (final entry in expectedCodes.entries) {
      final mapped = mapGarminSendPlatformException(
        PlatformException(code: entry.key, message: 'native detail'),
      );

      expect(mapped, isA<GarminSendError>());
      final sendError = mapped as GarminSendError;
      expect(sendError.code, entry.value, reason: entry.key);
      expect(sendError.message, 'native detail');
    }
  });

  test('maps every native too-large spelling to the contract budget error', () {
    for (final code in <String>[
      'payloadTooLarge',
      'BLE_REQUEST_TOO_LARGE',
      'bleRequestTooLarge',
    ]) {
      final mapped = mapGarminSendPlatformException(
        PlatformException(code: code),
      );

      expect(mapped, isA<ContractError>(), reason: code);
      expect(
        (mapped as ContractError).code,
        ContractErrorCode.payloadTooLarge,
        reason: code,
      );
    }
  });

  test(
    'surfaces platform failure and completes the send future once',
    () async {
      var invocationCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            invocationCount += 1;
            throw PlatformException(
              code: 'deviceUnavailable',
              message: 'Watch disconnected.',
            );
          });

      final gateway = MethodChannelGarminSendGateway(channel: channel);
      await expectLater(
        gateway.sendMessage(
          deviceId: const GarminDeviceId('physical:123'),
          message: _message(
            MessageKind.point,
            const PointPayload(
              intent: PointIntent.navigate,
              latitude: 52.52,
              longitude: 13.405,
            ),
          ),
        ),
        throwsA(
          isA<GarminSendError>()
              .having(
                (error) => error.code,
                'code',
                GarminSendErrorCode.deviceUnavailable,
              )
              .having(
                (error) => error.message,
                'message',
                'Watch disconnected.',
              ),
        ),
      );
      expect(invocationCount, 1);
    },
  );

  test('unsupported gateway returns its typed failure', () async {
    await expectLater(
      const UnsupportedGarminSendGateway().sendMessage(
        deviceId: const GarminDeviceId('physical:123'),
        message: _message(MessageKind.note, const NotePayload(body: 'Hello')),
      ),
      throwsA(
        isA<GarminSendError>().having(
          (error) => error.code,
          'code',
          GarminSendErrorCode.unsupportedPlatform,
        ),
      ),
    );
  });
}

MessageEnvelope _message(MessageKind kind, ContractPayload payload) {
  return MessageEnvelope(
    id: '01HX7Y8Z9ABCDEFGHJKMNPQS8X',
    kind: kind,
    createdAt: DateTime.utc(2026, 5, 9, 12),
    payload: payload,
  );
}
