import 'package:flutter/services.dart';
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
        'family': '006-B1234-00',
      },
    ]);

    expect(devices.single.id, const GarminDeviceId('physical:123'));
    expect(devices.single.metadata.modelName, 'Forerunner 965');
    expect(devices.single.metadata.family, '006-B1234-00');
    expect(devices.single.reachability, DeviceReachability.reachable);
    expect(
      devices.single.companionInstallState,
      CompanionInstallState.installed,
    );
  });

  test('maps Garmin disconnected enum strings before connected substring', () {
    final devices = mapNativeDeviceList([
      {
        'id': 'off',
        'name': 'Powered off watch',
        'reachability': 'NOT_CONNECTED',
        'companionInstallState': 'installed',
      },
      {
        'id': 'paired',
        'name': 'Unpaired watch',
        'reachability': 'not_paired',
        'companionInstallState': 'installed',
      },
      {
        'id': 'on',
        'name': 'Connected watch',
        'reachability': 'CONNECTED',
        'companionInstallState': 'installed',
      },
    ]);

    expect(devices[0].reachability, DeviceReachability.offline);
    expect(devices[1].reachability, DeviceReachability.offline);
    expect(devices[2].reachability, DeviceReachability.reachable);
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

  test('maps all known platform discovery error codes', () {
    final expectedCodes = {
      'sdkUnavailable': GarminDiscoveryErrorCode.sdkUnavailable,
      'garminConnectMissing': GarminDiscoveryErrorCode.garminConnectMissing,
      'authorizationCancelled': GarminDiscoveryErrorCode.authorizationCancelled,
      'noAuthorizedDevices': GarminDiscoveryErrorCode.noAuthorizedDevices,
      'timeout': GarminDiscoveryErrorCode.timeout,
      'unsupportedPlatform': GarminDiscoveryErrorCode.unsupportedPlatform,
      'other': GarminDiscoveryErrorCode.nativeFailure,
    };

    for (final entry in expectedCodes.entries) {
      final error = mapPlatformException(
        PlatformException(code: entry.key, message: 'failure'),
      );
      expect(error.code, entry.value);
      expect(error.message, 'failure');
    }
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

  test('derives presentation colors outside device domain models', () {
    final readyRow = mapDeviceRow(fixtureReadyDevice);
    final setupRow = mapDeviceRow(fixtureSetupDevice);

    expect(readyRow.accentColor, const Color(0xFF111111));
    expect(setupRow.accentColor, const Color(0xFFD8444A));
  });
}
