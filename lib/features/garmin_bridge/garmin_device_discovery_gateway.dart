import 'package:flutter/services.dart';

import '../devices/domain/device_directory.dart';
import '../devices/domain/garmin_device.dart';

abstract interface class GarminDeviceDiscoveryGateway {
  Future<List<GarminDevice>> discoverDevices();
}

class MethodChannelGarminDeviceDiscoveryGateway
    implements GarminDeviceDiscoveryGateway {
  MethodChannelGarminDeviceDiscoveryGateway({
    MethodChannel channel = const MethodChannel('wristlink/garmin_devices'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<List<GarminDevice>> discoverDevices() async {
    try {
      final payload = await _channel.invokeListMethod<Object?>(
        'discoverDevices',
      );
      return mapNativeDeviceList(payload ?? const <Object?>[]);
    } on PlatformException catch (error) {
      throw mapPlatformException(error);
    } on TypeError catch (error) {
      throw GarminDiscoveryError(
        GarminDiscoveryErrorCode.invalidPayload,
        'Invalid Garmin device payload: $error',
      );
    }
  }
}

class UnsupportedGarminDeviceDiscoveryGateway
    implements GarminDeviceDiscoveryGateway {
  const UnsupportedGarminDeviceDiscoveryGateway();

  @override
  Future<List<GarminDevice>> discoverDevices() async {
    throw const GarminDiscoveryError(
      GarminDiscoveryErrorCode.unsupportedPlatform,
      'Garmin device discovery is not available on this platform.',
    );
  }
}

List<GarminDevice> mapNativeDeviceList(List<Object?> payload) {
  return payload
      .whereType<Map<Object?, Object?>>()
      .map(mapNativeDevice)
      .toList(growable: false);
}

GarminDevice mapNativeDevice(Map<Object?, Object?> payload) {
  final id = _string(payload['id']) ?? _string(payload['unitId']);
  final name = _string(payload['name']);
  if (id == null || name == null) {
    throw const GarminDiscoveryError(
      GarminDiscoveryErrorCode.invalidPayload,
      'Garmin device payload must include id and name.',
    );
  }

  return GarminDevice(
    id: GarminDeviceId('physical:$id'),
    name: name,
    source: DeviceSource.physical,
    reachability: _reachability(payload['reachability']),
    companionInstallState: _companion(payload['companionInstallState']),
    metadata: GarminDeviceMetadata(
      modelName: _string(payload['modelName']),
      family: _string(payload['family']),
      unitId: _string(payload['unitId']),
      lastSeen: _dateTime(payload['lastSeen']),
      nativePayload: Map<String, Object?>.fromEntries(
        payload.entries.map((entry) {
          return MapEntry(entry.key.toString(), entry.value);
        }),
      ),
    ),
  );
}

GarminDiscoveryError mapPlatformException(PlatformException error) {
  final code = switch (error.code) {
    'sdkUnavailable' => GarminDiscoveryErrorCode.sdkUnavailable,
    'garminConnectMissing' => GarminDiscoveryErrorCode.garminConnectMissing,
    'authorizationCancelled' => GarminDiscoveryErrorCode.authorizationCancelled,
    'noAuthorizedDevices' => GarminDiscoveryErrorCode.noAuthorizedDevices,
    'timeout' => GarminDiscoveryErrorCode.timeout,
    'unsupportedPlatform' => GarminDiscoveryErrorCode.unsupportedPlatform,
    _ => GarminDiscoveryErrorCode.nativeFailure,
  };
  return GarminDiscoveryError(
    code,
    error.message ?? 'Garmin discovery failed.',
  );
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

DateTime? _dateTime(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

DeviceReachability _reachability(Object? value) {
  return switch (value) {
    'reachable' || 'connected' || 'available' => DeviceReachability.reachable,
    'nearby' => DeviceReachability.nearby,
    'offline' || 'unavailable' => DeviceReachability.offline,
    'sending' => DeviceReachability.sending,
    'failed' => DeviceReachability.failed,
    _ => DeviceReachability.unknown,
  };
}

CompanionInstallState _companion(Object? value) {
  return switch (value) {
    'installed' || true => CompanionInstallState.installed,
    'missing' || false => CompanionInstallState.missing,
    _ => CompanionInstallState.unknown,
  };
}
