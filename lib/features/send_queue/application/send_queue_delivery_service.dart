import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../devices/domain/device_directory.dart';
import '../background/background_send_scheduler.dart';
import '../data/send_queue_repository.dart';
import '../domain/send_queue_record.dart';
import '../presentation/send_queue_controller.dart';
import 'send_queue_delivery_coordinator.dart';

class SendQueueDeliveryService extends WidgetsBindingObserver {
  SendQueueDeliveryService({
    required SendQueueRepository repository,
    required SendQueueController controller,
    required SendQueueDeliveryCoordinator coordinator,
    required DeviceDirectoryController deviceDirectory,
    required BackgroundSendScheduler backgroundScheduler,
    DeliveryClock clock = _systemClock,
  }) : _repository = repository,
       _controller = controller,
       _coordinator = coordinator,
       _deviceDirectory = deviceDirectory,
       _backgroundScheduler = backgroundScheduler,
       _clock = clock;

  final SendQueueRepository _repository;
  final SendQueueController _controller;
  final SendQueueDeliveryCoordinator _coordinator;
  final DeviceDirectoryController _deviceDirectory;
  final BackgroundSendScheduler _backgroundScheduler;
  final DeliveryClock _clock;
  final Set<Future<void>> _activeAsynchronousWork = <Future<void>>{};
  StreamSubscription<SendQueueRecord>? _mutationSubscription;
  Future<QueueDrainResult>? _foregroundTrigger;
  var _hydratingForForeground = false;
  var _initialized = false;
  var _disposed = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    await _controller.initialize();
    if (_controller.storageError != null) {
      _initialized = true;
      return;
    }
    await _backgroundScheduler.initialize();
    await _coordinator.start();
    _mutationSubscription = _coordinator.mutations.listen((_) {
      _launchObservedWork(
        _refreshSnapshot,
        context: 'refreshing the queue after a delivery mutation',
      );
    });
    _deviceDirectory.addListener(_handleDeviceDirectoryChange);
    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
    _launchObservedDrain(QueueDrainTrigger.startup);
  }

  Future<SendQueueRecord> submit(SendQueueRecord record) async {
    _ensureReady();
    final stored = await _controller.enqueue(record);
    _launchObservedDrain(QueueDrainTrigger.submission);
    return stored;
  }

  Future<SendQueueRecord> retry(String messageId) async {
    _ensureReady();
    final retried = await _repository.retryFailed(messageId, _clock().toUtc());
    await _controller.refresh();
    await trigger(QueueDrainTrigger.explicitRetry);
    return (await _repository.findById(retried.id)) ?? retried;
  }

  Future<QueueDrainResult> trigger(QueueDrainTrigger trigger) {
    _ensureReady();
    if (trigger == QueueDrainTrigger.foreground) {
      return _foregroundTrigger ??= _hydrateThenDrainForeground();
    }
    return _drain(trigger);
  }

  Future<QueueDrainResult> _hydrateThenDrainForeground() async {
    try {
      _hydratingForForeground = true;
      final hydration = await _deviceDirectory.hydrateTransport();
      return await _drain(
        hydration is DeviceRefreshSuccess
            ? QueueDrainTrigger.deviceReadiness
            : QueueDrainTrigger.foreground,
      );
    } finally {
      _hydratingForForeground = false;
      _foregroundTrigger = null;
    }
  }

  Future<QueueDrainResult> _drain(QueueDrainTrigger trigger) async {
    final result = await _coordinator.requestDrain(trigger);
    await _controller.refresh();
    await _backgroundScheduler.reconcile(
      hasRetryableWork: result.hasRetryableWork,
      nextWakeUpAt: result.nextWakeUpAt,
      now: _clock().toUtc(),
    );
    return result;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _initialized && !_disposed) {
      _launchObservedDrain(QueueDrainTrigger.foreground);
    }
  }

  Future<void> disposeService() async {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _deviceDirectory.removeListener(_handleDeviceDirectoryChange);
    await _mutationSubscription?.cancel();
    await Future.wait(List<Future<void>>.of(_activeAsynchronousWork));
    await _coordinator.dispose();
    await _controller.disposeRepository();
  }

  void _handleDeviceDirectoryChange() {
    if (_initialized && !_disposed && !_hydratingForForeground) {
      _launchObservedDrain(QueueDrainTrigger.deviceReadiness);
    }
  }

  void _launchObservedDrain(QueueDrainTrigger trigger) {
    _launchObservedWork(() async {
      await this.trigger(trigger);
    }, context: 'running an asynchronous ${trigger.name} queue drain');
  }

  void _launchObservedWork(
    Future<void> Function() work, {
    required String context,
  }) {
    if (_disposed) return;
    late final Future<void> tracked;
    tracked = Future<void>.sync(work)
        .then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'WristLink send queue',
                context: ErrorDescription(context),
              ),
            );
          },
        )
        .whenComplete(() {
          _activeAsynchronousWork.remove(tracked);
        });
    _activeAsynchronousWork.add(tracked);
    unawaited(tracked);
  }

  Future<void> _refreshSnapshot() async {
    if (_disposed) return;
    try {
      await _controller.refresh();
      final result = queueDrainResultForRecords(
        _controller.records,
        _clock().toUtc(),
      );
      await _backgroundScheduler.reconcile(
        hasRetryableWork: result.hasRetryableWork,
        nextWakeUpAt: result.nextWakeUpAt,
        now: _clock().toUtc(),
      );
    } on QueueStorageException {
      // The controller already publishes the typed storage error.
    }
  }

  void _ensureReady() {
    if (!_initialized || _disposed || _controller.storageError != null) {
      throw StateError('The send queue delivery service is not available.');
    }
  }
}

DateTime _systemClock() => DateTime.now().toUtc();
