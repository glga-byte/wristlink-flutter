import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';

class WristLinkAppShell extends StatefulWidget {
  const WristLinkAppShell({super.key});

  @override
  State<WristLinkAppShell> createState() => _WristLinkAppShellState();
}

class _WristLinkAppShellState extends State<WristLinkAppShell> {
  var _selectedIndex = 0;

  static const _destinations = <Widget>[
    SendScreen(),
    QueueScreen(),
    DevicesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _destinations),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
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

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  static const _items = [
    _QueueItem(
      color: Color(0xFFFFCF33),
      title: 'Trailhead parking',
      detail: 'Point · retry when watch reconnects',
      status: 'queued',
    ),
    _QueueItem(
      color: Color(0xFF2F7D80),
      title: 'Coffee meet point',
      detail: 'Point · sending to Forerunner 965',
      status: 'sending',
    ),
    _QueueItem(
      color: Color(0xFFD8444A),
      title: 'Home note',
      detail: 'Note · companion app missing',
      status: 'failed',
    ),
    _QueueItem(
      color: Color(0xFF111111),
      title: 'Gym timer',
      detail: 'Timer · delivered if available',
      status: 'delivered',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        children: [
          const _SectionLabel('ALL PROGRESS'),
          const SizedBox(height: 8),
          Text(
            'Queue',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  count: '2',
                  label: 'queued',
                  backgroundColor: Color(0xFFFFCF33),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(count: '7', label: 'sent'),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  count: '1',
                  label: 'failed',
                  foregroundColor: Color(0xFFD8444A),
                  backgroundColor: Color(0xFFFFF7F7),
                  borderColor: Color(0xFFF0B9BC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          for (final item in _items) _QueueListItem(item: item),
        ],
      ),
    );
  }
}

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        children: [
          const _SectionLabel('GARMIN CONNECT IQ'),
          const SizedBox(height: 8),
          Text(
            'Devices',
            style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 22),
          const _FeaturedDevice(),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const _DeviceListItem(
            color: Color(0xFF2F7D80),
            title: 'Fenix 7',
            detail: 'Nearby · companion missing',
            status: 'setup',
            statusColor: Color(0xFFD8444A),
          ),
          const _DeviceListItem(
            color: Color(0xFFD6D6D1),
            title: 'Venu 3',
            detail: 'Offline · last seen yesterday',
            status: 'offline',
            statusColor: Color(0xFF6F6F69),
          ),
          const SizedBox(height: 30),
          const _SectionLabel('BEFORE SENDING'),
          const SizedBox(height: 14),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 7),
                child: _StatusDot(color: Color(0xFF2F7D80), size: 8),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Check companion install per device and use the default reachable watch first.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          const _SettingsRow(
            icon: Icons.watch_outlined,
            title: 'Default watch',
            detail: 'Forerunner 965',
          ),
          const _SettingsRow(
            icon: Icons.sync_outlined,
            title: 'Background sending',
            detail: 'Retry when watch reconnects',
          ),
          const _SettingsRow(
            icon: Icons.code_rounded,
            title: 'Developer Tools',
            detail: 'Emulator device and bridge states',
            iconColor: Color(0xFFFFCF33),
            iconBackgroundColor: Color(0xFF111111),
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

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.count,
    required this.label,
    this.foregroundColor = const Color(0xFF111111),
    this.backgroundColor = const Color(0xFFF7F7F4),
    this.borderColor = const Color(0xFFE2E2DD),
  });

  final String count;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueListItem extends StatelessWidget {
  const _QueueListItem({required this.item});

  final _QueueItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusColor = item.status == 'failed'
        ? const Color(0xFFD8444A)
        : item.status == 'sending'
        ? const Color(0xFF2F7D80)
        : const Color(0xFF111111);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _StatusDot(color: item.color, size: 10),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      item.detail,
                      style: textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6F6F69),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                item.status,
                style: textTheme.labelLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _FeaturedDevice extends StatelessWidget {
  const _FeaturedDevice();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Forerunner 965',
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFCF33),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      'connected',
                      style: textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF111111),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Default watch',
              style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _DarkChip('Companion installed'),
                _DarkChip('Reachable now'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkChip extends StatelessWidget {
  const _DarkChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white38),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _DeviceListItem extends StatelessWidget {
  const _DeviceListItem({
    required this.color,
    required this.title,
    required this.detail,
    required this.status,
    required this.statusColor,
  });

  final Color color;
  final String title;
  final String detail;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SizedBox.square(dimension: 36),
              ),
              const SizedBox(width: 14),
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
              Text(
                status,
                style: textTheme.labelLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
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
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color iconColor;
  final Color iconBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
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
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: SizedBox.square(dimension: size),
    );
  }
}

class _QueueItem {
  const _QueueItem({
    required this.color,
    required this.title,
    required this.detail,
    required this.status,
  });

  final Color color;
  final String title;
  final String detail;
  final String status;
}
