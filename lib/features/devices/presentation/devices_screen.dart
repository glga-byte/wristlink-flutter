import 'package:flutter/material.dart';

import '../../devices/data/local_device_directory.dart';
import 'device_presentation_models.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({required this.directory, super.key});

  final LocalDeviceDirectory directory;

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.directory,
      builder: (context, _) {
        final presentation = mapDevicesPresentation(
          devices: widget.directory.devices,
          refreshError: widget.directory.lastRefreshError,
        );

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            children: [
              const _SectionLabel('GARMIN CONNECT IQ'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Devices',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Refresh Garmin devices',
                    onPressed: _refreshing ? null : _refreshDevices,
                    icon: _refreshing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (presentation.errorMessage != null) ...[
                _InlineMessage(
                  icon: Icons.error_outline,
                  message: presentation.errorMessage!,
                ),
                const SizedBox(height: 16),
              ],
              if (widget.directory.devices.isEmpty)
                _EmptyDevices(presentation: presentation)
              else ...[
                if (presentation.featuredDevice != null) ...[
                  _FeaturedDevice(device: presentation.featuredDevice!),
                  const SizedBox(height: 20),
                ],
                const Divider(height: 1),
                for (final row in presentation.rows) _DeviceListItem(row: row),
              ],
              const SizedBox(height: 30),
              const _SectionLabel('BEFORE SENDING'),
              const SizedBox(height: 14),
              const _GuidanceRow(
                text:
                    'Check companion install per device and use the default reachable watch first.',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshDevices() async {
    setState(() {
      _refreshing = true;
    });
    await widget.directory.refreshDevices();
    if (mounted) {
      setState(() {
        _refreshing = false;
      });
    }
  }
}

class DefaultWatchScreen extends StatelessWidget {
  const DefaultWatchScreen({required this.directory, super.key});

  final LocalDeviceDirectory directory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Default watch')),
      body: AnimatedBuilder(
        animation: directory,
        builder: (context, _) {
          if (directory.devices.isEmpty) {
            return const Center(child: Text('No Garmin devices available'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            children: [
              const _SectionLabel('SEND TARGET'),
              const SizedBox(height: 8),
              Text(
                'Choose the watch WristLink sends to first.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              for (final device in directory.devices)
                _DefaultWatchRow(
                  row: mapDeviceRow(device),
                  onTap: () => directory.setDefaultDevice(device.id),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DefaultWatchRow extends StatelessWidget {
  const _DefaultWatchRow({required this.row, required this.onTap});

  final DeviceRowModel row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _DeviceIcon(color: row.accentColor),
          title: Text(
            row.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(row.detail),
          trailing: row.isDefault
              ? const Icon(Icons.check_circle, color: Color(0xFF2F7D80))
              : const Icon(Icons.circle_outlined),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _FeaturedDevice extends StatelessWidget {
  const _FeaturedDevice({required this.device});

  final DeviceRowModel device;

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
                    device.name,
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusPill(label: device.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              device.detail,
              style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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

class _DeviceListItem extends StatelessWidget {
  const _DeviceListItem({required this.row});

  final DeviceRowModel row;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              _DeviceIcon(color: row.accentColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      row.detail,
                      style: textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6F6F69),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                row.status,
                style: textTheme.labelLarge?.copyWith(
                  color: row.statusColor,
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

class _DeviceIcon extends StatelessWidget {
  const _DeviceIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const SizedBox.square(
        dimension: 36,
        child: Icon(Icons.watch, color: Colors.white, size: 18),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFCF33),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.w800,
          ),
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

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices({required this.presentation});

  final DevicesPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E2DD)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              presentation.emptyTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(presentation.emptyMessage),
          ],
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        border: Border.all(color: const Color(0xFFF0B9BC)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFD8444A)),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _GuidanceRow extends StatelessWidget {
  const _GuidanceRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF2F7D80),
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: 8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
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
