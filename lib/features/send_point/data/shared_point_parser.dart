import '../domain/point_draft.dart';
import '../domain/point_parse_result.dart';
import 'google_maps_short_link_resolver.dart';
import 'point_draft_parser.dart';

class SharedPointParser {
  const SharedPointParser({
    required this.directParser,
    required this.shortLinkResolver,
  });

  final PointDraftParser directParser;
  final GoogleMapsShortLinkResolver shortLinkResolver;

  Future<PointParseResult> parse(String rawContent) async {
    final original = boundSharedContent(rawContent.trim());
    final shortLink = _findShortLink(original);
    if (shortLink == null) {
      return directParser.parse(original);
    }

    try {
      final resolved = await shortLinkResolver.resolve(shortLink);
      final result = directParser.parse(resolved.toString());
      if (result case PointParseSuccess(:final draft)) {
        return PointParseSuccess(
          draft.copyWith(
            label: draft.label == 'Shared point'
                ? _labelAroundShortLink(original, shortLink) ?? draft.label
                : draft.label,
            source: PointDraftSource.googleMapsShare,
            originalText: original,
          ),
        );
      }
      return PointParseFailure(
        code: (result as PointParseFailure).code,
        originalText: original,
        message: result.message,
      );
    } on GoogleMapsShortLinkException catch (error) {
      return PointParseFailure(
        code: error.code,
        originalText: original,
        message: error.message,
      );
    }
  }

  static Uri? _findShortLink(String content) {
    for (final match in RegExp(
      r'https://[^\s<>]+',
      caseSensitive: false,
    ).allMatches(content)) {
      final uri = Uri.tryParse(
        match.group(0)!.replaceFirst(RegExp(r'[).,;]+$'), ''),
      );
      if (uri != null && isGoogleMapsShortLink(uri)) {
        return uri;
      }
    }
    return null;
  }

  static String? _labelAroundShortLink(String original, Uri shortLink) {
    final label = original.replaceFirst(shortLink.toString(), '').trim();
    if (label.isEmpty || label.length > 120) {
      return null;
    }
    return label.replaceAll(RegExp(r'^[\s:–—-]+|[\s:–—-]+$'), '');
  }
}
