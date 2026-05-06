import 'package:flutter/material.dart';

import '../../devices/data/local_device_directory.dart';
import '../../devices/domain/garmin_device.dart';
import '../domain/emulator_device_settings.dart';

class DeveloperToolsScreen extends StatelessWidget {
  const DeveloperToolsScreen({required this.directory, super.key});

  final LocalDeviceDirectory directory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer Tools')),
      body: AnimatedBuilder(
        animation: directory,
        builder: (context, _) {
          final settings = directory.emulatorSettings;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Emulator device',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Override Garmin discovery for app flows'),
                value: settings.enabled,
                onChanged: (enabled) {
                  directory.updateEmulatorSettings(
                    settings.copyWith(enabled: enabled),
                  );
                },
              ),
              const SizedBox(height: 24),
              const _SectionLabel('REACHABILITY'),
              const SizedBox(height: 10),
              SegmentedButton<DeviceReachability>(
                segments: const [
                  ButtonSegment(
                    value: DeviceReachability.reachable,
                    label: Text('Reachable'),
                    icon: Icon(Icons.wifi_tethering),
                  ),
                  ButtonSegment(
                    value: DeviceReachability.offline,
                    label: Text('Offline'),
                    icon: Icon(Icons.wifi_off),
                  ),
                  ButtonSegment(
                    value: DeviceReachability.sending,
                    label: Text('Sending'),
                    icon: Icon(Icons.sync),
                  ),
                  ButtonSegment(
                    value: DeviceReachability.failed,
                    label: Text('Failed'),
                    icon: Icon(Icons.error_outline),
                  ),
                ],
                selected: {settings.reachability},
                onSelectionChanged: (selected) {
                  directory.updateEmulatorSettings(
                    settings.copyWith(reachability: selected.first),
                  );
                },
              ),
              const SizedBox(height: 28),
              const _SectionLabel('COMPANION APP'),
              const SizedBox(height: 10),
              SegmentedButton<CompanionInstallState>(
                segments: const [
                  ButtonSegment(
                    value: CompanionInstallState.installed,
                    label: Text('Installed'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                  ButtonSegment(
                    value: CompanionInstallState.missing,
                    label: Text('Missing'),
                    icon: Icon(Icons.do_not_disturb_on_outlined),
                  ),
                  ButtonSegment(
                    value: CompanionInstallState.unknown,
                    label: Text('Unknown'),
                    icon: Icon(Icons.help_outline),
                  ),
                ],
                selected: {settings.companionInstallState},
                onSelectionChanged: (selected) {
                  directory.updateEmulatorSettings(
                    settings.copyWith(companionInstallState: selected.first),
                  );
                },
              ),
              const SizedBox(height: 28),
              _CurrentState(settings: settings),
            ],
          );
        },
      ),
    );
  }
}

class _CurrentState extends StatelessWidget {
  const _CurrentState({required this.settings});

  final EmulatorDeviceSettings settings;

  @override
  Widget build(BuildContext context) {
    final enabled = settings.enabled ? 'enabled' : 'disabled';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E2DD)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Emulator is $enabled · ${settings.reachability.name} · ${settings.companionInstallState.name}',
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: const Color(0xFF2F7D80),
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}
