import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/payloads/message_contract.dart';
import 'package:wristlink_flutter/features/send_queue/domain/send_queue_record.dart';

void main() {
  test('persists contract-compatible envelopes with explicit statuses', () {
    final createdAt = DateTime.utc(2026, 5, 9, 12);
    final record = SendQueueRecord.pending(
      message: _message(
        MessageKind.point,
        const PointPayload(latitude: 1, longitude: 2),
      ),
      createdAt: createdAt,
      deviceId: const GarminDeviceId('physical:123'),
    ).applyTransportSuccess(createdAt.add(const Duration(seconds: 1)));

    final json = record.toJson();
    expect(json['status'], 'sending');
    expect(json['deviceId'], 'physical:123');
    expect((json['message']! as Map<String, Object?>)['kind'], 'point');

    final parsed = SendQueueRecord.fromJson(json);
    expect(parsed.id, record.id);
    expect(parsed.status, SendQueueStatus.sending);
    expect(parsed.message.toJson(), record.message.toJson());
  });

  test('transport success sends non-acknowledged message kinds to sent', () {
    final now = DateTime.utc(2026, 5, 9, 12);
    final record = SendQueueRecord.pending(
      message: _message(MessageKind.note, const NotePayload(body: 'Hello')),
      createdAt: now,
    ).applyTransportSuccess(now);

    expect(record.status, SendQueueStatus.sent);
  });

  test('acknowledgements transition required-ack messages', () {
    final now = DateTime.utc(2026, 5, 9, 12);
    final sending = SendQueueRecord.pending(
      message: _message(
        MessageKind.timer,
        const TimerPayload(label: 'Tea', duration: Duration(minutes: 3)),
      ),
      createdAt: now,
    ).applyTransportSuccess(now);

    expect(
      sending
          .applyAcknowledgement(
            _ack(WatchAcknowledgementStatus.accepted),
            now.add(const Duration(seconds: 1)),
          )
          .status,
      SendQueueStatus.sent,
    );
    expect(
      sending
          .applyAcknowledgement(
            _ack(WatchAcknowledgementStatus.rejected, reason: 'Bad timer'),
            now.add(const Duration(seconds: 2)),
          )
          .status,
      SendQueueStatus.failed,
    );
    expect(
      sending
          .applyAcknowledgement(
            _ack(WatchAcknowledgementStatus.retryable, reason: 'Busy'),
            now.add(const Duration(seconds: 3)),
          )
          .status,
      SendQueueStatus.pending,
    );
  });

  test('mismatched acknowledgements are rejected', () {
    final now = DateTime.utc(2026, 5, 9, 12);
    final record = SendQueueRecord.pending(
      message: _message(
        MessageKind.command,
        const CommandPayload(name: 'clear'),
      ),
      createdAt: now,
    );

    expect(
      () => record.applyAcknowledgement(
        WatchAcknowledgement(
          id: '01HX7Y8Z9ABCDEFGHJKMNPQS9X',
          ackFor: '01HX7Y8Z9ABCDEFGHJKMNPQS0X',
          status: WatchAcknowledgementStatus.accepted,
          receivedAt: now,
        ),
        now,
      ),
      throwsA(
        isA<ContractError>().having(
          (error) => error.code,
          'code',
          ContractErrorCode.invalidAcknowledgementReference,
        ),
      ),
    );
  });
}

MessageEnvelope _message(MessageKind kind, ContractPayload payload) {
  return MessageEnvelope(
    id: '01HX7Y8Z9ABCDEFGHJKMNPQRSX',
    kind: kind,
    createdAt: DateTime.utc(2026, 5, 9, 12),
    payload: payload,
  );
}

WatchAcknowledgement _ack(WatchAcknowledgementStatus status, {String? reason}) {
  return WatchAcknowledgement(
    id: '01HX7Y8Z9ABCDEFGHJKMNPQS2X',
    ackFor: '01HX7Y8Z9ABCDEFGHJKMNPQRSX',
    status: status,
    receivedAt: DateTime.utc(2026, 5, 9, 12, 0, 5),
    reason: reason,
  );
}
