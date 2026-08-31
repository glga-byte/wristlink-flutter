import '../../devices/domain/garmin_device.dart';
import '../../payloads/message_contract.dart';

enum SendQueueStatus { pending, sending, sent, failed }

enum SendQueueFailureCode {
  targetOffline,
  sdkUnavailable,
  transportTimeout,
  deviceDisconnected,
  companionMissing,
  payloadInvalid,
  payloadTooLarge,
  unsupportedPlatform,
  rejected,
  unsupported,
  acknowledgementTimeout,
  deliveryOutcomeUnknown,
  storageFailure,
  nativeFailure,
}

class SendQueueFailure {
  const SendQueueFailure({
    required this.code,
    required this.message,
    required this.isTransient,
  });

  factory SendQueueFailure.fromJson(Map<String, Object?> json) {
    final codeName = json['code'];
    final message = json['message'];
    final isTransient = json['isTransient'];
    final code = SendQueueFailureCode.values
        .where((value) => value.name == codeName)
        .firstOrNull;
    if (code == null || message is! String || isTransient is! bool) {
      throw const ContractError(
        ContractErrorCode.malformedPayload,
        'Malformed send queue failure metadata.',
      );
    }
    return SendQueueFailure(
      code: code,
      message: message,
      isTransient: isTransient,
    );
  }

  final SendQueueFailureCode code;
  final String message;
  final bool isTransient;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code.name,
    'message': message,
    'isTransient': isTransient,
  };
}

class SendQueueRecord {
  const SendQueueRecord({
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.attemptCount,
    this.deviceId,
    this.failure,
    this.nextAttemptAt,
    this.acknowledgementDeadline,
  });

  factory SendQueueRecord.pending({
    required MessageEnvelope message,
    required DateTime createdAt,
    GarminDeviceId? deviceId,
  }) {
    message.validate();
    return SendQueueRecord(
      message: message,
      status: SendQueueStatus.pending,
      createdAt: createdAt.toUtc(),
      updatedAt: createdAt.toUtc(),
      attemptCount: 0,
      deviceId: deviceId,
    );
  }

  factory SendQueueRecord.fromJson(Map<String, Object?> json) {
    final rawFailure = json['failure'];
    final attemptCount = json['attemptCount'];
    if (attemptCount is! int || attemptCount < 0) {
      throw const ContractError(
        ContractErrorCode.malformedPayload,
        'attemptCount must be a non-negative integer.',
      );
    }
    return SendQueueRecord(
      message: MessageEnvelope.fromJson(_map(json['message'], 'message')),
      status: _status(json['status']),
      createdAt: _dateTime(json['createdAt'], 'createdAt'),
      updatedAt: _dateTime(json['updatedAt'], 'updatedAt'),
      attemptCount: attemptCount,
      deviceId: json['deviceId'] is String
          ? GarminDeviceId(json['deviceId']! as String)
          : null,
      failure: rawFailure == null
          ? null
          : SendQueueFailure.fromJson(_map(rawFailure, 'failure')),
      nextAttemptAt: _optionalDateTime(json['nextAttemptAt'], 'nextAttemptAt'),
      acknowledgementDeadline: _optionalDateTime(
        json['acknowledgementDeadline'],
        'acknowledgementDeadline',
      ),
    );
  }

  final MessageEnvelope message;
  final SendQueueStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final GarminDeviceId? deviceId;
  final SendQueueFailure? failure;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final DateTime? acknowledgementDeadline;

  String get id => message.id;
  String? get failureReason => failure?.message;

  Map<String, Object?> toJson() => <String, Object?>{
    'message': message.toJson(),
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'attemptCount': attemptCount,
    if (deviceId != null) 'deviceId': deviceId!.value,
    if (failure != null) 'failure': failure!.toJson(),
    if (nextAttemptAt != null)
      'nextAttemptAt': nextAttemptAt!.toUtc().toIso8601String(),
    if (acknowledgementDeadline != null)
      'acknowledgementDeadline': acknowledgementDeadline!
          .toUtc()
          .toIso8601String(),
  };

  SendQueueRecord copyWith({
    MessageEnvelope? message,
    SendQueueStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    GarminDeviceId? deviceId,
    SendQueueFailure? failure,
    int? attemptCount,
    DateTime? nextAttemptAt,
    DateTime? acknowledgementDeadline,
    bool clearFailure = false,
    bool clearNextAttemptAt = false,
    bool clearAcknowledgementDeadline = false,
  }) {
    return SendQueueRecord(
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      failure: clearFailure ? null : failure ?? this.failure,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: clearNextAttemptAt
          ? null
          : nextAttemptAt ?? this.nextAttemptAt,
      acknowledgementDeadline: clearAcknowledgementDeadline
          ? null
          : acknowledgementDeadline ?? this.acknowledgementDeadline,
    );
  }

  SendQueueRecord applyTransportSuccess(
    DateTime now, {
    DateTime? acknowledgementDeadline,
  }) {
    return copyWith(
      status: message.kind.requiresAcknowledgement
          ? SendQueueStatus.sending
          : SendQueueStatus.sent,
      updatedAt: now.toUtc(),
      acknowledgementDeadline: acknowledgementDeadline,
      clearFailure: true,
      clearNextAttemptAt: true,
      clearAcknowledgementDeadline: !message.kind.requiresAcknowledgement,
    );
  }

  SendQueueRecord applyAcknowledgement(
    WatchAcknowledgement acknowledgement,
    DateTime now,
  ) {
    if (acknowledgement.ackFor != message.id) {
      throw ContractError(
        ContractErrorCode.invalidAcknowledgementReference,
        'Acknowledgement ${acknowledgement.id} references '
        '${acknowledgement.ackFor}, not ${message.id}.',
      );
    }
    if (!message.kind.requiresAcknowledgement ||
        status != SendQueueStatus.sending) {
      return this;
    }

    return switch (acknowledgement.outcome) {
      WatchAcknowledgementOutcome.sent => copyWith(
        status: SendQueueStatus.sent,
        updatedAt: now.toUtc(),
        clearFailure: true,
        clearNextAttemptAt: true,
        clearAcknowledgementDeadline: true,
      ),
      WatchAcknowledgementOutcome.failed => copyWith(
        status: SendQueueStatus.failed,
        updatedAt: now.toUtc(),
        failure: SendQueueFailure(
          code: acknowledgement.status == WatchAcknowledgementStatus.unsupported
              ? SendQueueFailureCode.unsupported
              : SendQueueFailureCode.rejected,
          message: acknowledgement.reason ?? acknowledgement.status.wireName,
          isTransient: false,
        ),
        clearNextAttemptAt: true,
        clearAcknowledgementDeadline: true,
      ),
      WatchAcknowledgementOutcome.retryable => copyWith(
        status: SendQueueStatus.pending,
        updatedAt: now.toUtc(),
        failure: SendQueueFailure(
          code: SendQueueFailureCode.nativeFailure,
          message: acknowledgement.reason ?? 'The watch requested a retry.',
          isTransient: true,
        ),
        clearAcknowledgementDeadline: true,
      ),
    };
  }
}

SendQueueStatus _status(Object? value) {
  if (value is String) {
    for (final status in SendQueueStatus.values) {
      if (status.name == value) return status;
    }
  }
  throw ContractError(
    ContractErrorCode.malformedPayload,
    'Unsupported send queue status: $value',
  );
}

DateTime _dateTime(Object? value, String field) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  throw ContractError(
    ContractErrorCode.malformedPayload,
    '$field must be an ISO 8601 timestamp.',
  );
}

DateTime? _optionalDateTime(Object? value, String field) {
  if (value == null) return null;
  return _dateTime(value, field);
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is Map) return value.cast<String, Object?>();
  throw ContractError(
    ContractErrorCode.malformedPayload,
    '$field must be an object.',
  );
}
