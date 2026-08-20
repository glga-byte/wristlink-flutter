import 'package:flutter_test/flutter_test.dart';
import 'package:wristlink_flutter/features/devices/domain/garmin_device.dart';
import 'package:wristlink_flutter/features/devices/domain/physical_device_id_codec.dart';

void main() {
  const codec = PhysicalDeviceIdCodec();

  test('round-trips a raw id through its canonical Dart representation', () {
    final canonicalId = codec.fromRaw('watch-123');

    expect(canonicalId, const GarminDeviceId('physical:watch-123'));
    expect(codec.toRaw(canonicalId), 'watch-123');
  });

  test('rejects empty and malformed raw ids', () {
    for (final rawId in <String>[
      '',
      ' watch-123',
      'watch 123',
      'physical:123',
    ]) {
      expect(
        () => codec.fromRaw(rawId),
        throwsA(isA<PhysicalDeviceIdCodecException>()),
        reason: rawId,
      );
    }
  });

  test('rejects empty, malformed, and non-physical canonical ids', () {
    for (final canonicalId in <String>[
      '',
      'physical:',
      'physical:watch 123',
      'physical:physical:123',
      'emulator:123',
      '123',
    ]) {
      expect(
        () => codec.toRaw(GarminDeviceId(canonicalId)),
        throwsA(isA<PhysicalDeviceIdCodecException>()),
        reason: canonicalId,
      );
    }
  });
}
