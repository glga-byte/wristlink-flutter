import 'package:flutter/material.dart';

import '../../devices/domain/garmin_device.dart';
import '../domain/emulator_device_controller.dart';
import '../domain/emulator_device_settings.dart';

class DeveloperToolsScreen extends StatelessWidget {
  const DeveloperToolsScreen({required this.directory, super.key});

  final EmulatorDeviceController directory;

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
              _ModeGrid<DeviceReachability>(
                value: settings.reachability,
                options: const [
                  _ModeOption(
                    value: DeviceReachability.reachable,
                    label: 'Reachable',
                    icon: Icons.wifi_tethering,
                  ),
                  _ModeOption(
                    value: DeviceReachability.offline,
                    label: 'Offline',
                    icon: Icons.wifi_off,
                  ),
                  _ModeOption(
                    value: DeviceReachability.sending,
                    label: 'Sending',
                    icon: Icons.sync,
                  ),
                  _ModeOption(
                    value: DeviceReachability.failed,
                    label: 'Failed',
                    icon: Icons.error_outline,
                  ),
                ],
                onChanged: (value) {
                  directory.updateEmulatorSettings(
                    settings.copyWith(enabled: true, reachability: value),
                  );
                },
              ),
              const SizedBox(height: 28),
              const _SectionLabel('COMPANION APP'),
              const SizedBox(height: 10),
              _ModeGrid<CompanionInstallState>(
                value: settings.companionInstallState,
                options: const [
                  _ModeOption(
                    value: CompanionInstallState.installed,
                    label: 'Installed',
                    icon: Icons.check_circle_outline,
                  ),
                  _ModeOption(
                    value: CompanionInstallState.missing,
                    label: 'Missing',
                    icon: Icons.do_not_disturb_on_outlined,
                  ),
                  _ModeOption(
                    value: CompanionInstallState.unknown,
                    label: 'Unknown',
                    icon: Icons.help_outline,
                  ),
                ],
                onChanged: (value) {
                  directory.updateEmulatorSettings(
                    settings.copyWith(
                      enabled: true,
                      companionInstallState: value,
                    ),
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

class _ModeOption<T> {
  const _ModeOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

class _ModeGrid<T> extends StatelessWidget {
  const _ModeGrid({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<_ModeOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    const spacing = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final option in options)
              SizedBox(
                width: itemWidth,
                child: _ModeButton<T>(
                  option: option,
                  selected: option.value == value,
                  onTap: () => onChanged(option.value),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ModeButton<T> extends StatelessWidget {
  const _ModeButton({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ModeOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFF007B74)
        : const Color(0xFF7A8682);
    final foregroundColor = selected
        ? const Color(0xFF173F3B)
        : const Color(0xFF17201E);
    final backgroundColor = selected
        ? const Color(0xFFC4E8E2)
        : Colors.transparent;

    return Tooltip(
      message: option.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: option.label,
        child: Material(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: borderColor),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(option.icon, size: 20, color: foregroundColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_rounded,
                        size: 19,
                        color: foregroundColor,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
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
