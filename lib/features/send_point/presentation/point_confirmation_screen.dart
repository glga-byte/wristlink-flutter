import 'package:flutter/material.dart';

import '../../devices/domain/device_directory.dart';
import '../../devices/domain/garmin_device.dart';
import '../../payloads/message_contract.dart';
import '../../send_queue/data/send_queue_repository.dart';
import '../../send_queue/domain/send_queue_record.dart';
import '../application/point_envelope_factory.dart';
import '../application/point_queue_actions.dart';
import '../domain/point_draft.dart';

class PointConfirmationScreen extends StatefulWidget {
  const PointConfirmationScreen({
    required this.draft,
    required this.deviceDirectory,
    required this.envelopeFactory,
    required this.queueActions,
    required this.onOpenDevices,
    super.key,
    this.clock = _systemClock,
    this.initialIntent = PointIntent.navigate,
  });

  final PointDraft draft;
  final DeviceDirectoryController deviceDirectory;
  final PointEnvelopeFactory envelopeFactory;
  final PointQueueActions queueActions;
  final VoidCallback onOpenDevices;
  final DateTime Function() clock;
  final PointIntent initialIntent;

  @override
  State<PointConfirmationScreen> createState() =>
      _PointConfirmationScreenState();
}

class _PointConfirmationScreenState extends State<PointConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late PointIntent _intent;
  var _submitting = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.label);
    _intent = widget.initialIntent;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit(_PointReadiness readiness) async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final device = readiness.device;
    if (!readiness.canSubmit || device == null) return;

    setState(() {
      _submitting = true;
      _submissionError = null;
    });
    try {
      final createdAt = widget.clock().toUtc();
      final envelope = widget.envelopeFactory.create(
        draft: widget.draft,
        intent: _intent,
        editedLabel: _nameController.text,
        createdAt: createdAt,
      );
      final result = await widget.queueActions.submit(
        SendQueueRecord.pending(
          message: envelope,
          createdAt: createdAt,
          deviceId: device.id,
        ),
      );
      if (mounted) Navigator.of(context).pop(result);
    } on PointDraftValidationException catch (error) {
      _showSubmissionError(error.message);
    } on ContractError catch (error) {
      _showSubmissionError(
        error.code == ContractErrorCode.payloadTooLarge
            ? 'This point is too large to send. Shorten the point name.'
            : error.message,
      );
    } on QueueStorageException catch (error) {
      _showSubmissionError('The point was not queued: ${error.message}');
    } on Object catch (error) {
      _showSubmissionError('The point could not be queued: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSubmissionError(String message) {
    if (!mounted) return;
    setState(() => _submissionError = message);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.deviceDirectory,
      builder: (context, _) {
        final readiness = _mapReadiness(
          widget.deviceDirectory.resolveSendTarget(),
        );
        return Scaffold(
          appBar: AppBar(
            leading: TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            leadingWidth: 84,
            title: Text(_sourceEyebrow(widget.draft.source)),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                children: [
                  Text(
                    'Send this point?',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const Key('point-name-field'),
                    controller: _nameController,
                    enabled: !_submitting,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Point name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a point name.'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _CoordinateCard(draft: widget.draft),
                  const SizedBox(height: 24),
                  Text(
                    'USE AS',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF2F7D80),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: 'Point use',
                    child: SegmentedButton<PointIntent>(
                      segments: const [
                        ButtonSegment(
                          value: PointIntent.navigate,
                          label: Text('Navigate'),
                          icon: Icon(Icons.navigation_outlined),
                        ),
                        ButtonSegment(
                          value: PointIntent.saveWaypoint,
                          label: Text('Save waypoint'),
                          icon: Icon(Icons.bookmark_outline),
                        ),
                      ],
                      selected: {_intent},
                      onSelectionChanged: _submitting
                          ? null
                          : (selection) {
                              setState(() => _intent = selection.single);
                            },
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ReadinessPanel(readiness: readiness),
                  if (!readiness.canSubmit) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: widget.onOpenDevices,
                      icon: const Icon(Icons.watch_outlined),
                      label: Text(readiness.setupActionLabel),
                    ),
                  ],
                  if (_submissionError != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _submissionError!,
                        key: const Key('point-submission-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('point-submit-button'),
                    onPressed: readiness.canSubmit && !_submitting
                        ? () => _submit(readiness)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _submitting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              readiness.willQueue
                                  ? 'Queue point'
                                  : 'Send to watch',
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    readiness.deliveryMessage,
                    key: const Key('point-delivery-message'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6F6F69),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CoordinateCard extends StatelessWidget {
  const _CoordinateCard({required this.draft});

  final PointDraft draft;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F4),
        border: Border.all(color: const Color(0xFFE2E2DD)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'COORDINATES',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF6F6F69),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                const Text(
                  'valid',
                  style: TextStyle(
                    color: Color(0xFF2F7D80),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              '${draft.latitude.toStringAsFixed(4)}, ${draft.longitude.toStringAsFixed(4)}',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text('Source: ${_sourceLabel(draft.source)}'),
          ],
        ),
      ),
    );
  }
}

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({required this.readiness});

  final _PointReadiness readiness;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReadinessRow(
          label: readiness.watchLabel,
          state: readiness.watchState,
          ok: readiness.device != null,
        ),
        const Divider(),
        _ReadinessRow(
          label: readiness.companionLabel,
          state: readiness.companionState,
          ok: readiness.companionReady,
        ),
      ],
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.label,
    required this.state,
    required this.ok,
  });

  final String label;
  final String state;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, $state',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              ok ? Icons.circle : Icons.error_outline,
              size: ok ? 10 : 18,
              color: ok
                  ? const Color(0xFF2F7D80)
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(
              state,
              style: TextStyle(
                color: ok
                    ? const Color(0xFF2F7D80)
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointReadiness {
  const _PointReadiness({
    required this.device,
    required this.canSubmit,
    required this.willQueue,
    required this.companionReady,
    required this.watchLabel,
    required this.watchState,
    required this.companionLabel,
    required this.companionState,
    required this.setupActionLabel,
    required this.deliveryMessage,
  });

  final GarminDevice? device;
  final bool canSubmit;
  final bool willQueue;
  final bool companionReady;
  final String watchLabel;
  final String watchState;
  final String companionLabel;
  final String companionState;
  final String setupActionLabel;
  final String deliveryMessage;
}

_PointReadiness _mapReadiness(SendTargetResolution resolution) {
  if (resolution case SendTargetReady(:final device)) {
    return _PointReadiness(
      device: device,
      canSubmit: true,
      willQueue: false,
      companionReady: true,
      watchLabel: '${device.name} found',
      watchState: 'ready',
      companionLabel: 'Companion app installed',
      companionState: 'ok',
      setupActionLabel: 'Open Devices',
      deliveryMessage: 'WristLink will attempt delivery immediately.',
    );
  }
  final unavailable = resolution as SendTargetUnavailable;
  final device = unavailable.device;
  final companionReady =
      device?.companionInstallState == CompanionInstallState.installed;
  final knownOffline =
      device != null &&
      companionReady &&
      (unavailable.reason == SendTargetUnavailableReason.defaultDeviceOffline ||
          unavailable.reason == SendTargetUnavailableReason.deviceNotReady);
  return _PointReadiness(
    device: device,
    canSubmit: knownOffline,
    willQueue: knownOffline,
    companionReady: companionReady,
    watchLabel: device == null ? 'No default watch found' : device.name,
    watchState: knownOffline ? 'offline' : 'setup needed',
    companionLabel: companionReady
        ? 'Companion app installed'
        : 'Companion app missing or not confirmed',
    companionState: companionReady ? 'ok' : 'setup',
    setupActionLabel: device == null ? 'Choose default watch' : 'Set up watch',
    deliveryMessage: knownOffline
        ? 'The point will stay queued and retry when the watch reconnects.'
        : 'Complete watch setup before creating a queue record.',
  );
}

String _sourceEyebrow(PointDraftSource source) => switch (source) {
  PointDraftSource.manualMap => 'MANUAL POINT',
  PointDraftSource.googleMapsShare => 'SHARED LOCATION',
  PointDraftSource.manualCoordinates => 'MANUAL COORDINATES',
};

String _sourceLabel(PointDraftSource source) => switch (source) {
  PointDraftSource.manualMap => 'Google Maps manual picker',
  PointDraftSource.googleMapsShare => 'Google Maps shared content',
  PointDraftSource.manualCoordinates => 'Manual coordinate recovery',
};

DateTime _systemClock() => DateTime.now().toUtc();
