import 'package:flutter/services.dart';

import '../devices/domain/device_directory.dart';
import '../devices/domain/garmin_device.dart';
import '../devices/domain/physical_device_id_codec.dart';

const _physicalDeviceIdCodec = PhysicalDeviceIdCodec();

abstract interface class GarminDeviceDiscoveryGateway {
  Future<List<GarminDevice>> discoverDevices();

  Future<List<GarminDevice>> hydrateTransport(
    List<GarminDevice> authorizedDevices,
  );

  Stream<GarminDevice> get deviceUpdates;
}

class MethodChannelGarminDeviceDiscoveryGateway
    implements GarminDeviceDiscoveryGateway {
  MethodChannelGarminDeviceDiscoveryGateway({
    MethodChannel channel = const MethodChannel('wristlink/garmin_devices'),
    EventChannel eventChannel = const EventChannel(
      'wristlink/garmin_device_events',
    ),
    Duration timeout = const Duration(seconds: 35),
  }) : _channel = channel,
       _eventChannel = eventChannel,
       _timeout = timeout;

  final MethodChannel _channel;
  final EventChannel _eventChannel;
  final Duration _timeout;
  Future<List<GarminDevice>>? _inFlightHydration;

  @override
  Stream<GarminDevice> get deviceUpdates {
    return _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .cast<Map>()
        .map((event) => mapNativeDevice(event.cast<Object?, Object?>()));
  }

  @override
  Future<List<GarminDevice>> discoverDevices() async {
    try {
      final payload = await _channel
          .invokeListMethod<Object?>('discoverDevices')
          .timeout(
            _timeout,
            onTimeout: () {
              throw const GarminDiscoveryError(
                GarminDiscoveryErrorCode.timeout,
                'Garmin device discovery timed out.',
              );
            },
          );
      return mapNativeDeviceList(payload ?? const <Object?>[]);
    } on GarminDiscoveryError {
      rethrow;
    } on PlatformException catch (error) {
      throw mapPlatformException(error);
    } on TypeError catch (error) {
      throw GarminDiscoveryError(
        GarminDiscoveryErrorCode.invalidPayload,
        'Invalid Garmin device payload: $error',
      );
    }
  }

  @override
  Future<List<GarminDevice>> hydrateTransport(
    List<GarminDevice> authorizedDevices,
  ) {
    return _inFlightHydration ??= _hydrateAndClear(authorizedDevices);
  }

  Future<List<GarminDevice>> _hydrateAndClear(
    List<GarminDevice> authorizedDevices,
  ) async {
    try {
      return await _hydrateTransport(authorizedDevices);
    } finally {
      _inFlightHydration = null;
    }
  }

  Future<List<GarminDevice>> _hydrateTransport(
    List<GarminDevice> authorizedDevices,
  ) async {
    try {
      final payload = await _channel
          .invokeListMethod<Object?>('hydrateTransport', {
            'devices': authorizedDevices
                .map(mapGarminTransportHydrationDevice)
                .toList(growable: false),
          })
          .timeout(
            _timeout,
            onTimeout: () {
              throw const GarminDiscoveryError(
                GarminDiscoveryErrorCode.timeout,
                'Garmin transport hydration timed out.',
              );
            },
          );
      return mapNativeDeviceList(payload ?? const <Object?>[]);
    } on GarminDiscoveryError {
      rethrow;
    } on MissingPluginException {
      throw const GarminDiscoveryError(
        GarminDiscoveryErrorCode.sdkUnavailable,
        'Garmin transport hydration is not available.',
      );
    } on PlatformException catch (error) {
      throw mapPlatformException(error);
    } on PhysicalDeviceIdCodecException catch (error) {
      throw GarminDiscoveryError(
        GarminDiscoveryErrorCode.invalidPayload,
        'Invalid Garmin transport hydration device: ${error.message}',
      );
    } on TypeError catch (error) {
      throw GarminDiscoveryError(
        GarminDiscoveryErrorCode.invalidPayload,
        'Invalid Garmin transport hydration payload: $error',
      );
    }
  }
}

class UnsupportedGarminDeviceDiscoveryGateway
    implements GarminDeviceDiscoveryGateway {
  const UnsupportedGarminDeviceDiscoveryGateway();

  @override
  Stream<GarminDevice> get deviceUpdates => const Stream<GarminDevice>.empty();

  @override
  Future<List<GarminDevice>> discoverDevices() async {
    throw const GarminDiscoveryError(
      GarminDiscoveryErrorCode.unsupportedPlatform,
      'Garmin device discovery is not available on this platform.',
    );
  }

  @override
  Future<List<GarminDevice>> hydrateTransport(
    List<GarminDevice> authorizedDevices,
  ) async {
    throw const GarminDiscoveryError(
      GarminDiscoveryErrorCode.unsupportedPlatform,
      'Garmin transport hydration is not available on this platform.',
    );
  }
}

Map<String, Object?> mapGarminTransportHydrationDevice(GarminDevice device) {
  return <String, Object?>{
    'id': _physicalDeviceIdCodec.toRaw(device.id),
    'name': device.name,
    'modelName': device.metadata.modelName,
    'partNumber': device.metadata.family,
    'unitId': device.metadata.unitId,
  };
}

List<GarminDevice> mapNativeDeviceList(List<Object?> payload) {
  return payload
      .whereType<Map>()
      .map((device) => mapNativeDevice(device.cast<Object?, Object?>()))
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
    id: _mapNativeDeviceId(id),
    name: name,
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

GarminDeviceId _mapNativeDeviceId(String id) {
  try {
    return _physicalDeviceIdCodec.fromRaw(id);
  } on PhysicalDeviceIdCodecException catch (error) {
    throw GarminDiscoveryError(
      GarminDiscoveryErrorCode.invalidPayload,
      'Invalid Garmin device id: ${error.message}',
    );
  }
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
  final normalized = value is String ? value.toLowerCase() : '';
  return switch (normalized) {
    'not_connected' ||
    'not_paired' ||
    'offline' ||
    'unavailable' => DeviceReachability.offline,
    'reachable' || 'connected' || 'available' => DeviceReachability.reachable,
    'nearby' => DeviceReachability.nearby,
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
