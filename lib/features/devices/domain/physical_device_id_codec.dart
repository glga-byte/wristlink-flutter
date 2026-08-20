import 'garmin_device.dart';

/// Converts between raw native Garmin ids and canonical Dart physical ids.
final class PhysicalDeviceIdCodec {
  const PhysicalDeviceIdCodec();

  static const _prefix = 'physical:';
  static final RegExp _rawIdPattern = RegExp(r'^[A-Za-z0-9._-]+$');

  GarminDeviceId fromRaw(String rawDeviceId) {
    _validateRaw(rawDeviceId);
    return GarminDeviceId('$_prefix$rawDeviceId');
  }

  String toRaw(GarminDeviceId deviceId) {
    final canonicalId = deviceId.value;
    if (!canonicalId.startsWith(_prefix)) {
      throw const PhysicalDeviceIdCodecException(
        'Garmin device id must use the physical namespace.',
      );
    }

    final rawDeviceId = canonicalId.substring(_prefix.length);
    _validateRaw(rawDeviceId);
    return rawDeviceId;
  }

  void _validateRaw(String rawDeviceId) {
    if (rawDeviceId.isEmpty || !_rawIdPattern.hasMatch(rawDeviceId)) {
      throw const PhysicalDeviceIdCodecException(
        'Garmin physical device id contains an invalid raw native id.',
      );
    }
  }
}

final class PhysicalDeviceIdCodecException implements Exception {
  const PhysicalDeviceIdCodecException(this.message);

  final String message;

  @override
  String toString() => 'PhysicalDeviceIdCodecException($message)';
}
