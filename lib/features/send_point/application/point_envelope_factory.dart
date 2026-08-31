import 'package:ulid/ulid.dart';

import '../../payloads/message_contract.dart';
import '../domain/point_draft.dart';

typedef PointMessageIdFactory = String Function(DateTime createdAt);

class PointDraftValidationException implements Exception {
  const PointDraftValidationException(this.message);

  final String message;

  @override
  String toString() => 'PointDraftValidationException($message)';
}

class PointEnvelopeFactory {
  PointEnvelopeFactory({PointMessageIdFactory? idFactory})
    : _idFactory =
          idFactory ??
          ((createdAt) => Ulid(
            millis: createdAt.millisecondsSinceEpoch,
          ).toCanonical().toUpperCase());

  final PointMessageIdFactory _idFactory;

  MessageEnvelope create({
    required PointDraft draft,
    required PointIntent intent,
    required String editedLabel,
    required DateTime createdAt,
  }) {
    if (!draft.hasValidCoordinates) {
      throw const PointDraftValidationException(
        'Latitude or longitude is outside the supported range.',
      );
    }
    final label = editedLabel.trim();
    if (label.isEmpty) {
      throw const PointDraftValidationException('Point name cannot be empty.');
    }
    final envelope = MessageEnvelope(
      id: _idFactory(createdAt.toUtc()),
      kind: MessageKind.point,
      createdAt: createdAt.toUtc(),
      payload: PointPayload(
        intent: intent,
        latitude: draft.latitude,
        longitude: draft.longitude,
        label: label,
      ),
    );
    envelope.validate();
    return envelope;
  }
}
