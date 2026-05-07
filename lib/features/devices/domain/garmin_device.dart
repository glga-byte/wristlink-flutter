enum DeviceReachability { reachable, nearby, offline, sending, failed, unknown }

enum CompanionInstallState { installed, missing, unknown }

enum DeviceReadiness { ready, needsSetup, unavailable, testing }

class GarminDeviceId {
  const GarminDeviceId(this.value);

  final String value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) {
    return other is GarminDeviceId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

class GarminDeviceMetadata {
  const GarminDeviceMetadata({
    this.modelName,
    this.family,
    this.unitId,
    this.lastSeen,
    this.nativePayload = const <String, Object?>{},
  });

  final String? modelName;
  final String? family;
  final String? unitId;
  final DateTime? lastSeen;
  final Map<String, Object?> nativePayload;

  GarminDeviceMetadata copyWith({
    String? modelName,
    String? family,
    String? unitId,
    DateTime? lastSeen,
    Map<String, Object?>? nativePayload,
  }) {
    return GarminDeviceMetadata(
      modelName: modelName ?? this.modelName,
      family: family ?? this.family,
      unitId: unitId ?? this.unitId,
      lastSeen: lastSeen ?? this.lastSeen,
      nativePayload: nativePayload ?? this.nativePayload,
    );
  }
}

class GarminDevice {
  const GarminDevice({
    required this.id,
    required this.name,
    required this.reachability,
    required this.companionInstallState,
    this.metadata = const GarminDeviceMetadata(),
    this.isDefault = false,
  });

  final GarminDeviceId id;
  final String name;
  final DeviceReachability reachability;
  final CompanionInstallState companionInstallState;
  final GarminDeviceMetadata metadata;
  final bool isDefault;

  DeviceReadiness get readiness {
    return deriveDeviceReadiness(
      reachability: reachability,
      companionInstallState: companionInstallState,
    );
  }

  bool get isReady => readiness == DeviceReadiness.ready;

  GarminDevice copyWith({
    GarminDeviceId? id,
    String? name,
    DeviceReachability? reachability,
    CompanionInstallState? companionInstallState,
    GarminDeviceMetadata? metadata,
    bool? isDefault,
  }) {
    return GarminDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      reachability: reachability ?? this.reachability,
      companionInstallState:
          companionInstallState ?? this.companionInstallState,
      metadata: metadata ?? this.metadata,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

DeviceReadiness deriveDeviceReadiness({
  required DeviceReachability reachability,
  required CompanionInstallState companionInstallState,
}) {
  if (reachability == DeviceReachability.sending ||
      reachability == DeviceReachability.failed) {
    return DeviceReadiness.testing;
  }

  if (reachability == DeviceReachability.offline ||
      reachability == DeviceReachability.unknown) {
    return DeviceReadiness.unavailable;
  }

  if (companionInstallState == CompanionInstallState.installed &&
      reachability == DeviceReachability.reachable) {
    return DeviceReadiness.ready;
  }

  if (companionInstallState == CompanionInstallState.missing &&
      (reachability == DeviceReachability.reachable ||
          reachability == DeviceReachability.nearby)) {
    return DeviceReadiness.needsSetup;
  }

  return DeviceReadiness.unavailable;
}
