import 'package:flutter/services.dart';

import '../devices/domain/garmin_device.dart';
import '../payloads/message_contract.dart';

abstract interface class GarminSendGateway {
  Future<GarminSendResult> sendMessage({
    required GarminDeviceId deviceId,
    required MessageEnvelope message,
  });
}

enum GarminSendStatus { deliveredToTransport }

class GarminSendResult {
  const GarminSendResult({
    required this.status,
    required this.requiresAcknowledgement,
  });

  final GarminSendStatus status;
  final bool requiresAcknowledgement;
}

enum GarminSendErrorCode {
  sdkUnavailable,
  deviceUnavailable,
  appNotInstalled,
  payloadTooLarge,
  unsupportedPlatform,
  nativeFailure,
}

class GarminSendError implements Exception {
  const GarminSendError(this.code, this.message);

  final GarminSendErrorCode code;
  final String message;

  @override
  String toString() => 'GarminSendError($code, $message)';
}

class MethodChannelGarminSendGateway implements GarminSendGateway {
  MethodChannelGarminSendGateway({
    MethodChannel channel = const MethodChannel('wristlink/garmin_send'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<GarminSendResult> sendMessage({
    required GarminDeviceId deviceId,
    required MessageEnvelope message,
  }) async {
    message.validateSize();

    try {
      await _channel.invokeMethod<Object?>('sendMessage', <String, Object?>{
        'deviceId': deviceId.value,
        'message': message.toJson(),
      });
      return GarminSendResult(
        status: GarminSendStatus.deliveredToTransport,
        requiresAcknowledgement: message.kind.requiresAcknowledgement,
      );
    } on PlatformException catch (error) {
      throw mapGarminSendPlatformException(error);
    }
  }
}

class UnsupportedGarminSendGateway implements GarminSendGateway {
  const UnsupportedGarminSendGateway();

  @override
  Future<GarminSendResult> sendMessage({
    required GarminDeviceId deviceId,
    required MessageEnvelope message,
  }) async {
    throw const GarminSendError(
      GarminSendErrorCode.unsupportedPlatform,
      'Garmin message sending is not available on this platform.',
    );
  }
}

Object mapGarminSendPlatformException(PlatformException error) {
  if (_isTooLarge(error.code)) {
    return ContractError(
      ContractErrorCode.payloadTooLarge,
      error.message ?? 'Serialized Garmin app-message payload is too large.',
    );
  }

  final code = switch (error.code) {
    'sdkUnavailable' => GarminSendErrorCode.sdkUnavailable,
    'deviceUnavailable' => GarminSendErrorCode.deviceUnavailable,
    'appNotInstalled' => GarminSendErrorCode.appNotInstalled,
    'unsupportedPlatform' => GarminSendErrorCode.unsupportedPlatform,
    _ => GarminSendErrorCode.nativeFailure,
  };

  return GarminSendError(code, error.message ?? 'Garmin send failed.');
}

bool _isTooLarge(String code) {
  return code == 'payloadTooLarge' ||
      code == 'BLE_REQUEST_TOO_LARGE' ||
      code == 'bleRequestTooLarge';
}
