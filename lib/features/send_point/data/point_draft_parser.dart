import '../domain/point_draft.dart';
import '../domain/point_parse_result.dart';

class PointDraftParser {
  const PointDraftParser();

  static final RegExp _uriPattern = RegExp(
    r'(?:https://[^\s<>]+|geo:[^\s<>]+)',
    caseSensitive: false,
  );
  static final RegExp _coordinatePattern = RegExp(
    r'(?<![\d.])([+-]?(?:\d{1,3}(?:\.\d+)?))\s*[,;]\s*([+-]?(?:\d{1,3}(?:\.\d+)?))(?![\d.])',
  );
  static final RegExp _atCoordinatePattern = RegExp(
    r'@([+-]?\d{1,3}(?:\.\d+)?),([+-]?\d{1,3}(?:\.\d+)?)',
  );
  static final RegExp _dataCoordinatePattern = RegExp(
    r'!3d([+-]?(?:\d{1,3}(?:\.\d+)?))!4d([+-]?(?:\d{1,3}(?:\.\d+)?))(?=!|$)',
    caseSensitive: false,
  );

  PointParseResult parse(
    String rawContent, {
    PointDraftSource source = PointDraftSource.googleMapsShare,
  }) {
    final original = boundSharedContent(rawContent.trim());
    if (original.isEmpty) {
      return _failure(PointParseErrorCode.noCoordinates, original);
    }

    PointParseFailure? ambiguousCoordinates;
    PointParseFailure? invalidRange;
    var unsupportedUrl = false;
    for (final match in _uriPattern.allMatches(original)) {
      final rawUri = _trimUriPunctuation(match.group(0)!);
      final uri = Uri.tryParse(rawUri);
      if (uri == null) {
        continue;
      }
      if (uri.scheme.toLowerCase() == 'geo') {
        final result = _parseGeo(uri, original, source);
        if (result is PointParseSuccess) {
          return result;
        }
        if (result is PointParseFailure &&
            result.code == PointParseErrorCode.invalidCoordinateRange) {
          invalidRange = result;
        }
        continue;
      }
      if (uri.scheme.toLowerCase() == 'https') {
        if (isGoogleMapsShortLink(uri)) {
          return _failure(
            PointParseErrorCode.shortLinkInvalidDestination,
            original,
            message: 'The Google Maps short link must be resolved first.',
          );
        }
        if (!isAllowedGoogleMapsDestination(uri)) {
          unsupportedUrl = true;
          continue;
        }
        final result = _parseGoogleMapsUri(uri, original, source);
        if (result is PointParseSuccess) {
          return result;
        }
        if (result is PointParseFailure &&
            result.code == PointParseErrorCode.invalidCoordinateRange) {
          invalidRange = result;
        }
        if (result is PointParseFailure &&
            result.code == PointParseErrorCode.ambiguousCoordinates) {
          ambiguousCoordinates = result;
        }
      }
    }

    if (unsupportedUrl) {
      return _failure(PointParseErrorCode.unsupportedUrl, original);
    }
    final candidates = _coordinatePattern
        .allMatches(original)
        .map(
          (match) =>
              _coordinates(match.group(1), match.group(2), raw: match.group(0)),
        )
        .whereType<_Coordinates>()
        .toList(growable: false);
    final valid = candidates.where((value) => value.isValid).toList();
    if (valid.length == 1 && candidates.length == 1) {
      return PointParseSuccess(
        PointDraft(
          latitude: valid.single.latitude,
          longitude: valid.single.longitude,
          label: _surroundingLabel(original, valid.single) ?? 'Shared point',
          source: source,
          originalText: original,
        ),
      );
    }
    if (candidates.length > 1) {
      return _failure(PointParseErrorCode.ambiguousCoordinates, original);
    }
    if (ambiguousCoordinates != null) {
      return ambiguousCoordinates;
    }
    if (candidates.isNotEmpty || invalidRange != null) {
      return invalidRange ??
          _failure(PointParseErrorCode.invalidCoordinateRange, original);
    }
    return _failure(PointParseErrorCode.noCoordinates, original);
  }

  PointParseResult _parseGeo(
    Uri uri,
    String original,
    PointDraftSource source,
  ) {
    final primary = _coordinatePattern.firstMatch(uri.path);
    var coordinates = primary == null
        ? null
        : _coordinates(
            primary.group(1),
            primary.group(2),
            raw: primary.group(0),
          );
    String? label;
    final query = uri.queryParameters['q'];
    if (query != null) {
      final match = _coordinatePattern.firstMatch(query);
      coordinates ??= match == null
          ? null
          : _coordinates(match.group(1), match.group(2), raw: match.group(0));
      final labelMatch = RegExp(r'\(([^()]+)\)\s*$').firstMatch(query);
      label = labelMatch?.group(1)?.trim();
    }
    return _resultFor(
      coordinates,
      original,
      source,
      label: label ?? 'Shared point',
    );
  }

  PointParseResult _parseGoogleMapsUri(
    Uri uri,
    String original,
    PointDraftSource source,
  ) {
    _Coordinates? coordinates;
    final at = _atCoordinatePattern.firstMatch(uri.toString());
    if (at != null) {
      coordinates = _coordinates(at.group(1), at.group(2), raw: at.group(0));
    }
    for (final key in const ['query', 'q', 'destination', 'll', 'center']) {
      final value = uri.queryParameters[key];
      if (coordinates == null && value != null) {
        final match = _coordinatePattern.firstMatch(value);
        coordinates = match == null
            ? null
            : _coordinates(match.group(1), match.group(2), raw: match.group(0));
      }
    }
    if (coordinates == null) {
      final dataCoordinates = _googleMapsDataCoordinates(uri);
      if (dataCoordinates.length > 1) {
        return _failure(PointParseErrorCode.ambiguousCoordinates, original);
      }
      if (dataCoordinates.isNotEmpty) {
        coordinates = dataCoordinates.single;
      }
    }

    String? label;
    final segments = uri.pathSegments;
    final placeIndex = segments.indexOf('place');
    if (placeIndex >= 0 && placeIndex + 1 < segments.length) {
      label = _normalizeDecodedLabel(segments[placeIndex + 1]);
    }
    label ??= _labelFromQuery(uri.queryParameters['q']);
    label ??= _labelFromQuery(uri.queryParameters['query']);
    return _resultFor(
      coordinates,
      original,
      source,
      label: label ?? 'Shared point',
    );
  }

  static List<_Coordinates> _googleMapsDataCoordinates(Uri uri) {
    final distinct = <_Coordinates>[];
    for (final segment in uri.pathSegments) {
      if (!segment.toLowerCase().startsWith('data=')) {
        continue;
      }
      for (final match in _dataCoordinatePattern.allMatches(segment)) {
        final candidate = _coordinates(
          match.group(1),
          match.group(2),
          raw: match.group(0),
        );
        if (candidate != null &&
            !distinct.any((existing) => existing.samePosition(candidate))) {
          distinct.add(candidate);
        }
      }
    }
    return distinct;
  }

  PointParseResult _resultFor(
    _Coordinates? coordinates,
    String original,
    PointDraftSource source, {
    required String label,
  }) {
    if (coordinates == null) {
      return _failure(PointParseErrorCode.noCoordinates, original);
    }
    if (!coordinates.isValid) {
      return _failure(PointParseErrorCode.invalidCoordinateRange, original);
    }
    return PointParseSuccess(
      PointDraft(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        label: label,
        source: source,
        originalText: original,
      ),
    );
  }

  static _Coordinates? _coordinates(
    String? latitude,
    String? longitude, {
    String? raw,
  }) {
    final lat = double.tryParse(latitude ?? '');
    final lon = double.tryParse(longitude ?? '');
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) {
      return null;
    }
    return _Coordinates(lat, lon, raw: raw ?? '$latitude,$longitude');
  }

  static String? _labelFromQuery(String? value) {
    if (value == null || _coordinatePattern.hasMatch(value)) {
      final match = value == null
          ? null
          : RegExp(r'\(([^()]+)\)\s*$').firstMatch(value);
      return match?.group(1)?.trim();
    }
    return _normalizeDecodedLabel(value);
  }

  static String? _surroundingLabel(String text, _Coordinates coordinates) {
    final withoutCoordinates = text.replaceFirst(coordinates.raw, '').trim();
    final withoutUris = withoutCoordinates.replaceAll(_uriPattern, '').trim();
    if (withoutUris.isEmpty || withoutUris.length > 120) {
      return null;
    }
    return withoutUris.replaceAll(RegExp(r'^[\s:–—-]+|[\s:–—-]+$'), '');
  }

  static String _normalizeDecodedLabel(String value) {
    return value.replaceAll('+', ' ').trim();
  }

  static String _trimUriPunctuation(String value) {
    return value.replaceFirst(RegExp(r'[.,;]+$'), '');
  }

  static PointParseFailure _failure(
    PointParseErrorCode code,
    String original, {
    String? message,
  }) {
    return PointParseFailure(
      code: code,
      originalText: original,
      message:
          message ??
          switch (code) {
            PointParseErrorCode.noCoordinates => 'No coordinates found.',
            PointParseErrorCode.ambiguousCoordinates =>
              'More than one coordinate pair was found.',
            PointParseErrorCode.invalidCoordinateRange =>
              'Coordinates are outside the supported range.',
            PointParseErrorCode.unsupportedUrl => 'This URL is not supported.',
            _ => 'The Google Maps link could not be resolved.',
          },
    );
  }
}

bool isGoogleMapsShortLink(Uri uri) {
  if (uri.scheme.toLowerCase() != 'https') {
    return false;
  }
  final host = uri.host.toLowerCase();
  return host == 'maps.app.goo.gl' ||
      (host == 'goo.gl' && uri.path.startsWith('/maps'));
}

bool isAllowedGoogleMapsDestination(Uri uri) {
  if (uri.scheme.toLowerCase() != 'https') {
    return false;
  }
  final host = uri.host.toLowerCase();
  return (host == 'google.com' || host.endsWith('.google.com')) &&
      (uri.path == '/maps' || uri.path.startsWith('/maps/'));
}

class _Coordinates {
  const _Coordinates(this.latitude, this.longitude, {required this.raw});

  final double latitude;
  final double longitude;
  final String raw;

  bool get isValid =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  bool samePosition(_Coordinates other) =>
      latitude == other.latitude && longitude == other.longitude;
}
