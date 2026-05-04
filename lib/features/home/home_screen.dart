import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _workflows = <_WorkflowPlaceholderData>[
    _WorkflowPlaceholderData(
      title: 'Points',
      description: 'Save locations to send to your Garmin watch.',
      icon: Icons.place_outlined,
    ),
    _WorkflowPlaceholderData(
      title: 'Timers',
      description: 'Prepare quick timers for watch-side use.',
      icon: Icons.timer_outlined,
    ),
    _WorkflowPlaceholderData(
      title: 'Notes',
      description: 'Keep short notes ready for your wrist.',
      icon: Icons.note_alt_outlined,
    ),
    _WorkflowPlaceholderData(
      title: 'Send queue',
      description: 'Track pending, sending, sent, and failed commands.',
      icon: Icons.sync_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('WristLink')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'WristLink',
              style: textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send useful data from your phone to Garmin watches.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'Ready for core workflows',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (final workflow in _workflows) ...[
              _WorkflowPlaceholder(data: workflow),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkflowPlaceholder extends StatelessWidget {
  const _WorkflowPlaceholder({required this.data});

  final _WorkflowPlaceholderData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(data.icon, color: colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(data.description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowPlaceholderData {
  const _WorkflowPlaceholderData({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}
