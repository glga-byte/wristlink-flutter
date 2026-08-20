enum BackgroundSendPlatform { android, ios, unsupported }

enum BackgroundSchedulingErrorCode {
  unsupportedPlatform,
  initializationFailed,
  schedulingFailed,
  cancellationFailed,
}

class BackgroundSchedulingError {
  const BackgroundSchedulingError({
    required this.code,
    required this.message,
    this.cause,
  });

  final BackgroundSchedulingErrorCode code;
  final String message;
  final Object? cause;
}

class BackgroundSchedulingResult {
  const BackgroundSchedulingResult._({required this.scheduled, this.error});

  const BackgroundSchedulingResult.scheduled() : this._(scheduled: true);

  const BackgroundSchedulingResult.cancelled() : this._(scheduled: false);

  const BackgroundSchedulingResult.failure(BackgroundSchedulingError error)
    : this._(scheduled: false, error: error);

  final bool scheduled;
  final BackgroundSchedulingError? error;

  bool get isSuccess => error == null;
}

abstract interface class BackgroundSendScheduler {
  BackgroundSendPlatform get platform;

  BackgroundSchedulingError? get lastError;

  Future<BackgroundSchedulingResult> initialize();

  Future<BackgroundSchedulingResult> reconcile({
    required bool hasRetryableWork,
    required DateTime? nextWakeUpAt,
    required DateTime now,
  });
}

class UnsupportedBackgroundSendScheduler implements BackgroundSendScheduler {
  const UnsupportedBackgroundSendScheduler();

  static const _error = BackgroundSchedulingError(
    code: BackgroundSchedulingErrorCode.unsupportedPlatform,
    message: 'Background queue retry is unavailable on this platform.',
  );

  @override
  BackgroundSchedulingError? get lastError => _error;

  @override
  BackgroundSendPlatform get platform => BackgroundSendPlatform.unsupported;

  @override
  Future<BackgroundSchedulingResult> initialize() async =>
      const BackgroundSchedulingResult.failure(_error);

  @override
  Future<BackgroundSchedulingResult> reconcile({
    required bool hasRetryableWork,
    required DateTime? nextWakeUpAt,
    required DateTime now,
  }) async => const BackgroundSchedulingResult.failure(_error);
}
