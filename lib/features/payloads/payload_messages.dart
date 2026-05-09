import 'contract_errors.dart';

enum MessageKind {
  point('point', requiresAcknowledgement: true),
  timer('timer', requiresAcknowledgement: true),
  note('note', requiresAcknowledgement: false),
  command('command', requiresAcknowledgement: true);

  const MessageKind(this.wireName, {required this.requiresAcknowledgement});

  final String wireName;
  final bool requiresAcknowledgement;

  static MessageKind fromWireName(Object? value) {
    if (value is! String) {
      throw const ContractError(
        ContractErrorCode.unsupportedKind,
        'Message kind must be a string.',
      );
    }

    for (final kind in MessageKind.values) {
      if (kind.wireName == value) {
        return kind;
      }
    }

    throw ContractError(
      ContractErrorCode.unsupportedKind,
      'Unsupported message kind: $value',
    );
  }
}

abstract interface class ContractPayload {
  MessageKind get kind;

  void validate();

  Map<String, Object?> toJson();
}

class PointPayload implements ContractPayload {
  const PointPayload({
    required this.latitude,
    required this.longitude,
    this.label,
    this.note,
  });

  factory PointPayload.fromJson(Map<String, Object?> json) {
    final latitude = _number(json['lat'], 'lat');
    final longitude = _number(json['lon'], 'lon');
    if (latitude < -90 || latitude > 90) {
      throw const ContractError(
        ContractErrorCode.malformedPayload,
        'Point latitude must be between -90 and 90.',
      );
    }
    if (longitude < -180 || longitude > 180) {
      throw const ContractError(
        ContractErrorCode.malformedPayload,
        'Point longitude must be between -180 and 180.',
      );
    }

    return PointPayload(
      latitude: latitude,
      longitude: longitude,
      label: _optionalString(json['label'], 'label'),
      note: _optionalString(json['note'], 'note'),
    );
  }

  @override
  MessageKind get kind => MessageKind.point;

  final double latitude;
  final double longitude;
  final String? label;
  final String? note;

  @override
  void validate() {
    _validateNumber(latitude, 'lat');
    _validateNumber(longitude, 'lon');
    if (latitude < -90 || latitude > 90) {
      throw const ContractError(
        ContractErrorCode.malformedPayload,
        'Point latitude must be between -90 and 90.',
      );
    }
    if (longitude < -180 || longitude > 180) {
      throw const ContractError(
        ContractErrorCode.malformedPayload,
        'Point longitude must be between -180 and 180.',
      );
    }
    _optionalString(label, 'label');
    _optionalString(note, 'note');
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (label != null) 'label': label,
      'lat': latitude,
      'lon': longitude,
      if (note != null) 'note': note,
    };
  }
}

class TimerPayload implements ContractPayload {
  const TimerPayload({required this.label, required this.duration});

  factory TimerPayload.fromJson(Map<String, Object?> json) {
    final durationSec = _int(json['durationSec'], 'durationSec');
    if (durationSec < 1) {
      throw const ContractError(
        ContractErrorCode.malformedPayload,
        'Timer durationSec must be positive.',
      );
    }

    return TimerPayload(
      label: _requiredString(json['label'], 'label'),
      duration: Duration(seconds: durationSec),
    );
  }

  @override
  MessageKind get kind => MessageKind.timer;

  final String label;
  final Duration duration;

  @override
  void validate() {
    _requiredString(label, 'label');
    if (duration.inSeconds < 1 ||
        duration.inMicroseconds % Duration.microsecondsPerSecond != 0) {
      throw const ContractError(
        ContractErrorCode.malformedPayload,
        'Timer durationSec must be a positive whole-second duration.',
      );
    }
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'label': label, 'durationSec': duration.inSeconds};
  }
}

class NotePayload implements ContractPayload {
  const NotePayload({required this.body, this.title});

  factory NotePayload.fromJson(Map<String, Object?> json) {
    return NotePayload(
      title: _optionalString(json['title'], 'title'),
      body: _requiredString(json['body'], 'body'),
    );
  }

  @override
  MessageKind get kind => MessageKind.note;

  final String body;
  final String? title;

  @override
  void validate() {
    _optionalString(title, 'title');
    _requiredString(body, 'body');
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{if (title != null) 'title': title, 'body': body};
  }
}

class CommandPayload implements ContractPayload {
  const CommandPayload({
    required this.name,
    this.args = const <String, Object?>{},
  });

  factory CommandPayload.fromJson(Map<String, Object?> json) {
    final rawArgs = json['args'];
    return CommandPayload(
      name: _requiredString(json['name'], 'name'),
      args: rawArgs == null ? const <String, Object?>{} : _map(rawArgs, 'args'),
    );
  }

  @override
  MessageKind get kind => MessageKind.command;

  final String name;
  final Map<String, Object?> args;

  @override
  void validate() {
    _requiredString(name, 'name');
    _validateJsonValue(args, 'args');
  }

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'name': name, if (args.isNotEmpty) 'args': args};
  }
}

ContractPayload parsePayload(MessageKind kind, Object? value) {
  final json = _map(value, 'payload');
  return switch (kind) {
    MessageKind.point => PointPayload.fromJson(json),
    MessageKind.timer => TimerPayload.fromJson(json),
    MessageKind.note => NotePayload.fromJson(json),
    MessageKind.command => CommandPayload.fromJson(json),
  };
}

String _requiredString(Object? value, String field) {
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
  return _requiredString(value, field);
}

int _int(Object? value, String field) {
  if (value is int) {
    return value;
  }
  throw ContractError(
    ContractErrorCode.malformedPayload,
    '$field must be an integer.',
  );
}

double _number(Object? value, String field) {
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  throw ContractError(
    ContractErrorCode.malformedPayload,
    '$field must be a number.',
  );
}

void _validateNumber(num value, String field) {
  if (!value.isFinite) {
    throw ContractError(
      ContractErrorCode.malformedPayload,
      '$field must be a finite number.',
    );
  }
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

void _validateJsonValue(Object? value, String field) {
  switch (value) {
    case null || String() || bool():
      return;
    case num():
      if (value.isFinite) {
        return;
      }
    case List<Object?>():
      for (var index = 0; index < value.length; index += 1) {
        _validateJsonValue(value[index], '$field[$index]');
      }
      return;
    case Map<String, Object?>():
      for (final entry in value.entries) {
        _validateJsonValue(entry.value, '$field.${entry.key}');
      }
      return;
  }

  throw ContractError(
    ContractErrorCode.malformedPayload,
    '$field must be JSON-compatible.',
  );
}
