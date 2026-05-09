import 'contract_errors.dart';
import 'message_envelope.dart';

enum WatchAcknowledgementStatus {
  accepted('accepted', WatchAcknowledgementOutcome.sent),
  rejected('rejected', WatchAcknowledgementOutcome.failed),
  unsupported('unsupported', WatchAcknowledgementOutcome.failed),
  retryable('retryable', WatchAcknowledgementOutcome.retryable);

  const WatchAcknowledgementStatus(this.wireName, this.outcome);

  final String wireName;
  final WatchAcknowledgementOutcome outcome;

  static WatchAcknowledgementStatus fromWireName(Object? value) {
    if (value is! String) {
      throw const ContractError(
        ContractErrorCode.malformedPayload,
        'Acknowledgement status must be a string.',
      );
    }

    for (final status in WatchAcknowledgementStatus.values) {
      if (status.wireName == value) {
        return status;
      }
    }

    throw ContractError(
      ContractErrorCode.malformedPayload,
      'Unsupported acknowledgement status: $value',
    );
  }
}

enum WatchAcknowledgementOutcome { sent, failed, retryable }

class WatchAcknowledgement {
  const WatchAcknowledgement({
    required this.id,
    required this.ackFor,
    required this.status,
    required this.receivedAt,
    this.protocolVersion = contractProtocolVersion,
    this.reason,
  });

  factory WatchAcknowledgement.fromJson(Map<String, Object?> json) {
    final version = json['v'];
    if (version != contractProtocolVersion) {
      throw ContractError(
        ContractErrorCode.unsupportedVersion,
        'Unsupported acknowledgement contract version: $version',
      );
    }

    if (json['kind'] != 'ack') {
      throw const ContractError(
        ContractErrorCode.malformedPayload,
        'Acknowledgement kind must be ack.',
      );
    }

    final id = validateUlid(_string(json['id'], 'id'), field: 'id');
    final ackFor = validateUlid(
      _string(json['ackFor'], 'ackFor'),
      field: 'ackFor',
    );
    if (id == ackFor) {
      throw const ContractError(
        ContractErrorCode.invalidAcknowledgementReference,
        'Acknowledgement id must not match ackFor.',
      );
    }

    return WatchAcknowledgement(
      id: id,
      ackFor: ackFor,
      status: WatchAcknowledgementStatus.fromWireName(json['status']),
      receivedAt: _dateTime(json['receivedAt'], 'receivedAt'),
      reason: _optionalString(json['reason'], 'reason'),
    );
  }

  final int protocolVersion;
  final String id;
  final String ackFor;
  final WatchAcknowledgementStatus status;
  final DateTime receivedAt;
  final String? reason;

  WatchAcknowledgementOutcome get outcome => status.outcome;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'v': protocolVersion,
      'id': id,
      'kind': 'ack',
      'ackFor': ackFor,
      'status': status.wireName,
      'receivedAt': receivedAt.toUtc().toIso8601String(),
      if (reason != null) 'reason': reason,
    };
  }
}

String _string(Object? value, String field) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw ContractError(
    ContractErrorCode.malformedPayload,
    '$field must be a non-empty string.',
  );
}

String? _optionalString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  return _string(value, field);
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
