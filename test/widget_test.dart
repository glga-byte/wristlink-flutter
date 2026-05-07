import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/app/wristlink_app.dart';
import 'package:wristlink_flutter/features/devices/data/device_settings_store.dart';
import 'package:wristlink_flutter/features/devices/data/in_memory_device_settings_store.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_device_discovery_gateway.dart';

void main() {
  const garminDevicesChannel = MethodChannel('wristlink/garmin_devices');

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(garminDevicesChannel, null);
  });

  testWidgets('renders the primary tab scaffold and initial Send destination', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Send to watch'), findsOneWidget);
    expect(find.text('Share a place from Maps'), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);
    expect(find.byIcon(Icons.watch_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.text('Manual point'), findsOneWidget);
    expect(find.byIcon(Icons.add_location_alt_outlined), findsOneWidget);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Note'), 120);

    expect(find.text('Note'), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Command'), 120);

    expect(find.text('Command'), findsOneWidget);
    expect(find.byIcon(Icons.code_rounded), findsOneWidget);
  });

  testWidgets('switches between primary tab destinations', (tester) async {
    await tester.pumpWidget(_testApp());

    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    expect(find.text('ALL PROGRESS'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('queued'), findsNWidgets(2));
    expect(find.text('sending'), findsOneWidget);
    expect(find.text('failed'), findsNWidgets(2));
    expect(find.text('delivered'), findsOneWidget);
    expect(find.text('Trailhead parking'), findsOneWidget);
    expect(find.text('Coffee meet point'), findsOneWidget);
    expect(find.text('Home note'), findsOneWidget);
    expect(find.text('Gym timer'), findsOneWidget);

    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();

    expect(find.text('GARMIN CONNECT IQ'), findsOneWidget);
    expect(find.text('No Garmin devices'), findsOneWidget);
    expect(
      find.text('Refresh to authorize Garmin Connect IQ devices.'),
      findsOneWidget,
    );
    expect(find.text('Forerunner 965'), findsNothing);
    expect(find.text('Fenix 7'), findsNothing);
    expect(find.text('Venu 3'), findsNothing);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('WRISTLINK'), findsOneWidget);
    expect(find.text('Default watch'), findsOneWidget);
    expect(find.text('Choose target watch'), findsOneWidget);
    expect(find.text('Background sending'), findsOneWidget);
    expect(find.text('Retry when watch reconnects'), findsOneWidget);
    expect(find.text('Developer Tools'), findsOneWidget);
    expect(find.text('Emulator device and bridge states'), findsOneWidget);
    expect(find.text('About WristLink'), findsOneWidget);
  });

  testWidgets('Devices refresh calls the native Garmin discovery channel', (
    tester,
  ) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(garminDevicesChannel, (call) async {
          calls.add(call.method);
          return [
            {
              'id': 'native-test-watch',
              'name': 'Native Test Watch',
              'reachability': 'reachable',
              'companionInstallState': 'installed',
            },
          ];
        });

    await tester.pumpWidget(
      _testApp(discoveryGateway: MethodChannelGarminDeviceDiscoveryGateway()),
    );

    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(calls, ['discoverDevices']);
    expect(find.text('Native Test Watch'), findsOneWidget);
    expect(find.text('connected'), findsOneWidget);
  });

  testWidgets('Developer Tools offline state appears on Devices tab', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Developer Tools'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Offline'));
    await tester.pumpAndSettle();

    expect(
      find.text('Emulator is enabled · offline · installed'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devices'));
    await tester.pumpAndSettle();

    expect(find.text('WristLink Emulator'), findsOneWidget);
    expect(find.text('offline'), findsOneWidget);
    expect(find.text('connected'), findsNothing);
  });
}

Widget _testApp({
  DeviceSettingsStore? deviceSettingsStore,
  GarminDeviceDiscoveryGateway discoveryGateway =
      const UnsupportedGarminDeviceDiscoveryGateway(),
}) {
  return WristLinkApp(
    deviceSettingsStore: deviceSettingsStore ?? InMemoryDeviceSettingsStore(),
    discoveryGateway: discoveryGateway,
  );
}
