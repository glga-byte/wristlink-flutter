import 'package:flutter/material.dart';

import '../../devices/domain/device_directory.dart';
import '../../payloads/message_contract.dart';
import '../../send_queue/domain/send_queue_record.dart';
import '../../send_queue/presentation/send_queue_controller.dart';
import '../application/point_queue_actions.dart';

class PointStatusScreen extends StatefulWidget {
  const PointStatusScreen({
    required this.messageId,
    required this.queueController,
    required this.queueActions,
    required this.deviceDirectory,
    required this.onOpenDevices,
    super.key,
    this.onEditPoint,
  });

  final String messageId;
  final SendQueueController queueController;
  final PointQueueActions queueActions;
  final DeviceDirectory deviceDirectory;
  final VoidCallback onOpenDevices;
  final VoidCallback? onEditPoint;

  @override
  State<PointStatusScreen> createState() => _PointStatusScreenState();
}

class _PointStatusScreenState extends State<PointStatusScreen> {
  var _retrying = false;
  String? _retryError;

  Future<void> _retry() async {
    setState(() {
      _retrying = true;
      _retryError = null;
    });
    try {
      await widget.queueActions.retry(widget.messageId);
      await widget.queueController.refresh();
    } on Object catch (error) {
      if (mounted) setState(() => _retryError = 'Retry failed: $error');
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.queueController,
      builder: (context, _) {
        final matches = widget.queueController.records.where(
          (record) => record.id == widget.messageId,
        );
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Point status')),
            body: const Center(
              child: Text('This queue record is unavailable.'),
            ),
          );
        }
        final record = matches.first;
        final model = _statusModel(record, widget.deviceDirectory);
        return Scaffold(
          appBar: AppBar(title: const Text('Point status')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'DELIVERY STATE',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF2F7D80),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    model.title,
                    key: const Key('point-status-title'),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: model.cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.headline,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: model.foregroundColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          model.message,
                          style: TextStyle(color: model.foregroundColor),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: model.accentColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              model.label,
                              style: TextStyle(
                                color: model.accentColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (record.status == SendQueueStatus.failed) ...[
                  const SizedBox(height: 20),
                  if (_showsDeviceSetup(record.failure?.code))
                    FilledButton.icon(
                      onPressed: widget.onOpenDevices,
                      icon: const Icon(Icons.watch_outlined),
                      label: const Text('Open Devices'),
                    )
                  else if (_requiresPointEdit(record.failure?.code) &&
                      widget.onEditPoint != null)
                    FilledButton.icon(
                      onPressed: widget.onEditPoint,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit point'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _retrying ? null : _retry,
                      icon: _retrying
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        record.failure?.code ==
                                SendQueueFailureCode.deliveryOutcomeUnknown
                            ? 'Retry same point'
                            : 'Retry delivery',
                      ),
                    ),
                ],
                if (_retryError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _retryError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to queue'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

bool _showsDeviceSetup(SendQueueFailureCode? code) =>
    code == SendQueueFailureCode.companionMissing;

bool _requiresPointEdit(SendQueueFailureCode? code) =>
    code == SendQueueFailureCode.payloadTooLarge ||
    code == SendQueueFailureCode.payloadInvalid;

class _PointStatusModel {
  const _PointStatusModel({
    required this.title,
    required this.headline,
    required this.message,
    required this.label,
    required this.cardColor,
    required this.foregroundColor,
    required this.accentColor,
  });

  final String title;
  final String headline;
  final String message;
  final String label;
  final Color cardColor;
  final Color foregroundColor;
  final Color accentColor;
}

_PointStatusModel _statusModel(
  SendQueueRecord record,
  DeviceDirectory directory,
) {
  final payload = record.message.payload as PointPayload;
  final pointName = payload.label ?? 'Point';
  final target = directory.devices
      .where((device) => device.id == record.deviceId)
      .firstOrNull;
  final targetName = target?.name ?? 'Selected watch';
  return switch (record.status) {
    SendQueueStatus.pending => _PointStatusModel(
      title: 'Point queued',
      headline: '$targetName is not reachable.',
      message:
          'WristLink saved $pointName and will retry in the background when the watch reconnects.',
      label: 'queued',
      cardColor: const Color(0xFF111111),
      foregroundColor: Colors.white,
      accentColor: const Color(0xFFFFCF33),
    ),
    SendQueueStatus.sending => _PointStatusModel(
      title: 'Sending point',
      headline: 'Waiting for $targetName',
      message: 'The point is being delivered and is waiting for confirmation.',
      label: 'sending',
      cardColor: const Color(0xFFE8F3F1),
      foregroundColor: const Color(0xFF111111),
      accentColor: const Color(0xFF2F7D80),
    ),
    SendQueueStatus.sent => _PointStatusModel(
      title: 'Point sent',
      headline: '$pointName reached $targetName.',
      message: 'The watch accepted this point.',
      label: 'sent',
      cardColor: const Color(0xFFE8F3F1),
      foregroundColor: const Color(0xFF111111),
      accentColor: const Color(0xFF2F7D80),
    ),
    SendQueueStatus.failed => _PointStatusModel(
      title: 'Point failed',
      headline: _failureHeadline(record.failure?.code),
      message: record.failure?.message ?? 'Delivery failed.',
      label: 'failed',
      cardColor: const Color(0xFFFFF7F7),
      foregroundColor: const Color(0xFF111111),
      accentColor: const Color(0xFFD8444A),
    ),
  };
}

String _failureHeadline(SendQueueFailureCode? code) => switch (code) {
  SendQueueFailureCode.deliveryOutcomeUnknown => 'Delivery outcome is unknown.',
  SendQueueFailureCode.payloadTooLarge => 'The point content is too long.',
  SendQueueFailureCode.companionMissing => 'Companion app setup is needed.',
  SendQueueFailureCode.rejected ||
  SendQueueFailureCode.unsupported => 'The watch rejected this point.',
  _ => 'The point could not be delivered.',
};
