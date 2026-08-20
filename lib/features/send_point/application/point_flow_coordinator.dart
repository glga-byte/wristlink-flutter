import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../devices/domain/device_directory.dart';
import '../../payloads/message_contract.dart';
import '../../send_queue/domain/send_queue_record.dart';
import '../../send_queue/presentation/send_queue_controller.dart';
import '../data/shared_point_parser.dart';
import '../domain/point_draft.dart';
import '../domain/point_parse_result.dart';
import '../presentation/manual_point_picker_screen.dart';
import '../presentation/point_confirmation_screen.dart';
import '../presentation/point_parse_recovery_screen.dart';
import '../presentation/point_status_screen.dart';
import '../share/shared_content_gateway.dart';
import 'point_envelope_factory.dart';
import 'point_queue_actions.dart';

class PointFlowCoordinator {
  PointFlowCoordinator({
    required this.navigatorKey,
    required this.selectedTab,
    required this.deviceDirectory,
    required this.queueController,
    required this.queueActions,
    required this.sharedContentGateway,
    required this.parser,
    required this.envelopeFactory,
    this.mapViewBuilder = buildGooglePointMap,
    this.currentLocationGateway = const GeolocatorCurrentLocationGateway(),
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final ValueNotifier<int> selectedTab;
  final DeviceDirectoryController deviceDirectory;
  final SendQueueController queueController;
  final PointQueueActions queueActions;
  final SharedContentGateway sharedContentGateway;
  final SharedPointParser parser;
  final PointEnvelopeFactory envelopeFactory;
  final PointMapViewBuilder mapViewBuilder;
  final CurrentLocationGateway currentLocationGateway;

  final Set<String> _handledIngressIds = <String>{};
  StreamSubscription<SharedContentRecord>? _liveSubscription;
  Future<void> _shareSequence = Future.value();
  var _started = false;
  var _disposed = false;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _liveSubscription = sharedContentGateway.liveRecords.listen(
      _enqueueSharedRecord,
    );
    final pending = await sharedContentGateway.drainPending();
    for (final record in pending) {
      _enqueueSharedRecord(record);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _liveSubscription?.cancel();
  }

  Future<void> startManualPoint() async {
    if (_disposed) return;
    final draft = await _push<PointDraft>(
      ManualPointPickerScreen(
        mapViewBuilder: mapViewBuilder,
        currentLocationGateway: currentLocationGateway,
      ),
    );
    if (draft != null) await _confirmAndShowStatus(draft);
  }

  Future<void> showStatus(SendQueueRecord record) => _showStatus(record.id);

  void openDevices() {
    final navigator = navigatorKey.currentState;
    if (navigator != null) navigator.popUntil((route) => route.isFirst);
    selectedTab.value = 2;
  }

  void _enqueueSharedRecord(SharedContentRecord record) {
    if (_disposed || !_handledIngressIds.add(record.id)) return;
    _shareSequence = _shareSequence.then((_) => _handleSharedRecord(record));
  }

  Future<void> _handleSharedRecord(SharedContentRecord record) async {
    if (_disposed) return;
    PointParseResult result;
    try {
      result = await parser.parse(record.content);
    } on Object catch (error) {
      result = PointParseFailure(
        code: PointParseErrorCode.noCoordinates,
        originalText: boundSharedContent(record.content),
        message: 'The shared point could not be parsed: $error',
      );
    }

    // At this point the bounded content and parse state are owned by Dart flow
    // state, so native ingress storage can safely remove the record.
    try {
      await sharedContentGateway.acknowledge(record.id);
    } on Object {
      // Native storage may redeliver; the in-memory ingress id set suppresses a
      // duplicate presentation for this app process.
    }

    PointDraft? draft;
    switch (result) {
      case PointParseSuccess(draft: final parsedDraft):
        draft = parsedDraft;
      case PointParseFailure():
        draft = await _push<PointDraft>(
          PointParseRecoveryScreen(failure: result, parser: parser),
        );
    }
    if (draft != null) await _confirmAndShowStatus(draft);
  }

  Future<void> _confirmAndShowStatus(PointDraft draft) async {
    return _confirmAndShowStatusWithIntent(draft, PointIntent.navigate);
  }

  Future<void> _confirmAndShowStatusWithIntent(
    PointDraft draft,
    PointIntent initialIntent,
  ) async {
    final record = await _push<SendQueueRecord>(
      PointConfirmationScreen(
        draft: draft,
        deviceDirectory: deviceDirectory,
        envelopeFactory: envelopeFactory,
        queueActions: queueActions,
        onOpenDevices: openDevices,
        initialIntent: initialIntent,
      ),
    );
    if (record != null) await _showStatus(record.id);
  }

  Future<void> _showStatus(String messageId) {
    return _push<void>(
      PointStatusScreen(
        messageId: messageId,
        queueController: queueController,
        queueActions: queueActions,
        deviceDirectory: deviceDirectory,
        onOpenDevices: openDevices,
        onEditPoint: () => _editPoint(messageId),
      ),
    );
  }

  void _editPoint(String messageId) {
    final matches = queueController.records.where(
      (record) => record.id == messageId,
    );
    if (matches.isEmpty) return;
    final payload = matches.first.message.payload;
    if (payload is! PointPayload) return;
    navigatorKey.currentState?.pop();
    unawaited(
      _confirmAndShowStatusWithIntent(
        PointDraft(
          latitude: payload.latitude,
          longitude: payload.longitude,
          label: payload.label ?? 'Point',
          source: PointDraftSource.manualCoordinates,
        ),
        payload.intent,
      ),
    );
  }

  Future<T?> _push<T>(Widget screen) async {
    while (!_disposed && navigatorKey.currentState == null) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    if (_disposed) return null;
    final route = defaultTargetPlatform == TargetPlatform.iOS
        ? CupertinoPageRoute<T>(builder: (_) => screen)
        : MaterialPageRoute<T>(builder: (_) => screen);
    return navigatorKey.currentState!.push<T>(route);
  }
}
