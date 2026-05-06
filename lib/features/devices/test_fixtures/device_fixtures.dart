import '../domain/garmin_device.dart';

const fixtureReadyDevice = GarminDevice(
  id: GarminDeviceId('physical:fixture-ready'),
  name: 'Forerunner 965',
  source: DeviceSource.physical,
  reachability: DeviceReachability.reachable,
  companionInstallState: CompanionInstallState.installed,
  isDefault: true,
);

const fixtureSetupDevice = GarminDevice(
  id: GarminDeviceId('physical:fixture-setup'),
  name: 'Fenix 7',
  source: DeviceSource.physical,
  reachability: DeviceReachability.nearby,
  companionInstallState: CompanionInstallState.missing,
);

const fixtureOfflineDevice = GarminDevice(
  id: GarminDeviceId('physical:fixture-offline'),
  name: 'Venu 3',
  source: DeviceSource.physical,
  reachability: DeviceReachability.offline,
  companionInstallState: CompanionInstallState.unknown,
);
