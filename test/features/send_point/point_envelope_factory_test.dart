import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/payloads/message_contract.dart';
import 'package:wristlink_flutter/features/send_point/application/point_envelope_factory.dart';
import 'package:wristlink_flutter/features/send_point/domain/point_draft.dart';

void main() {
  final createdAt = DateTime.utc(2026, 8, 20, 10);
  const messageId = '01HX7Y8Z9ABCDEFGHJKMNPQS6X';
  const draft = PointDraft(
    latitude: 52.516275,
    longitude: 13.377704,
    label: 'Dropped pin',
    source: PointDraftSource.manualMap,
  );

  test('maps a draft and both intents into a stable v1 point envelope', () {
    final factory = PointEnvelopeFactory(idFactory: (_) => messageId);
    for (final intent in PointIntent.values) {
      final envelope = factory.create(
        draft: draft,
        intent: intent,
        editedLabel: '  Gate  ',
        createdAt: createdAt,
      );
      expect(envelope.id, messageId);
      expect(envelope.createdAt, createdAt);
      expect(envelope.kind, MessageKind.point);
      final payload = envelope.payload as PointPayload;
      expect(payload.intent, intent);
      expect(payload.label, 'Gate');
      expect(payload.latitude, draft.latitude);
    }
  });

  test('rejects empty labels and invalid coordinates before submission', () {
    final factory = PointEnvelopeFactory(idFactory: (_) => messageId);
    expect(
      () => factory.create(
        draft: draft,
        intent: PointIntent.navigate,
        editedLabel: '   ',
        createdAt: createdAt,
      ),
      throwsA(isA<PointDraftValidationException>()),
    );
    expect(
      () => factory.create(
        draft: draft.copyWith(latitude: 100),
        intent: PointIntent.navigate,
        editedLabel: 'Invalid',
        createdAt: createdAt,
      ),
      throwsA(isA<PointDraftValidationException>()),
    );
  });

  test('uses the existing serialized byte-budget error path', () {
    final factory = PointEnvelopeFactory(idFactory: (_) => messageId);
    expect(
      () => factory.create(
        draft: draft,
        intent: PointIntent.saveWaypoint,
        editedLabel: 'x' * v1SerializedMessageBudgetBytes,
        createdAt: createdAt,
      ),
      throwsA(
        isA<ContractError>().having(
          (error) => error.code,
          'code',
          ContractErrorCode.payloadTooLarge,
        ),
      ),
    );
  });
}
