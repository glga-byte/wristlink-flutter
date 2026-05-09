import '../../devices/domain/garmin_device.dart';
import '../../payloads/message_contract.dart';

enum SendQueueStatus { pending, sending, sent, failed }

class SendQueueRecord {
  const SendQueueRecord({
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.deviceId,
    this.failureReason,
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
      deviceId: deviceId,
    );
  }

  factory SendQueueRecord.fromJson(Map<String, Object?> json) {
    return SendQueueRecord(
      message: MessageEnvelope.fromJson(_map(json['message'], 'message')),
      status: _status(json['status']),
      createdAt: _dateTime(json['createdAt'], 'createdAt'),
      updatedAt: _dateTime(json['updatedAt'], 'updatedAt'),
      deviceId: json['deviceId'] is String
          ? GarminDeviceId(json['deviceId']! as String)
          : null,
      failureReason: json['failureReason'] is String
          ? json['failureReason']! as String
          : null,
    );
  }

  final MessageEnvelope message;
  final SendQueueStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final GarminDeviceId? deviceId;
  final String? failureReason;

  String get id => message.id;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'message': message.toJson(),
      'status': status.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (deviceId != null) 'deviceId': deviceId!.value,
      if (failureReason != null) 'failureReason': failureReason,
    };
  }

  SendQueueRecord copyWith({
    MessageEnvelope? message,
    SendQueueStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    GarminDeviceId? deviceId,
    String? failureReason,
    bool clearFailureReason = false,
  }) {
    return SendQueueRecord(
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      failureReason: clearFailureReason
          ? null
          : failureReason ?? this.failureReason,
    );
  }

  SendQueueRecord applyTransportSuccess(DateTime now) {
    return copyWith(
      status: message.kind.requiresAcknowledgement
          ? SendQueueStatus.sending
          : SendQueueStatus.sent,
      updatedAt: now.toUtc(),
      clearFailureReason: true,
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

    if (!message.kind.requiresAcknowledgement) {
      return this;
    }

    return switch (acknowledgement.outcome) {
      WatchAcknowledgementOutcome.sent => copyWith(
        status: SendQueueStatus.sent,
        updatedAt: now.toUtc(),
        clearFailureReason: true,
      ),
      WatchAcknowledgementOutcome.failed => copyWith(
        status: SendQueueStatus.failed,
        updatedAt: now.toUtc(),
        failureReason:
            acknowledgement.reason ?? acknowledgement.status.wireName,
      ),
      WatchAcknowledgementOutcome.retryable => copyWith(
        status: SendQueueStatus.pending,
        updatedAt: now.toUtc(),
        failureReason: acknowledgement.reason,
      ),
    };
  }
}

SendQueueStatus _status(Object? value) {
  if (value is String) {
    for (final status in SendQueueStatus.values) {
      if (status.name == value) {
        return status;
      }
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
    if (parsed != null) {
      return parsed.toUtc();
    }
  }
  throw ContractError(
    ContractErrorCode.malformedPayload,
    '$field must be an ISO 8601 timestamp.',
  );
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  throw ContractError(
    ContractErrorCode.malformedPayload,
    '$field must be an object.',
  );
}
