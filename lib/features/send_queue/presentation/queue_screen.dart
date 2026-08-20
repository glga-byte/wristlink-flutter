import 'package:flutter/material.dart';

import '../../payloads/message_contract.dart';
import '../domain/send_queue_record.dart';
import 'send_queue_controller.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({
    required this.controller,
    required this.onRecordTap,
    super.key,
  });

  final SendQueueController controller;
  final ValueChanged<SendQueueRecord> onRecordTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final records = controller.records;
        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              children: [
                Text(
                  'ALL PROGRESS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF2F7D80),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Queue',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        count: records
                            .where(
                              (record) =>
                                  record.status == SendQueueStatus.pending,
                            )
                            .length,
                        label: 'queued',
                        backgroundColor: const Color(0xFFFFCF33),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryTile(
                        count: records
                            .where(
                              (record) => record.status == SendQueueStatus.sent,
                            )
                            .length,
                        label: 'sent',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryTile(
                        count: records
                            .where(
                              (record) =>
                                  record.status == SendQueueStatus.failed,
                            )
                            .length,
                        label: 'failed',
                        foregroundColor: const Color(0xFFD8444A),
                        backgroundColor: const Color(0xFFFFF7F7),
                        borderColor: const Color(0xFFF0B9BC),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                if (!controller.isInitialized)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (controller.storageError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'Queue storage is unavailable: ${controller.storageError!.message}',
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (records.isEmpty)
                  const _EmptyQueue()
                else
                  for (final record in records)
                    _QueueRecordRow(
                      record: record,
                      onTap: () => onRecordTap(record),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 14),
          Text(
            'Nothing in the queue',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Points you submit will appear here.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QueueRecordRow extends StatelessWidget {
  const _QueueRecordRow({required this.record, required this.onTap});

  final SendQueueRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final presentationStatus = queuePresentationStatus(record);
    final label = presentationStatus.name;
    final payload = record.message.payload;
    final title = payload is PointPayload
        ? payload.label ?? 'Point'
        : 'Message';
    final detail = _detail(record);
    final color = switch (presentationStatus) {
      QueuePresentationStatus.queued => const Color(0xFFFFCF33),
      QueuePresentationStatus.sending => const Color(0xFF2F7D80),
      QueuePresentationStatus.sent => const Color(0xFF111111),
      QueuePresentationStatus.failed => const Color(0xFFD8444A),
    };
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          onTap: onTap,
          leading: Icon(Icons.circle, size: 10, color: color),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(detail),
          trailing: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

String _detail(SendQueueRecord record) {
  final failure = record.failure;
  if (failure != null) return 'Point · ${failure.message}';
  return switch (record.status) {
    SendQueueStatus.pending => 'Point · retry when watch reconnects',
    SendQueueStatus.sending => 'Point · waiting for watch acknowledgement',
    SendQueueStatus.sent => 'Point · sent to watch',
    SendQueueStatus.failed => 'Point · delivery failed',
  };
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.count,
    required this.label,
    this.foregroundColor = const Color(0xFF111111),
    this.backgroundColor = const Color(0xFFF7F7F4),
    this.borderColor = const Color(0xFFE2E2DD),
  });

  final int count;
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
              '$count',
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
