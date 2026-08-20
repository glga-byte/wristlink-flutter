import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/point_draft.dart';

class PointMapCoordinate {
  const PointMapCoordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  String get formatted =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
}

class PointMapViewportController extends ChangeNotifier {
  PointMapCoordinate? _requestedTarget;

  PointMapCoordinate? get requestedTarget => _requestedTarget;

  void moveTo(PointMapCoordinate target) {
    _requestedTarget = target;
    notifyListeners();
  }
}

typedef PointMapViewBuilder =
    Widget Function(
      BuildContext context,
      PointMapCoordinate initialTarget,
      PointMapViewportController viewportController,
      ValueChanged<PointMapCoordinate> onCameraChanged,
    );

abstract interface class CurrentLocationGateway {
  Future<PointMapCoordinate> currentLocation();
}

class GeolocatorCurrentLocationGateway implements CurrentLocationGateway {
  const GeolocatorCurrentLocationGateway();

  @override
  Future<PointMapCoordinate> currentLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationAccessException(
        'Location permission was denied. You can still choose a point manually.',
      );
    }
    final position = await Geolocator.getCurrentPosition();
    return PointMapCoordinate(position.latitude, position.longitude);
  }
}

class LocationAccessException implements Exception {
  const LocationAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ManualPointPickerScreen extends StatefulWidget {
  const ManualPointPickerScreen({
    super.key,
    this.initialTarget = const PointMapCoordinate(47.3769, 8.5417),
    this.mapViewBuilder = buildGooglePointMap,
    this.currentLocationGateway = const GeolocatorCurrentLocationGateway(),
  });

  final PointMapCoordinate initialTarget;
  final PointMapViewBuilder mapViewBuilder;
  final CurrentLocationGateway currentLocationGateway;

  @override
  State<ManualPointPickerScreen> createState() =>
      _ManualPointPickerScreenState();
}

class _ManualPointPickerScreenState extends State<ManualPointPickerScreen> {
  late PointMapCoordinate _selected;
  late final PointMapViewportController _viewportController;
  var _locating = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialTarget;
    _viewportController = PointMapViewportController();
  }

  @override
  void dispose() {
    _viewportController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final target = await widget.currentLocationGateway.currentLocation();
      if (!mounted) return;
      setState(() => _selected = target);
      _viewportController.moveTo(target);
    } on Object catch (error) {
      if (!mounted) return;
      final message = error is LocationAccessException
          ? error.message
          : 'Current location is unavailable. You can still pan the map.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _accept() {
    Navigator.of(context).pop(
      PointDraft(
        latitude: _selected.latitude,
        longitude: _selected.longitude,
        label: 'Dropped pin',
        source: PointDraftSource.manualMap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useCupertino = defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              label: 'Map for choosing a point. Pan, zoom, or tap to move it.',
              child: widget.mapViewBuilder(
                context,
                widget.initialTarget,
                _viewportController,
                (coordinate) {
                  if (mounted) setState(() => _selected = coordinate);
                },
              ),
            ),
          ),
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 52),
                child: Icon(
                  Icons.location_on,
                  semanticLabel: 'Selected point pin',
                  size: 54,
                  color: Color(0xFFFFCF33),
                  shadows: [Shadow(blurRadius: 1, color: Color(0xFF111111))],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FloatingActionButton.small(
                  heroTag: 'current-location',
                  tooltip: 'Use current location',
                  onPressed: _locating ? null : _useCurrentLocation,
                  child: _locating
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'SELECTED POINT',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: const Color(0xFF2F7D80),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Dropped pin',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _selected.formatted,
                        key: const Key('selected-point-coordinates'),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 14),
                      const Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: Color(0xFF2F7D80),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text('Source: Google Maps manual picker'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: useCupertino
                                ? CupertinoButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Cancel'),
                                  )
                                : OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Cancel'),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: useCupertino
                                ? CupertinoButton.filled(
                                    onPressed: _accept,
                                    child: const Text('Use this point'),
                                  )
                                : FilledButton(
                                    onPressed: _accept,
                                    child: const Text('Use this point'),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget buildGooglePointMap(
  BuildContext context,
  PointMapCoordinate initialTarget,
  PointMapViewportController viewportController,
  ValueChanged<PointMapCoordinate> onCameraChanged,
) {
  return _GooglePointMap(
    initialTarget: initialTarget,
    viewportController: viewportController,
    onCameraChanged: onCameraChanged,
  );
}

class _GooglePointMap extends StatefulWidget {
  const _GooglePointMap({
    required this.initialTarget,
    required this.viewportController,
    required this.onCameraChanged,
  });

  final PointMapCoordinate initialTarget;
  final PointMapViewportController viewportController;
  final ValueChanged<PointMapCoordinate> onCameraChanged;

  @override
  State<_GooglePointMap> createState() => _GooglePointMapState();
}

class _GooglePointMapState extends State<_GooglePointMap> {
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    widget.viewportController.addListener(_moveToRequestedTarget);
  }

  @override
  void didUpdateWidget(covariant _GooglePointMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewportController != widget.viewportController) {
      oldWidget.viewportController.removeListener(_moveToRequestedTarget);
      widget.viewportController.addListener(_moveToRequestedTarget);
    }
  }

  @override
  void dispose() {
    widget.viewportController.removeListener(_moveToRequestedTarget);
    _controller?.dispose();
    super.dispose();
  }

  void _moveToRequestedTarget() {
    final target = widget.viewportController.requestedTarget;
    final controller = _controller;
    if (target == null || controller == null) return;
    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLng(LatLng(target.latitude, target.longitude)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          widget.initialTarget.latitude,
          widget.initialTarget.longitude,
        ),
        zoom: 15,
      ),
      compassEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      onMapCreated: (controller) {
        _controller = controller;
        _moveToRequestedTarget();
      },
      onCameraMove: (position) {
        widget.onCameraChanged(
          PointMapCoordinate(
            position.target.latitude,
            position.target.longitude,
          ),
        );
      },
      onTap: (target) {
        unawaited(_controller?.animateCamera(CameraUpdate.newLatLng(target)));
      },
    );
  }
}
