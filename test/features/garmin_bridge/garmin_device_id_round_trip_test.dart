import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_device_discovery_gateway.dart';
import 'package:wristlink_flutter/features/garmin_bridge/garmin_send_gateway.dart';
import 'package:wristlink_flutter/features/payloads/message_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('wristlink/garmin_id_round_trip_test');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'Android numeric and iOS UUID discovery ids round-trip through Dart sends',
    () async {
      final fixtureCases = await _loadFixtureCases();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      final gateway = MethodChannelGarminSendGateway(channel: channel);

      for (final fixtureCase in fixtureCases) {
        final device = mapNativeDevice(fixtureCase.discoveryPayload);

        expect(
          device.id,
          GarminDeviceId(fixtureCase.canonicalDeviceId),
          reason: fixtureCase.platform,
        );
        expect(
          device.metadata.unitId,
          fixtureCase.rawDeviceId,
          reason: fixtureCase.platform,
        );

        await gateway.sendMessage(deviceId: device.id, message: _message);

        final arguments = calls.last.arguments! as Map<Object?, Object?>;
        expect(
          arguments['deviceId'],
          fixtureCase.rawDeviceId,
          reason: fixtureCase.platform,
        );
        expect(arguments['deviceId'], isNot(startsWith('physical:')));
      }

      expect(calls, hasLength(2));
    },
  );
}

Future<List<_RoundTripFixtureCase>> _loadFixtureCases() async {
  final decoded =
      jsonDecode(
            await File(
              'test/fixtures/garmin_device_id_round_trip.json',
            ).readAsString(),
          )
          as Map<String, Object?>;
  return (decoded['cases']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .map(_RoundTripFixtureCase.fromJson)
      .toList(growable: false);
}

final class _RoundTripFixtureCase {
  const _RoundTripFixtureCase({
    required this.platform,
    required this.rawDeviceId,
    required this.canonicalDeviceId,
    required this.discoveryPayload,
  });

  factory _RoundTripFixtureCase.fromJson(Map<String, Object?> json) {
    return _RoundTripFixtureCase(
      platform: json['platform']! as String,
      rawDeviceId: json['rawDeviceId']! as String,
      canonicalDeviceId: json['canonicalDeviceId']! as String,
      discoveryPayload: (json['discoveryPayload']! as Map<String, Object?>)
          .cast<Object?, Object?>(),
    );
  }

  final String platform;
  final String rawDeviceId;
  final String canonicalDeviceId;
  final Map<Object?, Object?> discoveryPayload;
}

final _message = MessageEnvelope(
  id: '01HX7Y8Z9ABCDEFGHJKMNPQS8X',
  kind: MessageKind.point,
  createdAt: DateTime.utc(2026, 8, 26, 12),
  payload: const PointPayload(
    intent: PointIntent.navigate,
    latitude: 52.52,
    longitude: 13.405,
    label: 'Round-trip fixture',
  ),
);
