import 'dart:convert';

import 'contract_errors.dart';
import 'payload_messages.dart';

const contractProtocolVersion = 1;
const v1SerializedMessageBudgetBytes = 1024;

final RegExp _ulidPattern = RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$');

class MessageEnvelope {
  const MessageEnvelope({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.payload,
    this.protocolVersion = contractProtocolVersion,
    this.ttl,
  });

  factory MessageEnvelope.fromJson(Map<String, Object?> json) {
    final version = json['v'];
    if (version != contractProtocolVersion) {
      throw ContractError(
        ContractErrorCode.unsupportedVersion,
        'Unsupported message contract version: $version',
      );
    }

    final id = _requiredUlid(json['id'], 'id');
    final kind = MessageKind.fromWireName(json['kind']);
    final createdAt = _dateTime(json['createdAt'], 'createdAt');
    final ttl = _ttl(json['ttlSec']);
    final payload = parsePayload(kind, json['payload']);

    return MessageEnvelope(
      protocolVersion: contractProtocolVersion,
      id: id,
      kind: kind,
      createdAt: createdAt,
      ttl: ttl,
      payload: payload,
    )..validateSize();
  }

  final int protocolVersion;
  final String id;
  final MessageKind kind;
  final DateTime createdAt;
  final Duration? ttl;
  final ContractPayload payload;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'v': protocolVersion,
      'id': id,
      'kind': kind.wireName,
      'createdAt': _formatUtc(createdAt),
      if (ttl != null) 'ttlSec': ttl!.inSeconds,
      'payload': payload.toJson(),
    };
  }

  int get serializedSizeBytes => utf8.encode(jsonEncode(toJson())).length;

  void validateSize() {
    final size = serializedSizeBytes;
    if (size > v1SerializedMessageBudgetBytes) {
      throw ContractError(
        ContractErrorCode.payloadTooLarge,
        'Serialized message is $size bytes; limit is '
        '$v1SerializedMessageBudgetBytes bytes.',
      );
    }
  }
}

String validateUlid(String id, {String field = 'id'}) {
  return _requiredUlid(id, field);
}

String _requiredUlid(Object? value, String field) {
  if (value is String && _ulidPattern.hasMatch(value)) {
    return value;
  }
  throw ContractError(
    ContractErrorCode.malformedPayload,
    '$field must be a 26-character ULID string.',
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

Duration? _ttl(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int && value > 0) {
    return Duration(seconds: value);
  }
  throw const ContractError(
    ContractErrorCode.malformedPayload,
    'ttlSec must be a positive integer when present.',
  );
}

String _formatUtc(DateTime value) {
  return value.toUtc().toIso8601String();
}
