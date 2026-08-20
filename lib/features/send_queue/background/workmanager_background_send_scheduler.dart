import 'package:workmanager/workmanager.dart';

import 'background_send_scheduler.dart';

const backgroundSendUniqueWorkName = 'com.wristlink.sendQueue.backgroundRetry';
const backgroundSendTaskName = 'wristlinkSendQueueRetry';

abstract interface class WorkmanagerClient {
  Future<void> initialize(Function callbackDispatcher);

  Future<void> registerOneOff({required Duration initialDelay});

  Future<void> registerPeriodic({required Duration initialDelay});

  Future<void> cancel();
}

class PluginWorkmanagerClient implements WorkmanagerClient {
  PluginWorkmanagerClient({Workmanager? workmanager})
    : _workmanager = workmanager ?? Workmanager();

  final Workmanager _workmanager;

  @override
  Future<void> initialize(Function callbackDispatcher) {
    return _workmanager.initialize(callbackDispatcher);
  }

  @override
  Future<void> registerOneOff({required Duration initialDelay}) {
    return _workmanager.registerOneOffTask(
      backgroundSendUniqueWorkName,
      backgroundSendTaskName,
      initialDelay: initialDelay,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 15),
      tag: backgroundSendTaskName,
    );
  }

  @override
  Future<void> registerPeriodic({required Duration initialDelay}) {
    return _workmanager.registerPeriodicTask(
      backgroundSendUniqueWorkName,
      backgroundSendTaskName,
      frequency: const Duration(minutes: 15),
      initialDelay: initialDelay,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
        requiresStorageNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 15),
      tag: backgroundSendTaskName,
    );
  }

  @override
  Future<void> cancel() {
    return _workmanager.cancelByUniqueName(backgroundSendUniqueWorkName);
  }
}

class WorkmanagerBackgroundSendScheduler implements BackgroundSendScheduler {
  WorkmanagerBackgroundSendScheduler({
    required this.platform,
    required Function callbackDispatcher,
    WorkmanagerClient? client,
  }) : _callbackDispatcher = callbackDispatcher,
       _client = client ?? PluginWorkmanagerClient();

  @override
  final BackgroundSendPlatform platform;
  final Function _callbackDispatcher;
  final WorkmanagerClient _client;
  BackgroundSchedulingError? _lastError;
  var _initialized = false;

  @override
  BackgroundSchedulingError? get lastError => _lastError;

  @override
  Future<BackgroundSchedulingResult> initialize() async {
    if (_initialized) {
      return const BackgroundSchedulingResult.cancelled();
    }
    if (platform == BackgroundSendPlatform.unsupported) {
      return _failure(
        BackgroundSchedulingErrorCode.unsupportedPlatform,
        'Background queue retry is unavailable on this platform.',
      );
    }
    try {
      await _client.initialize(_callbackDispatcher);
      _initialized = true;
      _lastError = null;
      return const BackgroundSchedulingResult.cancelled();
    } on Object catch (error) {
      return _failure(
        BackgroundSchedulingErrorCode.initializationFailed,
        'Background queue retry could not be initialized.',
        error,
      );
    }
  }

  @override
  Future<BackgroundSchedulingResult> reconcile({
    required bool hasRetryableWork,
    required DateTime? nextWakeUpAt,
    required DateTime now,
  }) async {
    if (!_initialized) {
      final initialized = await initialize();
      if (!initialized.isSuccess) return initialized;
    }
    if (!hasRetryableWork) {
      try {
        await _client.cancel();
        _lastError = null;
        return const BackgroundSchedulingResult.cancelled();
      } on Object catch (error) {
        return _failure(
          BackgroundSchedulingErrorCode.cancellationFailed,
          'Scheduled background queue retry could not be cancelled.',
          error,
        );
      }
    }

    final nowUtc = now.toUtc();
    final wakeUp = (nextWakeUpAt ?? nowUtc).toUtc();
    final initialDelay = wakeUp.isAfter(nowUtc)
        ? wakeUp.difference(nowUtc)
        : Duration.zero;
    try {
      switch (platform) {
        case BackgroundSendPlatform.android:
          await _client.registerOneOff(initialDelay: initialDelay);
        case BackgroundSendPlatform.ios:
          await _client.registerPeriodic(initialDelay: initialDelay);
        case BackgroundSendPlatform.unsupported:
          return _failure(
            BackgroundSchedulingErrorCode.unsupportedPlatform,
            'Background queue retry is unavailable on this platform.',
          );
      }
      _lastError = null;
      return const BackgroundSchedulingResult.scheduled();
    } on Object catch (error) {
      return _failure(
        BackgroundSchedulingErrorCode.schedulingFailed,
        'Background queue retry could not be scheduled.',
        error,
      );
    }
  }

  BackgroundSchedulingResult _failure(
    BackgroundSchedulingErrorCode code,
    String message, [
    Object? cause,
  ]) {
    final error = BackgroundSchedulingError(
      code: code,
      message: message,
      cause: cause,
    );
    _lastError = error;
    return BackgroundSchedulingResult.failure(error);
  }
}
