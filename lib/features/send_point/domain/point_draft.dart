enum PointDraftSource { manualMap, googleMapsShare, manualCoordinates }

class PointDraft {
  const PointDraft({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.source,
    this.originalText,
  });

  final double latitude;
  final double longitude;
  final String label;
  final PointDraftSource source;
  final String? originalText;

  bool get hasValidCoordinates =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  PointDraft copyWith({
    double? latitude,
    double? longitude,
    String? label,
    PointDraftSource? source,
    String? originalText,
  }) {
    return PointDraft(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
      source: source ?? this.source,
      originalText: originalText ?? this.originalText,
    );
  }
}
