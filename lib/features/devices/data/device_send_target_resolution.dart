import '../domain/device_directory.dart';
import '../domain/garmin_device.dart';

SendTargetResolution resolveDeviceSendTarget({
  required List<GarminDevice> devices,
  required GarminDeviceId? defaultDeviceId,
}) {
  if (devices.isEmpty) {
    return const SendTargetUnavailable(SendTargetUnavailableReason.noDevices);
  }

  if (defaultDeviceId == null) {
    return const SendTargetUnavailable(
      SendTargetUnavailableReason.noDefaultDevice,
    );
  }

  final defaultDevice = devices.where((device) => device.id == defaultDeviceId);
  if (defaultDevice.isEmpty) {
    return const SendTargetUnavailable(
      SendTargetUnavailableReason.defaultDeviceMissing,
    );
  }

  final device = defaultDevice.first;
  if (device.isReady) {
    return SendTargetReady(device);
  }

  if (device.companionInstallState == CompanionInstallState.missing) {
    return SendTargetUnavailable(
      SendTargetUnavailableReason.companionMissing,
      device: device,
    );
  }

  if (device.reachability == DeviceReachability.offline ||
      device.reachability == DeviceReachability.unknown) {
    return SendTargetUnavailable(
      SendTargetUnavailableReason.defaultDeviceOffline,
      device: device,
    );
  }

  return SendTargetUnavailable(
    SendTargetUnavailableReason.deviceNotReady,
    device: device,
  );
}
