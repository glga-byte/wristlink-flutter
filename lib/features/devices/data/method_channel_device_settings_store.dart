import 'dart:convert';

import 'package:flutter/services.dart';

import '../../developer_tools/domain/emulator_device_settings.dart';
import '../domain/garmin_device.dart';
import 'device_settings_store.dart';
import 'in_memory_device_settings_store.dart';

class MethodChannelDeviceSettingsStore implements DeviceSettingsStore {
  MethodChannelDeviceSettingsStore({
    MethodChannel channel = const MethodChannel('wristlink/device_settings'),
    DeviceSettingsStore? fallbackStore,
  }) : _channel = channel,
       _fallbackStore = fallbackStore ?? InMemoryDeviceSettingsStore();

  static const _defaultDeviceKey = 'defaultDeviceId';
  static const _authorizedDevicesKey = 'authorizedDevices';
  static const _emulatorSettingsKey = 'emulatorSettings';

  final MethodChannel _channel;
  final DeviceSettingsStore _fallbackStore;
  var _useFallback = false;

  @override
  Future<GarminDeviceId?> readDefaultDeviceId() async {
    if (_useFallback) {
      return _fallbackStore.readDefaultDeviceId();
    }

    final value = await _readString(_defaultDeviceKey);
    if (_useFallback) {
      return _fallbackStore.readDefaultDeviceId();
    }
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.trim().isEmpty) {
      return null;
    }
    return GarminDeviceId(value);
  }

  @override
  Future<void> writeDefaultDeviceId(GarminDeviceId id) async {
    if (_useFallback) {
      return _fallbackStore.writeDefaultDeviceId(id);
    }
    if (!await _writeString(_defaultDeviceKey, id.value)) {
      return _fallbackStore.writeDefaultDeviceId(id);
    }
  }

  @override
  Future<List<GarminDevice>> readAuthorizedDevices() async {
    if (_useFallback) {
      return _fallbackStore.readAuthorizedDevices();
    }

    final value = await _readString(_authorizedDevicesKey);
    if (_useFallback) {
      return _fallbackStore.readAuthorizedDevices();
    }
    if (value == null || value.isEmpty) {
      return const <GarminDevice>[];
    }

    final decoded = _tryDecodeJson(value);
    if (decoded is! List<Object?>) {
      return const <GarminDevice>[];
    }
    return decoded
        .whereType<Map>()
        .map((device) => _deviceFromJson(device.cast<String, Object?>()))
        .whereType<GarminDevice>()
        .toList(growable: false);
  }

  @override
  Future<void> replaceAuthorizedDevices(List<GarminDevice> devices) async {
    if (_useFallback) {
      return _fallbackStore.replaceAuthorizedDevices(devices);
    }

    final value = jsonEncode(
      devices.map(_deviceToJson).toList(growable: false),
    );
    if (!await _writeString(_authorizedDevicesKey, value)) {
      return _fallbackStore.replaceAuthorizedDevices(devices);
    }
  }

  @override
  Future<EmulatorDeviceSettings> readEmulatorSettings() async {
    if (_useFallback) {
      return _fallbackStore.readEmulatorSettings();
    }

    final value = await _readString(_emulatorSettingsKey);
    if (_useFallback) {
      return _fallbackStore.readEmulatorSettings();
    }
    if (value == null || value.isEmpty) {
      return const EmulatorDeviceSettings();
    }

    final decoded = _tryDecodeJson(value);
    if (decoded is! Map) {
      return const EmulatorDeviceSettings();
    }
    final settings = decoded.cast<String, Object?>();
    return EmulatorDeviceSettings(
      enabled: settings['enabled'] == true,
      reachability: _enumByName(
        DeviceReachability.values,
        settings['reachability'],
        DeviceReachability.reachable,
      ),
      companionInstallState: _enumByName(
        CompanionInstallState.values,
        settings['companionInstallState'],
        CompanionInstallState.installed,
      ),
    );
  }

  @override
  Future<void> writeEmulatorSettings(EmulatorDeviceSettings settings) async {
    if (_useFallback) {
      return _fallbackStore.writeEmulatorSettings(settings);
    }

    final value = jsonEncode({
      'enabled': settings.enabled,
      'reachability': settings.reachability.name,
      'companionInstallState': settings.companionInstallState.name,
    });
    if (!await _writeString(_emulatorSettingsKey, value)) {
      return _fallbackStore.writeEmulatorSettings(settings);
    }
  }

  Future<String?> _readString(String key) async {
    try {
      return await _channel.invokeMethod<String>('readString', {'key': key});
    } on Object catch (error) {
      if (error is! MissingPluginException && error is! PlatformException) {
        rethrow;
      }
      _useFallback = true;
      return null;
    }
  }

  Future<bool> _writeString(String key, String value) async {
    try {
      await _channel.invokeMethod<void>('writeString', {
        'key': key,
        'value': value,
      });
      return true;
    } on Object catch (error) {
      if (error is! MissingPluginException && error is! PlatformException) {
        rethrow;
      }
      _useFallback = true;
      return false;
    }
  }
}

Map<String, Object?> _deviceToJson(GarminDevice device) {
  return {
    'id': device.id.value,
    'name': device.name,
    'source': device.source.name,
    'reachability': device.reachability.name,
    'companionInstallState': device.companionInstallState.name,
    'isDefault': device.isDefault,
    'metadata': {
      'modelName': device.metadata.modelName,
      'family': device.metadata.family,
      'unitId': device.metadata.unitId,
      'lastSeen': device.metadata.lastSeen?.toIso8601String(),
      'nativePayload': _jsonSafeMap(device.metadata.nativePayload),
    },
  };
}

GarminDevice? _deviceFromJson(Map<String, Object?> json) {
  final id = json['id'] as String?;
  if (id == null || id.trim().isEmpty) {
    return null;
  }

  final metadata = json['metadata'] is Map
      ? (json['metadata'] as Map).cast<String, Object?>()
      : const <String, Object?>{};
  final nativePayload = metadata['nativePayload'] is Map
      ? (metadata['nativePayload'] as Map).cast<String, Object?>()
      : const <String, Object?>{};

  return GarminDevice(
    id: GarminDeviceId(id),
    name: json['name'] as String? ?? 'Garmin device',
    source: _enumByName(
      DeviceSource.values,
      json['source'],
      DeviceSource.physical,
    ),
    reachability: _enumByName(
      DeviceReachability.values,
      json['reachability'],
      DeviceReachability.unknown,
    ),
    companionInstallState: _enumByName(
      CompanionInstallState.values,
      json['companionInstallState'],
      CompanionInstallState.unknown,
    ),
    metadata: GarminDeviceMetadata(
      modelName: metadata['modelName'] as String?,
      family: metadata['family'] as String?,
      unitId: metadata['unitId'] as String?,
      lastSeen: _dateTime(metadata['lastSeen']),
      nativePayload: nativePayload,
    ),
    isDefault: json['isDefault'] == true,
  );
}

Object? _tryDecodeJson(String value) {
  try {
    return jsonDecode(value);
  } on FormatException {
    return null;
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) {
    return fallback;
  }
  return values.where((value) => value.name == name).firstOrNull ?? fallback;
}

DateTime? _dateTime(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

Map<String, Object?> _jsonSafeMap(Map<String, Object?> source) {
  return Map<String, Object?>.fromEntries(
    source.entries.where((entry) => _isJsonSafe(entry.value)),
  );
}

bool _isJsonSafe(Object? value) {
  return value == null || value is String || value is num || value is bool;
}
