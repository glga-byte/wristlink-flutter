import 'dart:async';

import 'package:flutter/material.dart';

import '../features/devices/data/device_settings_store.dart';
import '../features/garmin_bridge/garmin_device_discovery_gateway.dart';
import 'wristlink_app_composition.dart';
import 'wristlink_app_shell.dart';

class WristLinkApp extends StatefulWidget {
  const WristLinkApp({
    super.key,
    this.deviceSettingsStore,
    this.discoveryGateway,
    this.dependencies = const WristLinkAppDependencies(),
  });

  final DeviceSettingsStore? deviceSettingsStore;
  final GarminDeviceDiscoveryGateway? discoveryGateway;
  final WristLinkAppDependencies dependencies;

  @override
  State<WristLinkApp> createState() => _WristLinkAppState();
}

class _WristLinkAppState extends State<WristLinkApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _selectedTab = ValueNotifier<int>(0);
  late final WristLinkAppComposition _composition;
  late final Future<void> _initialization;
  var _flowStarted = false;

  @override
  void initState() {
    super.initState();
    final supplied = widget.dependencies;
    _composition = WristLinkAppComposition(
      navigatorKey: _navigatorKey,
      selectedTab: _selectedTab,
      dependencies: WristLinkAppDependencies(
        deviceSettingsStore:
            widget.deviceSettingsStore ?? supplied.deviceSettingsStore,
        discoveryGateway: widget.discoveryGateway ?? supplied.discoveryGateway,
        sharedContentGateway: supplied.sharedContentGateway,
        sharedPointParser: supplied.sharedPointParser,
        sendQueueRepositoryFactory: supplied.sendQueueRepositoryFactory,
        sendGateway: supplied.sendGateway,
        acknowledgementGateway: supplied.acknowledgementGateway,
        backgroundScheduler: supplied.backgroundScheduler,
        envelopeFactory: supplied.envelopeFactory,
        mapViewBuilder: supplied.mapViewBuilder,
        currentLocationGateway: supplied.currentLocationGateway,
      ),
    );
    _initialization = _composition.initialize();
  }

  @override
  void dispose() {
    unawaited(_composition.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'WristLink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006B5F),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'WristLink could not initialize: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!_flowStarted) {
            _flowStarted = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(_composition.pointFlowCoordinator.start());
            });
          }
          return WristLinkAppShell(
            deviceDirectory: _composition.deviceDirectory,
            queueController: _composition.queueController,
            selectedTab: _selectedTab,
            onManualPoint: _composition.pointFlowCoordinator.startManualPoint,
            onQueueRecordTap: _composition.pointFlowCoordinator.showStatus,
          );
        },
      ),
    );
  }
}
