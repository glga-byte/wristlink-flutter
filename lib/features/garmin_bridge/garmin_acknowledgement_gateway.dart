import 'package:flutter/services.dart';

import '../payloads/message_contract.dart';

abstract interface class GarminAcknowledgementGateway {
  Stream<GarminAcknowledgementEvent> get events;

  Stream<WatchAcknowledgement> get acknowledgements;

  Stream<GarminAcknowledgementDiagnostic> get diagnostics;
}

sealed class GarminAcknowledgementEvent {
  const GarminAcknowledgementEvent();
}

class GarminAcknowledgementReceived extends GarminAcknowledgementEvent {
  const GarminAcknowledgementReceived(this.acknowledgement);

  final WatchAcknowledgement acknowledgement;
}

enum GarminAcknowledgementDiagnosticCode {
  invalidChannelValue,
  invalidMapKey,
  invalidContract,
}

class GarminAcknowledgementDiagnostic extends GarminAcknowledgementEvent {
  const GarminAcknowledgementDiagnostic({
    required this.code,
    required this.message,
    this.contractErrorCode,
  });

  final GarminAcknowledgementDiagnosticCode code;
  final String message;
  final ContractErrorCode? contractErrorCode;
}

class EventChannelGarminAcknowledgementGateway
    extends StreamGarminAcknowledgementGateway {
  EventChannelGarminAcknowledgementGateway({
    EventChannel eventChannel = const EventChannel(
      'wristlink/garmin_acknowledgements',
    ),
  }) : super(eventChannel.receiveBroadcastStream());
}

class StreamGarminAcknowledgementGateway
    implements GarminAcknowledgementGateway {
  StreamGarminAcknowledgementGateway(Stream<Object?> rawEvents)
    : _events = rawEvents
          .map(parseGarminAcknowledgementEvent)
          .asBroadcastStream();

  final Stream<GarminAcknowledgementEvent> _events;

  @override
  Stream<GarminAcknowledgementEvent> get events => _events;

  @override
  late final Stream<WatchAcknowledgement> acknowledgements = _events
      .where((event) => event is GarminAcknowledgementReceived)
      .cast<GarminAcknowledgementReceived>()
      .map((event) => event.acknowledgement);

  @override
  late final Stream<GarminAcknowledgementDiagnostic> diagnostics = _events
      .where((event) => event is GarminAcknowledgementDiagnostic)
      .cast<GarminAcknowledgementDiagnostic>();
}

class UnsupportedGarminAcknowledgementGateway
    implements GarminAcknowledgementGateway {
  const UnsupportedGarminAcknowledgementGateway();

  @override
  Stream<WatchAcknowledgement> get acknowledgements => const Stream.empty();

  @override
  Stream<GarminAcknowledgementDiagnostic> get diagnostics =>
      const Stream.empty();

  @override
  Stream<GarminAcknowledgementEvent> get events => const Stream.empty();
}

GarminAcknowledgementEvent parseGarminAcknowledgementEvent(Object? rawEvent) {
  if (rawEvent is! Map) {
    return GarminAcknowledgementDiagnostic(
      code: GarminAcknowledgementDiagnosticCode.invalidChannelValue,
      message:
          'Garmin acknowledgement channel value must be a map, but received '
          '${rawEvent.runtimeType}.',
    );
  }

  final acknowledgementMap = <String, Object?>{};
  for (final entry in rawEvent.entries) {
    final key = entry.key;
    if (key is! String) {
      return GarminAcknowledgementDiagnostic(
        code: GarminAcknowledgementDiagnosticCode.invalidMapKey,
        message: 'Garmin acknowledgement map keys must be strings.',
      );
    }
    acknowledgementMap[key] = entry.value;
  }

  try {
    return GarminAcknowledgementReceived(
      WatchAcknowledgement.fromJson(acknowledgementMap),
    );
  } on ContractError catch (error) {
    return GarminAcknowledgementDiagnostic(
      code: GarminAcknowledgementDiagnosticCode.invalidContract,
      message: error.message,
      contractErrorCode: error.code,
    );
  }
}
