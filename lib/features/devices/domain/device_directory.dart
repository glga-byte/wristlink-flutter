import 'garmin_device.dart';

enum DeviceDirectoryEmptyReason { noAuthorizedDevices, unsupportedPlatform }

enum SendTargetUnavailableReason {
  noDevices,
  noDefaultDevice,
  defaultDeviceMissing,
  defaultDeviceOffline,
  companionMissing,
  deviceNotReady,
}

sealed class SendTargetResolution {
  const SendTargetResolution();
}

class SendTargetReady extends SendTargetResolution {
  const SendTargetReady(this.device);

  final GarminDevice device;
}

class SendTargetUnavailable extends SendTargetResolution {
  const SendTargetUnavailable(this.reason, {this.device});

  final SendTargetUnavailableReason reason;
  final GarminDevice? device;
}

sealed class DeviceRefreshResult {
  const DeviceRefreshResult();
}

class DeviceRefreshSuccess extends DeviceRefreshResult {
  const DeviceRefreshSuccess(this.devices);

  final List<GarminDevice> devices;
}

class DeviceRefreshFailure extends DeviceRefreshResult {
  const DeviceRefreshFailure(this.error);

  final GarminDiscoveryError error;
}

enum GarminDiscoveryErrorCode {
  sdkUnavailable,
  garminConnectMissing,
  authorizationCancelled,
  noAuthorizedDevices,
  timeout,
  unsupportedPlatform,
  nativeFailure,
  invalidPayload,
}

class GarminDiscoveryError implements Exception {
  const GarminDiscoveryError(this.code, this.message);

  final GarminDiscoveryErrorCode code;
  final String message;

  @override
  String toString() => 'GarminDiscoveryError($code, $message)';
}

abstract interface class DeviceDirectory {
  List<GarminDevice> get devices;

  GarminDeviceId? get defaultDeviceId;

  GarminDiscoveryError? get lastRefreshError;

  Future<DeviceRefreshResult> refreshDevices();

  Future<void> setDefaultDevice(GarminDeviceId id);

  SendTargetResolution resolveSendTarget();
}
