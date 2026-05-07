import 'package:flutter/material.dart';

import '../devices/domain/device_directory.dart';
import '../devices/presentation/device_presentation_models.dart';

class SendScreen extends StatelessWidget {
  const SendScreen({required this.deviceDirectory, super.key});

  final DeviceDirectoryController deviceDirectory;

  static const _sendActions = <_SendActionData>[
    _SendActionData(
      icon: Icons.add_location_alt_outlined,
      title: 'Manual point',
      description: 'Coordinates, label, optional note',
      color: Color(0xFF2F7D80),
    ),
    _SendActionData(
      icon: Icons.timer_outlined,
      title: 'Timer',
      description: 'Countdown or reminder on the watch',
      color: Color(0xFFFFCF33),
    ),
    _SendActionData(
      icon: Icons.description_outlined,
      title: 'Note',
      description: 'Short text saved on the watch',
      color: Color(0xFF111111),
    ),
    _SendActionData(
      icon: Icons.code_rounded,
      title: 'Command',
      description: 'Reusable watch action or preset',
      color: Color(0xFF2F7D80),
      outlined: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: deviceDirectory,
      builder: (context, _) {
        final textTheme = Theme.of(context).textTheme;
        final readiness = mapShareConfirmReadiness(
          deviceDirectory.resolveSendTarget(),
        );

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            children: [
              Text(
                readiness.canSend
                    ? 'READY ON ${readiness.foundWatchLabel.toUpperCase().replaceAll(' FOUND', '')}'
                    : 'WATCH SETUP NEEDED',
                style: textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF2F7D80),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Send to watch',
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 24),
              _SharePlaceCard(readiness: readiness),
              const SizedBox(height: 24),
              const Divider(height: 1),
              for (final action in _sendActions) _SendActionRow(data: action),
            ],
          ),
        );
      },
    );
  }
}

class _SharePlaceCard extends StatelessWidget {
  const _SharePlaceCard({required this.readiness});

  final ShareConfirmReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFCF33),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share a place from Maps',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Open Google Maps, share a URL or text, then confirm the parsed point before sending.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ReadinessLine(
                    icon: readiness.canSend
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    text: readiness.foundWatchLabel,
                  ),
                  const SizedBox(height: 6),
                  _ReadinessLine(
                    icon: readiness.canSend
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    text: readiness.companionInstalledLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF111111),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 34,
                  child: Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFFFFCF33),
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessLine extends StatelessWidget {
  const _ReadinessLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF111111)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SendActionRow extends StatelessWidget {
  const _SendActionRow({required this.data});

  final _SendActionData data;

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
                  color: data.outlined ? Colors.transparent : data.color,
                  borderRadius: BorderRadius.circular(data.outlined ? 18 : 8),
                  border: data.outlined
                      ? Border.all(color: data.color, width: 3)
                      : null,
                ),
                child: SizedBox.square(
                  dimension: 36,
                  child: Icon(
                    data.icon,
                    color:
                        data.outlined || data.color == const Color(0xFFFFCF33)
                        ? const Color(0xFF111111)
                        : Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      data.description,
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

class _SendActionData {
  const _SendActionData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.outlined = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool outlined;
}
