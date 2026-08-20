import 'package:flutter/material.dart';

import '../features/developer_tools/presentation/developer_tools_screen.dart';
import '../features/devices/domain/device_directory.dart';
import '../features/devices/presentation/devices_screen.dart' as devices;
import '../features/home/home_screen.dart';
import '../features/send_queue/domain/send_queue_record.dart';
import '../features/send_queue/presentation/queue_screen.dart';
import '../features/send_queue/presentation/send_queue_controller.dart';

class WristLinkAppShell extends StatefulWidget {
  const WristLinkAppShell({
    required this.deviceDirectory,
    required this.queueController,
    required this.selectedTab,
    required this.onManualPoint,
    required this.onQueueRecordTap,
    super.key,
  });

  final DeviceDirectoryController deviceDirectory;
  final SendQueueController queueController;
  final ValueNotifier<int> selectedTab;
  final VoidCallback onManualPoint;
  final ValueChanged<SendQueueRecord> onQueueRecordTap;

  @override
  State<WristLinkAppShell> createState() => _WristLinkAppShellState();
}

class _WristLinkAppShellState extends State<WristLinkAppShell> {
  @override
  void initState() {
    super.initState();
    widget.selectedTab.addListener(_handleSelectedTabChanged);
  }

  @override
  void didUpdateWidget(covariant WristLinkAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTab != widget.selectedTab) {
      oldWidget.selectedTab.removeListener(_handleSelectedTabChanged);
      widget.selectedTab.addListener(_handleSelectedTabChanged);
    }
  }

  @override
  void dispose() {
    widget.selectedTab.removeListener(_handleSelectedTabChanged);
    super.dispose();
  }

  void _handleSelectedTabChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: widget.selectedTab.value,
        children: [
          SendScreen(
            deviceDirectory: widget.deviceDirectory,
            onManualPoint: widget.onManualPoint,
          ),
          QueueScreen(
            controller: widget.queueController,
            onRecordTap: widget.onQueueRecordTap,
          ),
          devices.DevicesScreen(directory: widget.deviceDirectory),
          SettingsScreen(deviceDirectory: widget.deviceDirectory),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.selectedTab.value,
        onDestinationSelected: (index) {
          widget.selectedTab.value = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.send_outlined),
            selectedIcon: Icon(Icons.send_rounded),
            label: 'Send',
          ),
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted_rounded),
            label: 'Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.watch_outlined),
            selectedIcon: Icon(Icons.watch),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.deviceDirectory, super.key});

  final DeviceDirectoryController deviceDirectory;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        children: [
          const _SectionLabel('WRISTLINK'),
          const SizedBox(height: 8),
          Text(
            'Settings',
            style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: deviceDirectory,
            builder: (context, _) {
              final defaultDevice = deviceDirectory.devices
                  .where((device) => device.isDefault)
                  .firstOrNull;
              return _SettingsRow(
                icon: Icons.watch_outlined,
                title: 'Default watch',
                detail: defaultDevice?.name ?? 'Choose target watch',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => devices.DefaultWatchScreen(
                        directory: deviceDirectory,
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const _SettingsRow(
            icon: Icons.sync_outlined,
            title: 'Background sending',
            detail: 'Retry when watch reconnects',
          ),
          _SettingsRow(
            icon: Icons.code_rounded,
            title: 'Developer Tools',
            detail: 'Emulator device and bridge states',
            iconColor: Color(0xFFFFCF33),
            iconBackgroundColor: Color(0xFF111111),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DeveloperToolsScreen(),
                ),
              );
            },
          ),
          const _SettingsRow(
            icon: Icons.info_outline,
            title: 'About WristLink',
            detail: 'Flutter companion app',
          ),
        ],
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.iconColor = const Color(0xFF2F7D80),
    this.iconBackgroundColor = const Color(0xFFF7F7F4),
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color iconColor;
  final Color iconBackgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(icon, color: iconColor),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        detail,
                        style: textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6F6F69),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
