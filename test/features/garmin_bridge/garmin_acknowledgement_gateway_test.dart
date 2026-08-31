import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_acknowledgement_gateway.dart';
import 'package:wristlink_flutter/features/payloads/message_contract.dart';

void main() {
  test(
    'emits contract-validated acknowledgements on the typed stream',
    () async {
      final rawEvents = StreamController<Object?>();
      final gateway = StreamGarminAcknowledgementGateway(rawEvents.stream);
      final acknowledgements = <WatchAcknowledgement>[];
      final diagnostics = <GarminAcknowledgementDiagnostic>[];
      final acknowledgementSubscription = gateway.acknowledgements.listen(
        acknowledgements.add,
      );
      final diagnosticSubscription = gateway.diagnostics.listen(
        diagnostics.add,
      );

      rawEvents.add(_validAcknowledgement());
      await pumpEventQueue();

      expect(acknowledgements, hasLength(1));
      expect(acknowledgements.single.ackFor, '01HX7Y8Z9ABCDEFGHJKMNPQRSX');
      expect(
        acknowledgements.single.status,
        WatchAcknowledgementStatus.accepted,
      );
      expect(diagnostics, isEmpty);

      await acknowledgementSubscription.cancel();
      await diagnosticSubscription.cancel();
      await rawEvents.close();
    },
  );

  test(
    'routes malformed channel values to diagnostics and keeps parsing',
    () async {
      final rawEvents = StreamController<Object?>();
      final gateway = StreamGarminAcknowledgementGateway(rawEvents.stream);
      final acknowledgements = <WatchAcknowledgement>[];
      final diagnostics = <GarminAcknowledgementDiagnostic>[];
      final acknowledgementSubscription = gateway.acknowledgements.listen(
        acknowledgements.add,
      );
      final diagnosticSubscription = gateway.diagnostics.listen(
        diagnostics.add,
      );

      rawEvents
        ..add('not a map')
        ..add(<Object?, Object?>{1: 'invalid key'})
        ..add(<String, Object?>{
          ..._validAcknowledgement(),
          'status': 'unknown',
        })
        ..add(_validAcknowledgement());
      await pumpEventQueue();

      expect(acknowledgements, hasLength(1));
      expect(
        diagnostics.map((diagnostic) => diagnostic.code),
        <GarminAcknowledgementDiagnosticCode>[
          GarminAcknowledgementDiagnosticCode.invalidChannelValue,
          GarminAcknowledgementDiagnosticCode.invalidMapKey,
          GarminAcknowledgementDiagnosticCode.invalidContract,
        ],
      );
      expect(
        diagnostics.last.contractErrorCode,
        ContractErrorCode.malformedPayload,
      );

      await acknowledgementSubscription.cancel();
      await diagnosticSubscription.cancel();
      await rawEvents.close();
    },
  );

  test('event stream keeps valid and diagnostic events disjoint', () async {
    final events = Stream<Object?>.fromIterable(<Object?>[
      null,
      _validAcknowledgement(),
    ]);
    final gateway = StreamGarminAcknowledgementGateway(events);

    await expectLater(
      gateway.events,
      emitsInOrder(<Object>[
        isA<GarminAcknowledgementDiagnostic>(),
        isA<GarminAcknowledgementReceived>(),
        emitsDone,
      ]),
    );
  });

  test(
    'delivers duplicate raw acknowledgements for later correlation',
    () async {
      final rawEvents = StreamController<Object?>();
      final gateway = StreamGarminAcknowledgementGateway(rawEvents.stream);
      final acknowledgements = <WatchAcknowledgement>[];
      final subscription = gateway.acknowledgements.listen(
        acknowledgements.add,
      );

      rawEvents
        ..add(_validAcknowledgement())
        ..add(_validAcknowledgement());
      await pumpEventQueue();

      expect(acknowledgements, hasLength(2));
      expect(
        acknowledgements.map((acknowledgement) => acknowledgement.id),
        everyElement('01HX7Y8Z9ABCDEFGHJKMNPQS2X'),
      );

      await subscription.cancel();
      await rawEvents.close();
    },
  );
}

Map<String, Object?> _validAcknowledgement() => <String, Object?>{
  'v': 1,
  'id': '01HX7Y8Z9ABCDEFGHJKMNPQS2X',
  'kind': 'ack',
  'ackFor': '01HX7Y8Z9ABCDEFGHJKMNPQRSX',
  'status': 'accepted',
  'receivedAt': '2026-05-09T12:00:05.000Z',
};
