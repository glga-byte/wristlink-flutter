import 'package:flutter/material.dart';

import '../domain/device_directory.dart';
import '../domain/garmin_device.dart';

class DevicesPresentation {
  const DevicesPresentation({
    required this.featuredDevice,
    required this.rows,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.errorMessage,
  });

  final DeviceRowModel? featuredDevice;
  final List<DeviceRowModel> rows;
  final String emptyTitle;
  final String emptyMessage;
  final String? errorMessage;
}

class DeviceRowModel {
  const DeviceRowModel({
    required this.id,
    required this.name,
    required this.detail,
    required this.status,
    required this.statusColor,
    required this.accentColor,
    required this.isDefault,
    required this.source,
  });

  final GarminDeviceId id;
  final String name;
  final String detail;
  final String status;
  final Color statusColor;
  final Color accentColor;
  final bool isDefault;
  final DeviceSource source;
}

DevicesPresentation mapDevicesPresentation({
  required List<GarminDevice> devices,
  GarminDiscoveryError? refreshError,
}) {
  final rows = devices.map(mapDeviceRow).toList(growable: false);
  final featuredCandidates = rows.where((row) {
    return row.isDefault && row.status == 'connected';
  });
  final featured = featuredCandidates.isEmpty ? null : featuredCandidates.first;

  return DevicesPresentation(
    featuredDevice: featured,
    rows: rows.where((row) => row.id != featured?.id).toList(growable: false),
    emptyTitle: 'No Garmin devices',
    emptyMessage: 'Refresh to authorize Garmin Connect IQ devices.',
    errorMessage: refreshError == null
        ? null
        : _discoveryErrorMessage(refreshError),
  );
}

DeviceRowModel mapDeviceRow(GarminDevice device) {
  return DeviceRowModel(
    id: device.id,
    name: device.name,
    detail: _detail(device),
    status: _status(device),
    statusColor: _statusColor(device),
    accentColor: device.accentColor,
    isDefault: device.isDefault,
    source: device.source,
  );
}

String _detail(GarminDevice device) {
  final source = device.source == DeviceSource.emulator ? 'Emulator' : null;
  final reachability = switch (device.reachability) {
    DeviceReachability.reachable => 'Reachable now',
    DeviceReachability.nearby => 'Nearby',
    DeviceReachability.offline => 'Offline',
    DeviceReachability.sending => 'Sending test',
    DeviceReachability.failed => 'Failed test state',
    DeviceReachability.unknown => 'Connection unknown',
  };
  final companion = switch (device.companionInstallState) {
    CompanionInstallState.installed => 'companion installed',
    CompanionInstallState.missing => 'companion missing',
    CompanionInstallState.unknown => 'companion unknown',
  };
  final defaultLabel = device.isDefault ? 'Default watch' : null;
  return [
    source,
    defaultLabel,
    reachability,
    companion,
  ].whereType<String>().join(' · ');
}

String _status(GarminDevice device) {
  return switch (device.readiness) {
    DeviceReadiness.ready => 'connected',
    DeviceReadiness.needsSetup => 'setup',
    DeviceReadiness.testing => switch (device.reachability) {
      DeviceReachability.sending => 'sending',
      DeviceReachability.failed => 'failed',
      _ => 'testing',
    },
    DeviceReadiness.unavailable => 'offline',
  };
}

Color _statusColor(GarminDevice device) {
  return switch (device.readiness) {
    DeviceReadiness.ready => const Color(0xFF2F7D80),
    DeviceReadiness.needsSetup => const Color(0xFFD8444A),
    DeviceReadiness.testing => const Color(0xFF111111),
    DeviceReadiness.unavailable => const Color(0xFF6F6F69),
  };
}

String _discoveryErrorMessage(GarminDiscoveryError error) {
  return switch (error.code) {
    GarminDiscoveryErrorCode.garminConnectMissing =>
      'Garmin Connect is not installed.',
    GarminDiscoveryErrorCode.authorizationCancelled =>
      'Garmin device authorization was cancelled.',
    GarminDiscoveryErrorCode.noAuthorizedDevices =>
      'No authorized Garmin devices were returned.',
    GarminDiscoveryErrorCode.timeout => 'Garmin device discovery timed out.',
    GarminDiscoveryErrorCode.unsupportedPlatform =>
      'Garmin discovery is not available on this platform.',
    GarminDiscoveryErrorCode.sdkUnavailable =>
      'Garmin Connect IQ SDK is unavailable.',
    GarminDiscoveryErrorCode.invalidPayload =>
      'Garmin discovery returned an invalid device payload.',
    GarminDiscoveryErrorCode.nativeFailure => error.message,
  };
}

class ShareConfirmReadiness {
  const ShareConfirmReadiness({
    required this.foundWatchLabel,
    required this.companionInstalledLabel,
    required this.canSend,
  });

  final String foundWatchLabel;
  final String companionInstalledLabel;
  final bool canSend;
}

ShareConfirmReadiness mapShareConfirmReadiness(
  SendTargetResolution resolution,
) {
  return switch (resolution) {
    SendTargetReady(:final device) => ShareConfirmReadiness(
      foundWatchLabel: '${device.name} found',
      companionInstalledLabel: 'Companion app installed',
      canSend: true,
    ),
    SendTargetUnavailable(:final device, :final reason) =>
      ShareConfirmReadiness(
        foundWatchLabel: device == null
            ? 'No default watch found'
            : '${device.name} not ready',
        companionInstalledLabel:
            reason == SendTargetUnavailableReason.companionMissing
            ? 'Companion app missing'
            : 'Companion app not confirmed',
        canSend: false,
      ),
  };
}
