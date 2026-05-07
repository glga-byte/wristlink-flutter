import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/developer_tools/presentation/developer_tools_screen.dart';
import 'package:wristlink_flutter/features/devices/data/in_memory_device_settings_store.dart';
import 'package:wristlink_flutter/features/devices/data/local_device_directory.dart';
import 'package:wristlink_flutter/features/devices/domain/device_directory.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/devices/presentation/devices_screen.dart';
import 'package:wristlink_flutter/features/devices/test_fixtures/device_fixtures.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_device_discovery_gateway.dart';
import 'package:wristlink_flutter/features/home/home_screen.dart';

void main() {
  testWidgets('Devices tab renders ready, setup, offline, and empty states', (
    tester,
  ) async {
    final directory = LocalDeviceDirectory(
      store: InMemoryDeviceSettingsStore(
        defaultDeviceId: fixtureReadyDevice.id,
        authorizedDevices: const [
          fixtureReadyDevice,
          fixtureSetupDevice,
          fixtureOfflineDevice,
        ],
      ),
    );
    await directory.load();

    await tester.pumpWidget(_App(child: DevicesScreen(directory: directory)));

    expect(find.text('Forerunner 965'), findsOneWidget);
    expect(find.text('connected'), findsOneWidget);
    expect(find.text('setup'), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
    expect(find.text('BEFORE SENDING'), findsOneWidget);

    final emptyDirectory = LocalDeviceDirectory(
      store: InMemoryDeviceSettingsStore(authorizedDevices: const []),
    );
    await emptyDirectory.load();
    await tester.pumpWidget(
      _App(child: DevicesScreen(directory: emptyDirectory)),
    );

    expect(find.text('No Garmin devices'), findsOneWidget);
  });

  testWidgets('Devices tab renders refresh errors', (tester) async {
    final errorDirectory = LocalDeviceDirectory(
      store: InMemoryDeviceSettingsStore(authorizedDevices: const []),
      discoveryGateway: const _ErrorGateway(),
    );
    await errorDirectory.load();

    await tester.pumpWidget(
      _App(child: DevicesScreen(directory: errorDirectory)),
    );
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Garmin Connect is not installed.'), findsOneWidget);
  });

  testWidgets('Default Watch screen updates shared default selection', (
    tester,
  ) async {
    final directory = LocalDeviceDirectory(
      store: InMemoryDeviceSettingsStore(
        defaultDeviceId: fixtureReadyDevice.id,
        authorizedDevices: const [fixtureReadyDevice, fixtureSetupDevice],
      ),
    );
    await directory.load();

    await tester.pumpWidget(
      _App(child: DefaultWatchScreen(directory: directory)),
    );
    await tester.tap(find.text('Fenix 7'));
    await tester.pumpAndSettle();

    expect(directory.defaultDeviceId, fixtureSetupDevice.id);
  });

  testWidgets('Developer Tools controls are inert', (tester) async {
    final directory = LocalDeviceDirectory(
      store: InMemoryDeviceSettingsStore(
        defaultDeviceId: fixtureReadyDevice.id,
        authorizedDevices: const [fixtureReadyDevice],
      ),
    );
    await directory.load();
    final initialDevices = directory.devices;

    await tester.pumpWidget(const _App(child: DeveloperToolsScreen()));

    await tester.tap(find.text('Offline'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Missing'));
    await tester.pumpAndSettle();

    expect(find.text('Emulator logic is not implemented.'), findsOneWidget);
    expect(directory.devices, initialDevices);
    expect(directory.defaultDeviceId, fixtureReadyDevice.id);
    expect(directory.resolveSendTarget(), isA<SendTargetReady>());
  });

  testWidgets('Send screen consumes shared send-target resolution', (
    tester,
  ) async {
    final directory = LocalDeviceDirectory(
      store: InMemoryDeviceSettingsStore(
        defaultDeviceId: fixtureReadyDevice.id,
        authorizedDevices: const [fixtureReadyDevice],
      ),
    );
    await directory.load();

    await tester.pumpWidget(
      _App(child: SendScreen(deviceDirectory: directory)),
    );

    expect(find.text('Forerunner 965 found'), findsOneWidget);
    expect(find.text('Companion app installed'), findsOneWidget);

    await directory.refreshDevices();
    await tester.pump();

    expect(find.text('Forerunner 965 found'), findsOneWidget);
  });
}

class _ErrorGateway implements GarminDeviceDiscoveryGateway {
  const _ErrorGateway();

  @override
  Stream<GarminDevice> get deviceUpdates => const Stream<GarminDevice>.empty();

  @override
  Future<List<GarminDevice>> discoverDevices() async {
    throw const GarminDiscoveryError(
      GarminDiscoveryErrorCode.garminConnectMissing,
      'Garmin Connect missing',
    );
  }
}

class _App extends StatelessWidget {
  const _App({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Scaffold(body: child));
  }
}
