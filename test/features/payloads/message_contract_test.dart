import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/payloads/message_contract.dart';

void main() {
  group('message contract fixtures', () {
    test('valid v1 message fixtures round-trip through Dart models', () {
      for (final fixture in _fixtureFiles(
        'contract/fixtures/v1/messages/valid',
      )) {
        final json = _readJson(fixture);
        final envelope = MessageEnvelope.fromJson(json);

        expect(envelope.toJson(), equals(json), reason: fixture.path);
        expect(
          envelope.serializedSizeBytes,
          lessThanOrEqualTo(v1SerializedMessageBudgetBytes),
          reason: fixture.path,
        );
      }
    });

    test('invalid v1 message fixtures are rejected with typed errors', () {
      final expectations = <String, ContractErrorCode>{
        'malformed_payload.json': ContractErrorCode.malformedPayload,
        'missing_required_field.json': ContractErrorCode.malformedPayload,
        'unknown_kind.json': ContractErrorCode.unsupportedKind,
        'unsupported_version.json': ContractErrorCode.unsupportedVersion,
        'invalid_ulid.json': ContractErrorCode.malformedPayload,
      };

      for (final fixture in _fixtureFiles(
        'contract/fixtures/v1/messages/invalid',
      )) {
        final expectedCode = expectations[fixture.uri.pathSegments.last];
        expect(expectedCode, isNotNull, reason: fixture.path);

        expect(
          () => MessageEnvelope.fromJson(_readJson(fixture)),
          throwsA(
            isA<ContractError>().having(
              (error) => error.code,
              'code',
              expectedCode,
            ),
          ),
          reason: fixture.path,
        );
      }
    });

    test(
      'unsupported protocol versions and unknown payload kinds are typed',
      () {
        expect(
          () => MessageEnvelope.fromJson(
            _readJson(
              File(
                'contract/fixtures/v1/messages/invalid/unsupported_version.json',
              ),
            ),
          ),
          throwsA(
            isA<ContractError>().having(
              (error) => error.code,
              'code',
              ContractErrorCode.unsupportedVersion,
            ),
          ),
        );

        expect(
          () => MessageEnvelope.fromJson(
            _readJson(
              File('contract/fixtures/v1/messages/invalid/unknown_kind.json'),
            ),
          ),
          throwsA(
            isA<ContractError>().having(
              (error) => error.code,
              'code',
              ContractErrorCode.unsupportedKind,
            ),
          ),
        );
      },
    );

    test('optional fields can be present or omitted consistently', () {
      final note = MessageEnvelope.fromJson(
        _readJson(
          File('contract/fixtures/v1/messages/valid/note_minimal.json'),
        ),
      );
      expect(note.ttl, isNull);
      expect(note.toJson()['ttlSec'], isNull);
      expect(
        (note.toJson()['payload']! as Map<String, Object?>)['title'],
        isNull,
      );

      final point = MessageEnvelope.fromJson(
        _readJson(File('contract/fixtures/v1/messages/valid/point.json')),
      );
      expect(point.ttl, const Duration(days: 1));
      expect(
        (point.toJson()['payload']! as Map<String, Object?>)['note'],
        'Meet here',
      );
    });

    test('ULID validation and v1 serialized size budget are enforced', () {
      expect(
        () => validateUlid('not-a-ulid'),
        throwsA(
          isA<ContractError>().having(
            (error) => error.code,
            'code',
            ContractErrorCode.malformedPayload,
          ),
        ),
      );

      final oversized = MessageEnvelope(
        id: '01HX7Y8Z9ABCDEFGHJKMNPQS6X',
        kind: MessageKind.note,
        createdAt: DateTime.utc(2026, 5, 9, 12, 10),
        payload: NotePayload(body: 'x' * v1SerializedMessageBudgetBytes),
      );

      expect(
        oversized.validateSize,
        throwsA(
          isA<ContractError>().having(
            (error) => error.code,
            'code',
            ContractErrorCode.payloadTooLarge,
          ),
        ),
      );
    });

    test('contract metadata matches Dart size budget', () {
      final metadata = _readJson(File('contract/protocol/v1/metadata.json'));
      expect(
        metadata['serializedMessageBudgetBytes'],
        v1SerializedMessageBudgetBytes,
      );
    });
  });

  group('watch acknowledgements', () {
    test('acknowledgement fixtures map to domain outcomes', () {
      final expectations = <String, WatchAcknowledgementOutcome>{
        'accepted.json': WatchAcknowledgementOutcome.sent,
        'rejected.json': WatchAcknowledgementOutcome.failed,
        'unsupported.json': WatchAcknowledgementOutcome.failed,
        'retryable.json': WatchAcknowledgementOutcome.retryable,
      };

      for (final fixture in _fixtureFiles(
        'contract/fixtures/v1/acknowledgements',
      )) {
        final acknowledgement = WatchAcknowledgement.fromJson(
          _readJson(fixture),
        );
        expect(
          acknowledgement.outcome,
          expectations[fixture.uri.pathSegments.last],
          reason: fixture.path,
        );
        expect(acknowledgement.toJson(), equals(_readJson(fixture)));
      }
    });

    test('acknowledgements cannot reference their own id', () {
      expect(
        () => WatchAcknowledgement.fromJson(<String, Object?>{
          'v': 1,
          'id': '01HX7Y8Z9ABCDEFGHJKMNPQS7X',
          'kind': 'ack',
          'ackFor': '01HX7Y8Z9ABCDEFGHJKMNPQS7X',
          'status': 'accepted',
          'receivedAt': '2026-05-09T12:11:00.000Z',
        }),
        throwsA(
          isA<ContractError>().having(
            (error) => error.code,
            'code',
            ContractErrorCode.invalidAcknowledgementReference,
          ),
        ),
      );
    });
  });
}

List<File> _fixtureFiles(String path) {
  return Directory(path)
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

Map<String, Object?> _readJson(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  return (decoded as Map).cast<String, Object?>();
}
