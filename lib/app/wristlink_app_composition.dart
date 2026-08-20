import 'package:flutter/widgets.dart';

import '../features/devices/data/device_settings_store.dart';
import '../features/devices/data/local_device_directory.dart';
import '../features/garmin_bridge/garmin_acknowledgement_gateway.dart';
import '../features/garmin_bridge/garmin_device_discovery_gateway.dart';
import '../features/garmin_bridge/garmin_send_gateway.dart';
import '../features/send_point/application/point_envelope_factory.dart';
import '../features/send_point/application/point_flow_coordinator.dart';
import '../features/send_point/application/point_queue_actions.dart';
import '../features/send_point/data/google_maps_short_link_resolver.dart';
import '../features/send_point/data/point_draft_parser.dart';
import '../features/send_point/data/shared_point_parser.dart';
import '../features/send_point/presentation/manual_point_picker_screen.dart';
import '../features/send_point/share/shared_content_gateway.dart';
import '../features/send_queue/application/send_queue_delivery_coordinator.dart';
import '../features/send_queue/application/send_queue_delivery_service.dart';
import '../features/send_queue/background/background_send_entrypoint.dart';
import '../features/send_queue/background/background_send_scheduler.dart';
import '../features/send_queue/data/send_queue_repository.dart';
import '../features/send_queue/presentation/send_queue_controller.dart';
import 'platform/background_send_scheduler_provider.dart';
import 'platform/device_settings_store_provider.dart';
import 'platform/garmin_delivery_gateway_provider.dart';
import 'platform/garmin_device_discovery_gateway_provider.dart';
import 'platform/send_queue_repository_provider.dart';
import 'platform/shared_content_gateway_provider.dart';

typedef SendQueueRepositoryFactory = Future<SendQueueRepository> Function();

class WristLinkAppDependencies {
  const WristLinkAppDependencies({
    this.deviceSettingsStore,
    this.discoveryGateway,
    this.sharedContentGateway,
    this.sharedPointParser,
    this.sendQueueRepositoryFactory,
    this.sendGateway,
    this.acknowledgementGateway,
    this.backgroundScheduler,
    this.envelopeFactory,
    this.mapViewBuilder,
    this.currentLocationGateway,
  });

  final DeviceSettingsStore? deviceSettingsStore;
  final GarminDeviceDiscoveryGateway? discoveryGateway;
  final SharedContentGateway? sharedContentGateway;
  final SharedPointParser? sharedPointParser;
  final SendQueueRepositoryFactory? sendQueueRepositoryFactory;
  final GarminSendGateway? sendGateway;
  final GarminAcknowledgementGateway? acknowledgementGateway;
  final BackgroundSendScheduler? backgroundScheduler;
  final PointEnvelopeFactory? envelopeFactory;
  final PointMapViewBuilder? mapViewBuilder;
  final CurrentLocationGateway? currentLocationGateway;
}

class WristLinkAppComposition {
  WristLinkAppComposition({
    required this.navigatorKey,
    required this.selectedTab,
    this.dependencies = const WristLinkAppDependencies(),
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final ValueNotifier<int> selectedTab;
  final WristLinkAppDependencies dependencies;

  late final LocalDeviceDirectory deviceDirectory;
  late final SendQueueController queueController;
  late final SendQueueDeliveryService deliveryService;
  late final PointQueueActions queueActions;
  late final SharedContentGateway sharedContentGateway;
  late final SharedPointParser sharedPointParser;
  late final PointEnvelopeFactory envelopeFactory;
  late final PointFlowCoordinator pointFlowCoordinator;

  var _initialized = false;
  var _disposed = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    deviceDirectory = LocalDeviceDirectory(
      store: dependencies.deviceSettingsStore ?? createDeviceSettingsStore(),
      discoveryGateway:
          dependencies.discoveryGateway ?? createGarminDeviceDiscoveryGateway(),
    );
    await deviceDirectory.load();
    await deviceDirectory.hydrateTransport();

    final repository =
        await (dependencies.sendQueueRepositoryFactory ??
            createSendQueueRepository)();
    queueController = SendQueueController(repository);
    final deliveryCoordinator = SendQueueDeliveryCoordinator(
      repository: repository,
      deviceDirectory: deviceDirectory,
      sendGateway: dependencies.sendGateway ?? createGarminSendGateway(),
      acknowledgementGateway:
          dependencies.acknowledgementGateway ??
          createGarminAcknowledgementGateway(),
    );
    deliveryService = SendQueueDeliveryService(
      repository: repository,
      controller: queueController,
      coordinator: deliveryCoordinator,
      deviceDirectory: deviceDirectory,
      backgroundScheduler:
          dependencies.backgroundScheduler ??
          createBackgroundSendScheduler(
            callbackDispatcher: backgroundSendCallbackDispatcher,
          ),
    );
    await deliveryService.initialize();

    queueActions = DeliveryPointQueueActions(deliveryService);
    sharedContentGateway =
        dependencies.sharedContentGateway ?? createSharedContentGateway();
    sharedPointParser =
        dependencies.sharedPointParser ??
        SharedPointParser(
          directParser: const PointDraftParser(),
          shortLinkResolver: HttpGoogleMapsShortLinkResolver(),
        );
    envelopeFactory = dependencies.envelopeFactory ?? PointEnvelopeFactory();
    pointFlowCoordinator = PointFlowCoordinator(
      navigatorKey: navigatorKey,
      selectedTab: selectedTab,
      deviceDirectory: deviceDirectory,
      queueController: queueController,
      queueActions: queueActions,
      sharedContentGateway: sharedContentGateway,
      parser: sharedPointParser,
      envelopeFactory: envelopeFactory,
      mapViewBuilder: dependencies.mapViewBuilder ?? buildGooglePointMap,
      currentLocationGateway:
          dependencies.currentLocationGateway ??
          const GeolocatorCurrentLocationGateway(),
    );
    _initialized = true;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (!_initialized) return;
    await pointFlowCoordinator.dispose();
    await deliveryService.disposeService();
    deviceDirectory.dispose();
    selectedTab.dispose();
  }
}
