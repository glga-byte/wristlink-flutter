import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wristlink_flutter/features/send_point/data/google_maps_short_link_resolver.dart';
import 'package:wristlink_flutter/features/send_point/data/point_draft_parser.dart';
import 'package:wristlink_flutter/features/send_point/data/shared_point_parser.dart';
import 'package:wristlink_flutter/features/send_point/domain/point_parse_result.dart';

void main() {
  const parser = PointDraftParser();

  test('redacted direct fixtures parse deterministically', () {
    final fixtures =
        jsonDecode(
              File(
                'test/fixtures/send_point/direct_cases.json',
              ).readAsStringSync(),
            )
            as List<Object?>;
    for (final raw in fixtures) {
      final fixture = (raw! as Map).cast<String, Object?>();
      final result = parser.parse(fixture['input']! as String);
      expect(
        result,
        isA<PointParseSuccess>(),
        reason: fixture['name'] as String,
      );
      final draft = (result as PointParseSuccess).draft;
      expect(draft.latitude, fixture['lat'], reason: fixture['name'] as String);
      expect(
        draft.longitude,
        fixture['lon'],
        reason: fixture['name'] as String,
      );
      expect(draft.label, fixture['label'], reason: fixture['name'] as String);
    }
  });

  test(
    'rejects locale decimal commas, ambiguity, ranges, and unsupported URLs',
    () {
      expect(
        (parser.parse('52,5200, 13,4050') as PointParseFailure).code,
        PointParseErrorCode.noCoordinates,
      );
      expect(
        (parser.parse('10,20 and 30,40') as PointParseFailure).code,
        PointParseErrorCode.ambiguousCoordinates,
      );
      expect(
        (parser.parse('91, 10') as PointParseFailure).code,
        PointParseErrorCode.invalidCoordinateRange,
      );
      expect(
        (parser.parse('https://example.com/maps/@1,2') as PointParseFailure)
            .code,
        PointParseErrorCode.unsupportedUrl,
      );
      expect(
        (parser.parse('Meet me near the station') as PointParseFailure).code,
        PointParseErrorCode.noCoordinates,
      );
    },
  );

  test('rejects malformed, ambiguous, and out-of-range data coordinates', () {
    expect(
      (parser.parse(
                'https://www.google.com/maps/place/Test/'
                'data=!8m2!3d12.5!4x34.5',
              )
              as PointParseFailure)
          .code,
      PointParseErrorCode.noCoordinates,
    );
    expect(
      (parser.parse(
                'https://www.google.com/maps/place/Test/'
                'data=!8m2!3d12.5!4d34.5!8m2!3d45.5!4d67.5',
              )
              as PointParseFailure)
          .code,
      PointParseErrorCode.ambiguousCoordinates,
    );
    expect(
      (parser.parse(
                'https://www.google.com/maps/place/Test/'
                'data=!8m2!3d91!4d34.5',
              )
              as PointParseFailure)
          .code,
      PointParseErrorCode.invalidCoordinateRange,
    );
    final duplicate = parser.parse(
      'https://www.google.com/maps/place/Test/'
      'data=!8m2!3d12.5!4d34.5!8m2!3d12.500!4d34.500',
    );
    expect(duplicate, isA<PointParseSuccess>());
    expect((duplicate as PointParseSuccess).draft.latitude, 12.5);
    expect(duplicate.draft.longitude, 34.5);
  });

  test('bounds preserved no-coordinate recovery text', () {
    final result = parser.parse('x' * (maxSharedContentCharacters + 50));
    expect(result, isA<PointParseFailure>());
    expect(
      (result as PointParseFailure).originalText,
      hasLength(maxSharedContentCharacters),
    );
  });

  test(
    'short resolver follows allowlisted redirects without reading bodies',
    () async {
      final client = _FakeClient((request) async {
        expect(request.followRedirects, isFalse);
        expect(request.headers['Range'], 'bytes=0-0');
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          302,
          headers: {
            'location': 'https://www.google.com/maps/place/Test/@1.25,2.5,15z',
          },
        );
      });
      final resolver = HttpGoogleMapsShortLinkResolver(client: client);
      final result = await resolver.resolve(
        Uri.parse('https://maps.app.goo.gl/a'),
      );
      expect(result.host, 'www.google.com');
      expect(client.requestCount, 1);
    },
  );

  test(
    'shared parser preserves original text after short-link resolution',
    () async {
      final shared = SharedPointParser(
        directParser: parser,
        shortLinkResolver: _FakeResolver(
          Uri.parse('https://www.google.com/maps/@3.5,4.5,12z'),
        ),
      );
      final result = await shared.parse(
        'Trail start https://maps.app.goo.gl/redacted',
      );
      final draft = (result as PointParseSuccess).draft;
      expect(draft.label, 'Trail start');
      expect(draft.originalText, contains('redacted'));
    },
  );

  test('shared parser handles a selected-place data redirect', () async {
    final shared = SharedPointParser(
      directParser: parser,
      shortLinkResolver: _FakeResolver(
        Uri.parse(
          'https://www.google.com/maps/place/Mountain+View,+CA+94043/'
          'data=!4m6!3m5!1sredacted!7e2!8m2!3d37.4219238!4d-122.0832704'
          '!18m1!1e1',
        ),
      ),
    );
    const original = 'https://maps.app.goo.gl/redacted';

    final result = await shared.parse(original);

    final draft = (result as PointParseSuccess).draft;
    expect(draft.latitude, 37.4219238);
    expect(draft.longitude, -122.0832704);
    expect(draft.label, 'Mountain View, CA 94043');
    expect(draft.originalText, original);
  });

  test(
    'redacted address-only redirect returns typed no-coordinate recovery',
    () async {
      final client = _FakeClient((_) async {
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          302,
          headers: {
            'location':
                'https://www.google.com/maps/place/'
                'Example+Z%C3%BCrich+100%25/'
                'data=!4m2!3m1!1sredacted'
                '!18m1!1e1?entry=gps',
          },
        );
      });
      final shared = SharedPointParser(
        directParser: parser,
        shortLinkResolver: HttpGoogleMapsShortLinkResolver(client: client),
      );
      const original = 'https://maps.app.goo.gl/address-only';

      final result = await shared.parse(original);

      expect(result, isA<PointParseFailure>());
      final failure = result as PointParseFailure;
      expect(failure.code, PointParseErrorCode.noCoordinates);
      expect(failure.message, 'No coordinates found.');
      expect(failure.originalText, original);
    },
  );

  test(
    'resolver rejects loops, unsafe destinations, connectivity, and timeout',
    () async {
      final loopClient = _FakeClient((request) async {
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          302,
          headers: {'location': request.url.toString()},
        );
      });
      await expectLater(
        HttpGoogleMapsShortLinkResolver(
          client: loopClient,
        ).resolve(Uri.parse('https://maps.app.goo.gl/loop')),
        throwsA(
          isA<GoogleMapsShortLinkException>().having(
            (error) => error.code,
            'code',
            PointParseErrorCode.shortLinkRedirectLoop,
          ),
        ),
      );

      final unsafeClient = _FakeClient((_) async {
        return http.StreamedResponse(
          const Stream<List<int>>.empty(),
          302,
          headers: {'location': 'https://example.com/track'},
        );
      });
      await expectLater(
        HttpGoogleMapsShortLinkResolver(
          client: unsafeClient,
        ).resolve(Uri.parse('https://maps.app.goo.gl/unsafe')),
        throwsA(
          isA<GoogleMapsShortLinkException>().having(
            (error) => error.code,
            'code',
            PointParseErrorCode.shortLinkInvalidDestination,
          ),
        ),
      );

      final offlineClient = _FakeClient((_) async {
        throw http.ClientException('offline');
      });
      await expectLater(
        HttpGoogleMapsShortLinkResolver(
          client: offlineClient,
        ).resolve(Uri.parse('https://maps.app.goo.gl/offline')),
        throwsA(
          isA<GoogleMapsShortLinkException>().having(
            (error) => error.code,
            'code',
            PointParseErrorCode.shortLinkConnectivity,
          ),
        ),
      );

      final timeoutClient = _FakeClient(
        (_) => Completer<http.StreamedResponse>().future,
      );
      await expectLater(
        HttpGoogleMapsShortLinkResolver(
          client: timeoutClient,
          requestTimeout: const Duration(milliseconds: 1),
        ).resolve(Uri.parse('https://maps.app.goo.gl/timeout')),
        throwsA(
          isA<GoogleMapsShortLinkException>().having(
            (error) => error.code,
            'code',
            PointParseErrorCode.shortLinkTimeout,
          ),
        ),
      );
    },
  );
}

class _FakeResolver implements GoogleMapsShortLinkResolver {
  const _FakeResolver(this.result);

  final Uri result;

  @override
  Future<Uri> resolve(Uri shortLink) async => result;
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;
  var requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requestCount += 1;
    return handler(request);
  }
}
