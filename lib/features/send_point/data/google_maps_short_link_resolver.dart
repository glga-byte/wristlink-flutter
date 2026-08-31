import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/point_parse_result.dart';
import 'point_draft_parser.dart';

class GoogleMapsShortLinkException implements Exception {
  const GoogleMapsShortLinkException(this.code, this.message);

  final PointParseErrorCode code;
  final String message;

  @override
  String toString() => 'GoogleMapsShortLinkException($code, $message)';
}

abstract interface class GoogleMapsShortLinkResolver {
  Future<Uri> resolve(Uri shortLink);
}

class HttpGoogleMapsShortLinkResolver implements GoogleMapsShortLinkResolver {
  HttpGoogleMapsShortLinkResolver({
    http.Client? client,
    this.maxRedirects = 5,
    this.requestTimeout = const Duration(seconds: 4),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final int maxRedirects;
  final Duration requestTimeout;

  @override
  Future<Uri> resolve(Uri shortLink) async {
    if (!isGoogleMapsShortLink(shortLink)) {
      throw const GoogleMapsShortLinkException(
        PointParseErrorCode.shortLinkInvalidDestination,
        'Only supported HTTPS Google Maps short links may be resolved.',
      );
    }
    final visited = <Uri>{};
    var current = shortLink;

    try {
      for (
        var redirectCount = 0;
        redirectCount <= maxRedirects;
        redirectCount++
      ) {
        if (!visited.add(current)) {
          throw const GoogleMapsShortLinkException(
            PointParseErrorCode.shortLinkRedirectLoop,
            'The Google Maps short link contains a redirect loop.',
          );
        }

        final request = http.Request('GET', current)
          ..followRedirects = false
          ..headers['Range'] = 'bytes=0-0';
        final response = await _client.send(request).timeout(requestTimeout);
        final subscription = response.stream.listen((_) {});
        await subscription.cancel();

        if (!_isRedirect(response.statusCode)) {
          if (isAllowedGoogleMapsDestination(current)) {
            return current;
          }
          throw GoogleMapsShortLinkException(
            PointParseErrorCode.shortLinkInvalidDestination,
            'Expected a Google Maps redirect, received HTTP ${response.statusCode}.',
          );
        }

        final rawLocation = response.headers['location'];
        if (rawLocation == null || rawLocation.isEmpty) {
          throw const GoogleMapsShortLinkException(
            PointParseErrorCode.shortLinkInvalidDestination,
            'The redirect did not include a destination.',
          );
        }
        final next = current.resolve(rawLocation);
        if (next.scheme.toLowerCase() != 'https') {
          throw const GoogleMapsShortLinkException(
            PointParseErrorCode.shortLinkInvalidDestination,
            'Google Maps redirects must remain on HTTPS.',
          );
        }
        if (isAllowedGoogleMapsDestination(next)) {
          return next;
        }
        if (!isGoogleMapsShortLink(next)) {
          throw const GoogleMapsShortLinkException(
            PointParseErrorCode.shortLinkInvalidDestination,
            'The short link redirected outside the Google Maps allowlist.',
          );
        }
        current = next;
      }
    } on TimeoutException catch (error) {
      throw GoogleMapsShortLinkException(
        PointParseErrorCode.shortLinkTimeout,
        'Timed out while resolving the Google Maps short link: $error',
      );
    } on SocketException catch (error) {
      throw GoogleMapsShortLinkException(
        PointParseErrorCode.shortLinkConnectivity,
        'Could not connect while resolving the Google Maps short link: $error',
      );
    } on http.ClientException catch (error) {
      throw GoogleMapsShortLinkException(
        PointParseErrorCode.shortLinkConnectivity,
        'Could not resolve the Google Maps short link: $error',
      );
    }

    throw GoogleMapsShortLinkException(
      PointParseErrorCode.shortLinkRedirectLimit,
      'The Google Maps short link exceeded $maxRedirects redirects.',
    );
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;
}
