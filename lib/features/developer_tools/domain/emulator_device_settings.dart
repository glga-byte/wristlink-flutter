import '../../devices/domain/garmin_device.dart';

class EmulatorDeviceSettings {
  const EmulatorDeviceSettings({
    this.enabled = false,
    this.reachability = DeviceReachability.reachable,
    this.companionInstallState = CompanionInstallState.installed,
  });

  final bool enabled;
  final DeviceReachability reachability;
  final CompanionInstallState companionInstallState;

  EmulatorDeviceSettings copyWith({
    bool? enabled,
    DeviceReachability? reachability,
    CompanionInstallState? companionInstallState,
  }) {
    return EmulatorDeviceSettings(
      enabled: enabled ?? this.enabled,
      reachability: reachability ?? this.reachability,
      companionInstallState:
          companionInstallState ?? this.companionInstallState,
    );
  }
}
