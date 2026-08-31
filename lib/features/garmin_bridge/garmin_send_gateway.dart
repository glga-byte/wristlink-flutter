import 'package:flutter/services.dart';

import '../devices/domain/garmin_device.dart';
import '../devices/domain/physical_device_id_codec.dart';
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
  transportTimeout,
  invalidDeviceId,
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
    PhysicalDeviceIdCodec deviceIdCodec = const PhysicalDeviceIdCodec(),
  }) : _channel = channel,
       _deviceIdCodec = deviceIdCodec;

  final MethodChannel _channel;
  final PhysicalDeviceIdCodec _deviceIdCodec;

  @override
  Future<GarminSendResult> sendMessage({
    required GarminDeviceId deviceId,
    required MessageEnvelope message,
  }) async {
    message.validate();
    final String rawDeviceId;
    try {
      rawDeviceId = _deviceIdCodec.toRaw(deviceId);
    } on PhysicalDeviceIdCodecException catch (error) {
      throw GarminSendError(GarminSendErrorCode.invalidDeviceId, error.message);
    }

    try {
      await _channel.invokeMethod<Object?>('sendMessage', <String, Object?>{
        'deviceId': rawDeviceId,
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
    'transportTimeout' => GarminSendErrorCode.transportTimeout,
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
