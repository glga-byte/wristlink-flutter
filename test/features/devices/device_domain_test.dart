import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/devices/domain/device_directory.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/devices/presentation/device_presentation_models.dart';
import 'package:wristlink_flutter/features/devices/test_fixtures/device_fixtures.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_device_discovery_gateway.dart';

void main() {
  test('derives ready, setup, unavailable, and testing readiness', () {
    expect(
      deriveDeviceReadiness(
        reachability: DeviceReachability.reachable,
        companionInstallState: CompanionInstallState.installed,
      ),
      DeviceReadiness.ready,
    );
    expect(
      deriveDeviceReadiness(
        reachability: DeviceReachability.nearby,
        companionInstallState: CompanionInstallState.missing,
      ),
      DeviceReadiness.needsSetup,
    );
    expect(
      deriveDeviceReadiness(
        reachability: DeviceReachability.offline,
        companionInstallState: CompanionInstallState.installed,
      ),
      DeviceReadiness.unavailable,
    );
    expect(
      deriveDeviceReadiness(
        reachability: DeviceReachability.failed,
        companionInstallState: CompanionInstallState.installed,
      ),
      DeviceReadiness.testing,
    );
  });

  test('maps native discovery payload into typed device models', () {
    final devices = mapNativeDeviceList([
      {
        'id': '123',
        'name': 'Forerunner 965',
        'reachability': 'connected',
        'companionInstallState': 'installed',
        'modelName': 'Forerunner 965',
      },
    ]);

    expect(devices.single.id, const GarminDeviceId('physical:123'));
    expect(devices.single.source, DeviceSource.physical);
    expect(devices.single.reachability, DeviceReachability.reachable);
    expect(
      devices.single.companionInstallState,
      CompanionInstallState.installed,
    );
  });

  test('maps discovery errors to user-presentable devices state', () {
    final presentation = mapDevicesPresentation(
      devices: const [],
      refreshError: const GarminDiscoveryError(
        GarminDiscoveryErrorCode.garminConnectMissing,
        'missing',
      ),
    );

    expect(presentation.emptyTitle, 'No Garmin devices');
    expect(presentation.errorMessage, 'Garmin Connect is not installed.');
  });

  test('maps share readiness from send-target resolution', () {
    final ready = mapShareConfirmReadiness(
      const SendTargetReady(fixtureReadyDevice),
    );
    final missingCompanion = mapShareConfirmReadiness(
      const SendTargetUnavailable(
        SendTargetUnavailableReason.companionMissing,
        device: fixtureSetupDevice,
      ),
    );

    expect(ready.canSend, isTrue);
    expect(ready.foundWatchLabel, 'Forerunner 965 found');
    expect(missingCompanion.canSend, isFalse);
    expect(missingCompanion.companionInstalledLabel, 'Companion app missing');
  });
}
