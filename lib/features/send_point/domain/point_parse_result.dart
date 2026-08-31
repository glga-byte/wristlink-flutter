import 'point_draft.dart';

const maxSharedContentCharacters = 8192;

enum PointParseErrorCode {
  noCoordinates,
  ambiguousCoordinates,
  invalidCoordinateRange,
  unsupportedUrl,
  shortLinkConnectivity,
  shortLinkTimeout,
  shortLinkRedirectLimit,
  shortLinkRedirectLoop,
  shortLinkInvalidDestination,
}

sealed class PointParseResult {
  const PointParseResult();
}

final class PointParseSuccess extends PointParseResult {
  const PointParseSuccess(this.draft);

  final PointDraft draft;
}

final class PointParseFailure extends PointParseResult {
  const PointParseFailure({
    required this.code,
    required this.originalText,
    required this.message,
  });

  final PointParseErrorCode code;
  final String originalText;
  final String message;
}

String boundSharedContent(String value) {
  if (value.length <= maxSharedContentCharacters) {
    return value;
  }
  return value.substring(0, maxSharedContentCharacters);
}
