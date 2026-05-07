import 'dart:convert';

import '../../developer_tools/domain/emulator_device_settings.dart';
import '../domain/garmin_device.dart';
import 'device_settings_store.dart';

abstract class StringDeviceSettingsStore implements DeviceSettingsStore {
  const StringDeviceSettingsStore();

  static const defaultDeviceKey = 'defaultDeviceId';
  static const authorizedDevicesKey = 'authorizedDevices';
  static const emulatorSettingsKey = 'emulatorSettings';

  Future<String?> readString(String key);

  Future<void> writeString(String key, String value);

  @override
  Future<GarminDeviceId?> readDefaultDeviceId() async {
    final value = await readString(defaultDeviceKey);
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
    await writeString(defaultDeviceKey, id.value);
  }

  @override
  Future<List<GarminDevice>> readAuthorizedDevices() async {
    final value = await readString(authorizedDevicesKey);
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
    final value = jsonEncode(
      devices.map(_deviceToJson).toList(growable: false),
    );
    await writeString(authorizedDevicesKey, value);
  }

  @override
  Future<EmulatorDeviceSettings> readEmulatorSettings() async {
    final value = await readString(emulatorSettingsKey);
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
    final value = jsonEncode({
      'enabled': settings.enabled,
      'reachability': settings.reachability.name,
      'companionInstallState': settings.companionInstallState.name,
    });
    await writeString(emulatorSettingsKey, value);
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
