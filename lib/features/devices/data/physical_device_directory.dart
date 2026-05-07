import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../garmin_bridge/garmin_device_discovery_gateway.dart';
import '../domain/device_directory.dart';
import '../domain/garmin_device.dart';
import 'device_send_target_resolution.dart';
import 'device_settings_store.dart';
import 'emulated_device_directory.dart';

class PhysicalDeviceDirectory extends ChangeNotifier
    implements DeviceDirectoryController {
  PhysicalDeviceDirectory({
    required DeviceSettingsStore store,
    GarminDeviceDiscoveryGateway discoveryGateway =
        const UnsupportedGarminDeviceDiscoveryGateway(),
  }) : _store = store,
       _discoveryGateway = discoveryGateway {
    _deviceUpdateSubscription = _discoveryGateway.deviceUpdates.listen(
      _applyNativeDeviceUpdate,
    );
  }

  final DeviceSettingsStore _store;
  final GarminDeviceDiscoveryGateway _discoveryGateway;
  late final StreamSubscription<GarminDevice> _deviceUpdateSubscription;

  GarminDeviceId? _defaultDeviceId;
  List<GarminDevice> _devices = const <GarminDevice>[];
  GarminDiscoveryError? _lastRefreshError;
  DeviceDirectoryEmptyReason? _emptyReason;

  @override
  List<GarminDevice> get devices => List<GarminDevice>.unmodifiable(_devices);

  @override
  GarminDeviceId? get defaultDeviceId => _defaultDeviceId;

  @override
  GarminDiscoveryError? get lastRefreshError => _lastRefreshError;

  @override
  DeviceDirectoryEmptyReason? get emptyReason => _emptyReason;

  Future<void> load() async {
    _defaultDeviceId = await _store.readDefaultDeviceId();
    _devices = _physicalDevicesOnly(await _store.readAuthorizedDevices());
    await _repairLegacyEmulatorDefaultId();
    _recompose();
    notifyListeners();
  }

  @override
  Future<DeviceRefreshResult> refreshDevices() async {
    try {
      final discoveredDevices = _physicalDevicesOnly(
        await _discoveryGateway.discoverDevices(),
      );
      await _store.replaceAuthorizedDevices(discoveredDevices);
      _devices = discoveredDevices;
      await _repairLegacyEmulatorDefaultId();
      _lastRefreshError = null;
      _emptyReason = discoveredDevices.isEmpty
          ? DeviceDirectoryEmptyReason.noAuthorizedDevices
          : null;
      _recompose();
      notifyListeners();
      return DeviceRefreshSuccess(devices);
    } on GarminDiscoveryError catch (error) {
      if (error.code == GarminDiscoveryErrorCode.timeout &&
          _devices.isNotEmpty) {
        _lastRefreshError = null;
        _recompose();
        notifyListeners();
        return DeviceRefreshSuccess(devices);
      }
      _lastRefreshError = error;
      if (_devices.isEmpty) {
        _emptyReason = _emptyReasonForError(error);
      }
      notifyListeners();
      return DeviceRefreshFailure(error);
    } on Object catch (error) {
      final discoveryError = GarminDiscoveryError(
        GarminDiscoveryErrorCode.nativeFailure,
        'Garmin device discovery failed: $error',
      );
      _lastRefreshError = discoveryError;
      if (_devices.isEmpty) {
        _emptyReason = _emptyReasonForError(discoveryError);
      }
      notifyListeners();
      return DeviceRefreshFailure(discoveryError);
    }
  }

  @override
  Future<void> setDefaultDevice(GarminDeviceId id) async {
    if (id == emulatorGarminDeviceId) {
      return;
    }
    _defaultDeviceId = id;
    await _store.writeDefaultDeviceId(id);
    _recompose();
    notifyListeners();
  }

  @override
  SendTargetResolution resolveSendTarget() {
    return resolveDeviceSendTarget(
      devices: devices,
      defaultDeviceId: _defaultDeviceId,
    );
  }

  @override
  void dispose() {
    _deviceUpdateSubscription.cancel();
    super.dispose();
  }

  Future<void> _applyNativeDeviceUpdate(GarminDevice device) async {
    if (device.source != DeviceSource.physical) {
      return;
    }

    final index = _devices.indexWhere((current) {
      return current.id == device.id;
    });
    if (index == -1) {
      return;
    }

    final updatedDevices = List<GarminDevice>.of(_devices);
    updatedDevices[index] = device;
    _devices = updatedDevices;
    await _store.replaceAuthorizedDevices(updatedDevices);
    _recompose();
    notifyListeners();
  }

  Future<void> _repairLegacyEmulatorDefaultId() async {
    if (_defaultDeviceId == emulatorGarminDeviceId) {
      _defaultDeviceId = _devices.isEmpty ? null : _devices.first.id;
      if (_defaultDeviceId != null) {
        await _store.writeDefaultDeviceId(_defaultDeviceId!);
      }
    } else if (_defaultDeviceId == null && _devices.isNotEmpty) {
      _defaultDeviceId = _devices.first.id;
    }
  }

  void _recompose() {
    _devices = _devices
        .map((device) {
          return device.copyWith(isDefault: device.id == _defaultDeviceId);
        })
        .toList(growable: false);
    _emptyReason = _devices.isEmpty
        ? _emptyReason ?? _defaultEmptyReason()
        : null;
  }

  DeviceDirectoryEmptyReason _defaultEmptyReason() {
    return _lastRefreshError == null
        ? DeviceDirectoryEmptyReason.noAuthorizedDevices
        : _emptyReasonForError(_lastRefreshError!);
  }

  DeviceDirectoryEmptyReason _emptyReasonForError(GarminDiscoveryError error) {
    return switch (error.code) {
      GarminDiscoveryErrorCode.unsupportedPlatform =>
        DeviceDirectoryEmptyReason.unsupportedPlatform,
      _ => DeviceDirectoryEmptyReason.noAuthorizedDevices,
    };
  }

  List<GarminDevice> _physicalDevicesOnly(List<GarminDevice> devices) {
    return devices
        .where((device) => device.source == DeviceSource.physical)
        .toList(growable: false);
  }
}
