import 'dart:async';
import 'dart:math' as math;

import '../../devices/domain/device_directory.dart';
import '../../devices/domain/garmin_device.dart';
import '../../garmin_bridge/garmin_acknowledgement_gateway.dart';
import '../../garmin_bridge/garmin_send_gateway.dart';
import '../../payloads/message_contract.dart';
import '../data/send_queue_repository.dart';
import '../domain/send_queue_record.dart';

typedef DeliveryClock = DateTime Function();
typedef DeliveryDelay = Future<void> Function(Duration duration);

enum QueueDrainTrigger {
  submission,
  startup,
  foreground,
  deviceReadiness,
  explicitRetry,
  background,
}

enum DeliveryDiagnosticCode {
  malformedAcknowledgement,
  unknownAcknowledgement,
  lateAcknowledgement,
  duplicateAcknowledgement,
  concurrentTransition,
  storageFailure,
}

class DeliveryDiagnostic {
  const DeliveryDiagnostic({
    required this.code,
    required this.message,
    this.messageId,
    this.acknowledgementId,
    this.acknowledgementDiagnosticCode,
    this.contractErrorCode,
  });

  final DeliveryDiagnosticCode code;
  final String message;
  final String? messageId;
  final String? acknowledgementId;
  final GarminAcknowledgementDiagnosticCode? acknowledgementDiagnosticCode;
  final ContractErrorCode? contractErrorCode;
}

class QueueDrainResult {
  const QueueDrainResult({
    required this.records,
    required this.hasRetryableWork,
    this.nextWakeUpAt,
  });

  final List<SendQueueRecord> records;
  final bool hasRetryableWork;
  final DateTime? nextWakeUpAt;
}

class DeliveryRetryPolicy {
  const DeliveryRetryPolicy({
    this.initialBackoff = const Duration(seconds: 15),
    this.maximumBackoff = const Duration(minutes: 15),
    this.acknowledgementTimeout = const Duration(seconds: 30),
    this.interruptedSendRecoveryWindow = const Duration(seconds: 30),
  });

  final Duration initialBackoff;
  final Duration maximumBackoff;
  final Duration acknowledgementTimeout;
  final Duration interruptedSendRecoveryWindow;

  Duration backoffForAttempt(int attemptCount) {
    final exponent = math.max(0, attemptCount - 1);
    final multiplier = math.pow(2, math.min(exponent, 20)).toInt();
    final milliseconds = math.min(
      initialBackoff.inMilliseconds * multiplier,
      maximumBackoff.inMilliseconds,
    );
    return Duration(milliseconds: milliseconds);
  }

  SendQueueFailure classify(Object error) {
    if (error is TimeoutException) {
      return const SendQueueFailure(
        code: SendQueueFailureCode.transportTimeout,
        message: 'Garmin message transport timed out.',
        isTransient: true,
      );
    }
    if (error is ContractError) {
      return SendQueueFailure(
        code: error.code == ContractErrorCode.payloadTooLarge
            ? SendQueueFailureCode.payloadTooLarge
            : SendQueueFailureCode.payloadInvalid,
        message: error.message,
        isTransient: false,
      );
    }
    if (error is GarminSendError) {
      return switch (error.code) {
        GarminSendErrorCode.sdkUnavailable => SendQueueFailure(
          code: SendQueueFailureCode.sdkUnavailable,
          message: error.message,
          isTransient: true,
        ),
        GarminSendErrorCode.deviceUnavailable => SendQueueFailure(
          code: SendQueueFailureCode.deviceDisconnected,
          message: error.message,
          isTransient: true,
        ),
        GarminSendErrorCode.transportTimeout => SendQueueFailure(
          code: SendQueueFailureCode.transportTimeout,
          message: error.message,
          isTransient: true,
        ),
        GarminSendErrorCode.appNotInstalled => SendQueueFailure(
          code: SendQueueFailureCode.companionMissing,
          message: error.message,
          isTransient: false,
        ),
        GarminSendErrorCode.payloadTooLarge => SendQueueFailure(
          code: SendQueueFailureCode.payloadTooLarge,
          message: error.message,
          isTransient: false,
        ),
        GarminSendErrorCode.invalidDeviceId => SendQueueFailure(
          code: SendQueueFailureCode.payloadInvalid,
          message: error.message,
          isTransient: false,
        ),
        GarminSendErrorCode.unsupportedPlatform => SendQueueFailure(
          code: SendQueueFailureCode.unsupportedPlatform,
          message: error.message,
          isTransient: false,
        ),
        GarminSendErrorCode.nativeFailure => SendQueueFailure(
          code: SendQueueFailureCode.nativeFailure,
          message: error.message,
          isTransient: false,
        ),
      };
    }
    return SendQueueFailure(
      code: SendQueueFailureCode.nativeFailure,
      message: 'Unexpected Garmin delivery failure: $error',
      isTransient: false,
    );
  }
}

class SendQueueDeliveryCoordinator {
  SendQueueDeliveryCoordinator({
    required SendQueueRepository repository,
    required DeviceDirectory deviceDirectory,
    required GarminSendGateway sendGateway,
    required GarminAcknowledgementGateway acknowledgementGateway,
    DeliveryRetryPolicy retryPolicy = const DeliveryRetryPolicy(),
    DeliveryClock clock = _systemClock,
    DeliveryDelay delay = Future<void>.delayed,
  }) : _repository = repository,
       _deviceDirectory = deviceDirectory,
       _sendGateway = sendGateway,
       _acknowledgementGateway = acknowledgementGateway,
       _retryPolicy = retryPolicy,
       _clock = clock,
       _delay = delay;

  final SendQueueRepository _repository;
  final DeviceDirectory _deviceDirectory;
  final GarminSendGateway _sendGateway;
  final GarminAcknowledgementGateway _acknowledgementGateway;
  final DeliveryRetryPolicy _retryPolicy;
  final DeliveryClock _clock;
  final DeliveryDelay _delay;
  final StreamController<SendQueueRecord> _mutations =
      StreamController<SendQueueRecord>.broadcast();
  final StreamController<DeliveryDiagnostic> _diagnostics =
      StreamController<DeliveryDiagnostic>.broadcast();
  final Map<String, Completer<WatchAcknowledgement>> _acknowledgementWaiters =
      <String, Completer<WatchAcknowledgement>>{};

  StreamSubscription<GarminAcknowledgementEvent>?
  _acknowledgementEventSubscription;
  Future<QueueDrainResult>? _activeDrain;
  var _drainRequested = false;
  var _ignoreScheduleForNextDrain = false;
  DateTime? _requestedDeadline;
  var _started = false;

  Stream<SendQueueRecord> get mutations => _mutations.stream;
  Stream<DeliveryDiagnostic> get diagnostics => _diagnostics.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _acknowledgementEventSubscription = _acknowledgementGateway.events.listen(
      _routeAcknowledgementEvent,
    );
    await recoverInterruptedSends();
  }

  Future<QueueDrainResult> requestDrain(
    QueueDrainTrigger trigger, {
    DateTime? deadline,
  }) {
    _drainRequested = true;
    _ignoreScheduleForNextDrain |= _triggerIgnoresSchedule(trigger);
    if (deadline != null &&
        (_requestedDeadline == null ||
            deadline.isBefore(_requestedDeadline!))) {
      _requestedDeadline = deadline.toUtc();
    }
    final active = _activeDrain;
    if (active != null) return active;

    late final Future<QueueDrainResult> drain;
    drain = _runRequestedDrains().whenComplete(() {
      if (identical(_activeDrain, drain)) {
        _activeDrain = null;
      }
    });
    _activeDrain = drain;
    return drain;
  }

  Future<void> recoverInterruptedSends() async {
    final now = _clock().toUtc();
    final records = await _repository.readAll();
    for (final record in records.where(
      (record) => record.status == SendQueueStatus.sending,
    )) {
      if (_acknowledgementWaiters.containsKey(record.id)) continue;
      final deadline =
          record.acknowledgementDeadline ??
          record.updatedAt.add(_retryPolicy.interruptedSendRecoveryWindow);
      if (deadline.isAfter(now)) {
        if (record.acknowledgementDeadline == null) {
          await _persist(
            record.copyWith(updatedAt: now, acknowledgementDeadline: deadline),
            expectedStatuses: const {SendQueueStatus.sending},
          );
        }
        continue;
      }
      await _persist(
        record.copyWith(
          status: SendQueueStatus.failed,
          updatedAt: now,
          failure: const SendQueueFailure(
            code: SendQueueFailureCode.deliveryOutcomeUnknown,
            message:
                'Delivery may have reached the watch. Retry explicitly to avoid an unintended duplicate.',
            isTransient: false,
          ),
          clearNextAttemptAt: true,
          clearAcknowledgementDeadline: true,
        ),
        expectedStatuses: const {SendQueueStatus.sending},
      );
    }
  }

  Future<void> dispose() async {
    await _acknowledgementEventSubscription?.cancel();
    await _mutations.close();
    await _diagnostics.close();
  }

  Future<QueueDrainResult> _runRequestedDrains() async {
    do {
      _drainRequested = false;
      final ignoreSchedule = _ignoreScheduleForNextDrain;
      _ignoreScheduleForNextDrain = false;
      final deadline = _requestedDeadline;
      _requestedDeadline = null;
      await _drainOnce(ignoreSchedule: ignoreSchedule, deadline: deadline);
    } while (_drainRequested);
    return queueDrainResultForRecords(
      await _repository.readAll(),
      _clock().toUtc(),
      retryPolicy: _retryPolicy,
    );
  }

  Future<void> _drainOnce({
    required bool ignoreSchedule,
    required DateTime? deadline,
  }) async {
    await recoverInterruptedSends();
    final now = _clock().toUtc();
    final records = await _repository.readAll();
    final candidates =
        records
            .where((record) {
              if (record.status != SendQueueStatus.pending) return false;
              final nextAttemptAt = record.nextAttemptAt;
              return ignoreSchedule ||
                  nextAttemptAt == null ||
                  !nextAttemptAt.isAfter(now);
            })
            .toList(growable: false)
          ..sort((left, right) => left.createdAt.compareTo(right.createdAt));

    for (final candidate in candidates) {
      if (_deadlineExpired(deadline)) return;
      final device = _findTarget(candidate.deviceId);
      if (device == null) {
        await _keepPending(
          candidate,
          const SendQueueFailure(
            code: SendQueueFailureCode.targetOffline,
            message: 'The selected watch is not currently available.',
            isTransient: true,
          ),
          now,
        );
        continue;
      }
      if (device.companionInstallState == CompanionInstallState.missing) {
        await _failPending(
          candidate,
          const SendQueueFailure(
            code: SendQueueFailureCode.companionMissing,
            message:
                'The WristLink companion app is not installed on the selected watch.',
            isTransient: false,
          ),
          now,
        );
        continue;
      }
      if (!device.isReady) {
        await _keepPending(
          candidate,
          const SendQueueFailure(
            code: SendQueueFailureCode.targetOffline,
            message: 'The selected watch is offline.',
            isTransient: true,
          ),
          now,
        );
        continue;
      }

      final claimed = await _repository.claimPending(
        candidate.id,
        now,
        ignoreSchedule: ignoreSchedule,
      );
      if (claimed == null) continue;
      _mutations.add(claimed);
      await _attemptDelivery(claimed, device, executionDeadline: deadline);
    }
  }

  Future<void> _attemptDelivery(
    SendQueueRecord claimed,
    GarminDevice target, {
    required DateTime? executionDeadline,
  }) async {
    final requiresAcknowledgement =
        claimed.message.kind.requiresAcknowledgement;
    final waiter = requiresAcknowledgement
        ? (_acknowledgementWaiters[claimed.id] =
              Completer<WatchAcknowledgement>())
        : null;
    try {
      try {
        await _withinDeadline(
          _sendGateway.sendMessage(
            deviceId: target.id,
            message: claimed.message,
          ),
          executionDeadline,
        );
      } on _DeliveryBudgetExpired {
        return;
      } on Object catch (error) {
        final current = await _repository.findById(claimed.id);
        if (current != null && current.status == SendQueueStatus.sending) {
          await _applyTransportFailure(current, _retryPolicy.classify(error));
        }
        return;
      }

      final current = await _repository.findById(claimed.id);
      if (current == null || current.status != SendQueueStatus.sending) return;
      final now = _clock().toUtc();
      if (!requiresAcknowledgement) {
        await _persist(
          current.applyTransportSuccess(now),
          expectedStatuses: const {SendQueueStatus.sending},
        );
        return;
      }

      final acknowledgementDeadline = now.add(
        _retryPolicy.acknowledgementTimeout,
      );
      await _persist(
        current.applyTransportSuccess(
          now,
          acknowledgementDeadline: acknowledgementDeadline,
        ),
        expectedStatuses: const {SendQueueStatus.sending},
      );
      await _waitForAcknowledgement(
        messageId: claimed.id,
        waiter: waiter!,
        deadline: acknowledgementDeadline,
        executionDeadline: executionDeadline,
      );
    } finally {
      if (waiter != null &&
          identical(_acknowledgementWaiters[claimed.id], waiter)) {
        _acknowledgementWaiters.remove(claimed.id);
      }
    }
  }

  Future<void> _waitForAcknowledgement({
    required String messageId,
    required Completer<WatchAcknowledgement> waiter,
    required DateTime deadline,
    required DateTime? executionDeadline,
  }) async {
    final remaining = deadline.difference(_clock().toUtc());
    final executionRemaining = executionDeadline?.difference(_clock().toUtc());
    final waitDuration =
        executionRemaining != null && executionRemaining < remaining
        ? executionRemaining
        : remaining;
    final acknowledgement = await Future.any<WatchAcknowledgement?>([
      waiter.future.then<WatchAcknowledgement?>((value) => value),
      _delay(
        waitDuration.isNegative ? Duration.zero : waitDuration,
      ).then((_) => null),
    ]);
    if (acknowledgement != null) {
      await _applyAcknowledgement(acknowledgement);
      return;
    }

    if (_deadlineExpired(executionDeadline) &&
        executionDeadline != null &&
        executionDeadline.isBefore(deadline)) {
      return;
    }

    final current = await _repository.findById(messageId);
    if (current == null || current.status != SendQueueStatus.sending) return;
    await _persist(
      current.copyWith(
        status: SendQueueStatus.failed,
        updatedAt: _clock().toUtc(),
        failure: const SendQueueFailure(
          code: SendQueueFailureCode.acknowledgementTimeout,
          message:
              'The watch did not acknowledge the point. Retry explicitly if it was not received.',
          isTransient: false,
        ),
        clearNextAttemptAt: true,
        clearAcknowledgementDeadline: true,
      ),
      expectedStatuses: const {SendQueueStatus.sending},
    );
  }

  void _routeAcknowledgement(WatchAcknowledgement acknowledgement) {
    final waiter = _acknowledgementWaiters[acknowledgement.ackFor];
    if (waiter == null) {
      unawaited(_applyAcknowledgement(acknowledgement));
      return;
    }
    if (waiter.isCompleted) {
      _diagnostics.add(
        DeliveryDiagnostic(
          code: DeliveryDiagnosticCode.duplicateAcknowledgement,
          message: 'A duplicate acknowledgement was ignored.',
          messageId: acknowledgement.ackFor,
          acknowledgementId: acknowledgement.id,
        ),
      );
      return;
    }
    waiter.complete(acknowledgement);
  }

  void _routeAcknowledgementEvent(GarminAcknowledgementEvent event) {
    switch (event) {
      case GarminAcknowledgementReceived(:final acknowledgement):
        _routeAcknowledgement(acknowledgement);
      case GarminAcknowledgementDiagnostic():
        _diagnostics.add(
          DeliveryDiagnostic(
            code: DeliveryDiagnosticCode.malformedAcknowledgement,
            message: event.message,
            acknowledgementDiagnosticCode: event.code,
            contractErrorCode: event.contractErrorCode,
          ),
        );
    }
  }

  Future<void> _applyAcknowledgement(
    WatchAcknowledgement acknowledgement,
  ) async {
    final current = await _repository.findById(acknowledgement.ackFor);
    if (current == null) {
      _diagnostics.add(
        DeliveryDiagnostic(
          code: DeliveryDiagnosticCode.unknownAcknowledgement,
          message: 'An acknowledgement for an unknown message was ignored.',
          messageId: acknowledgement.ackFor,
          acknowledgementId: acknowledgement.id,
        ),
      );
      return;
    }
    if (current.status != SendQueueStatus.sending) {
      final duplicate =
          current.status == SendQueueStatus.sent &&
          acknowledgement.outcome == WatchAcknowledgementOutcome.sent;
      _diagnostics.add(
        DeliveryDiagnostic(
          code: duplicate
              ? DeliveryDiagnosticCode.duplicateAcknowledgement
              : DeliveryDiagnosticCode.lateAcknowledgement,
          message: duplicate
              ? 'A duplicate acknowledgement was ignored.'
              : 'A late acknowledgement could not change the queue record.',
          messageId: acknowledgement.ackFor,
          acknowledgementId: acknowledgement.id,
        ),
      );
      return;
    }

    var transitioned = current.applyAcknowledgement(
      acknowledgement,
      _clock().toUtc(),
    );
    if (transitioned.status == SendQueueStatus.pending) {
      transitioned = transitioned.copyWith(
        nextAttemptAt: transitioned.updatedAt.add(
          _retryPolicy.backoffForAttempt(transitioned.attemptCount),
        ),
      );
    }
    try {
      await _persist(
        transitioned,
        expectedStatuses: const {SendQueueStatus.sending},
      );
    } on QueueStorageException catch (error) {
      if (error.code != QueueStorageErrorCode.invalidTransition) rethrow;
      _diagnostics.add(
        DeliveryDiagnostic(
          code: DeliveryDiagnosticCode.concurrentTransition,
          message:
              'A concurrent queue transition won acknowledgement correlation.',
          messageId: acknowledgement.ackFor,
          acknowledgementId: acknowledgement.id,
        ),
      );
    }
  }

  Future<void> _applyTransportFailure(
    SendQueueRecord current,
    SendQueueFailure failure,
  ) async {
    final now = _clock().toUtc();
    final transitioned = current.copyWith(
      status: failure.isTransient
          ? SendQueueStatus.pending
          : SendQueueStatus.failed,
      updatedAt: now,
      failure: failure,
      nextAttemptAt: failure.isTransient
          ? now.add(_retryPolicy.backoffForAttempt(current.attemptCount))
          : null,
      clearNextAttemptAt: !failure.isTransient,
      clearAcknowledgementDeadline: true,
    );
    await _persist(
      transitioned,
      expectedStatuses: const {SendQueueStatus.sending},
    );
  }

  Future<void> _keepPending(
    SendQueueRecord record,
    SendQueueFailure failure,
    DateTime now,
  ) async {
    await _persist(
      record.copyWith(
        updatedAt: now,
        failure: failure,
        nextAttemptAt: now.add(
          _retryPolicy.backoffForAttempt(math.max(1, record.attemptCount)),
        ),
        clearAcknowledgementDeadline: true,
      ),
      expectedStatuses: const {SendQueueStatus.pending},
    );
  }

  Future<void> _failPending(
    SendQueueRecord record,
    SendQueueFailure failure,
    DateTime now,
  ) async {
    await _persist(
      record.copyWith(
        status: SendQueueStatus.failed,
        updatedAt: now,
        failure: failure,
        clearNextAttemptAt: true,
        clearAcknowledgementDeadline: true,
      ),
      expectedStatuses: const {SendQueueStatus.pending},
    );
  }

  Future<SendQueueRecord> _persist(
    SendQueueRecord record, {
    required Set<SendQueueStatus> expectedStatuses,
  }) async {
    try {
      final stored = await _repository.saveTransition(
        record,
        expectedStatuses: expectedStatuses,
      );
      _mutations.add(stored);
      return stored;
    } on QueueStorageException catch (error) {
      if (error.code == QueueStorageErrorCode.invalidTransition) {
        _diagnostics.add(
          DeliveryDiagnostic(
            code: DeliveryDiagnosticCode.concurrentTransition,
            message: 'A concurrent queue transition was preserved.',
            messageId: record.id,
          ),
        );
        final current = await _repository.findById(record.id);
        if (current != null) return current;
      }
      _diagnostics.add(
        DeliveryDiagnostic(
          code: DeliveryDiagnosticCode.storageFailure,
          message: error.message,
          messageId: record.id,
        ),
      );
      rethrow;
    }
  }

  GarminDevice? _findTarget(GarminDeviceId? id) {
    if (id == null) return null;
    for (final device in _deviceDirectory.devices) {
      if (device.id == id) return device;
    }
    return null;
  }

  bool _deadlineExpired(DateTime? deadline) {
    return deadline != null && !_clock().toUtc().isBefore(deadline);
  }

  Future<T> _withinDeadline<T>(Future<T> future, DateTime? deadline) {
    if (deadline == null) return future;
    final remaining = deadline.difference(_clock().toUtc());
    if (remaining <= Duration.zero) {
      return Future<T>.error(const _DeliveryBudgetExpired());
    }
    return future.timeout(
      remaining,
      onTimeout: () => throw const _DeliveryBudgetExpired(),
    );
  }
}

QueueDrainResult queueDrainResultForRecords(
  List<SendQueueRecord> records,
  DateTime now, {
  DeliveryRetryPolicy retryPolicy = const DeliveryRetryPolicy(),
}) {
  final wakeUps = <DateTime>[];
  var hasRetryableWork = false;
  for (final record in records) {
    if (record.status == SendQueueStatus.pending &&
        (record.failure == null || record.failure!.isTransient)) {
      hasRetryableWork = true;
      wakeUps.add(record.nextAttemptAt ?? now);
    } else if (record.status == SendQueueStatus.sending) {
      hasRetryableWork = true;
      wakeUps.add(
        record.acknowledgementDeadline ??
            record.updatedAt.add(retryPolicy.interruptedSendRecoveryWindow),
      );
    }
  }
  wakeUps.sort();
  return QueueDrainResult(
    records: List.unmodifiable(records),
    hasRetryableWork: hasRetryableWork,
    nextWakeUpAt: wakeUps.firstOrNull,
  );
}

DateTime _systemClock() => DateTime.now().toUtc();

bool _triggerIgnoresSchedule(QueueDrainTrigger trigger) {
  return trigger == QueueDrainTrigger.submission ||
      trigger == QueueDrainTrigger.deviceReadiness ||
      trigger == QueueDrainTrigger.explicitRetry;
}

class _DeliveryBudgetExpired implements Exception {
  const _DeliveryBudgetExpired();
}
