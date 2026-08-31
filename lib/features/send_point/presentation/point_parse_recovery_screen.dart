import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/shared_point_parser.dart';
import '../domain/point_draft.dart';
import '../domain/point_parse_result.dart';

class PointParseRecoveryScreen extends StatefulWidget {
  const PointParseRecoveryScreen({
    required this.failure,
    required this.parser,
    super.key,
  });

  final PointParseFailure failure;
  final SharedPointParser parser;

  @override
  State<PointParseRecoveryScreen> createState() =>
      _PointParseRecoveryScreenState();
}

class _PointParseRecoveryScreenState extends State<PointParseRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _nameController = TextEditingController(text: 'Shared point');
  var _showManualEntry = false;
  var _retrying = false;
  String? _retryError;

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.failure.originalText));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Shared text copied.')));
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryError = null;
    });
    final result = await widget.parser.parse(widget.failure.originalText);
    if (!mounted) return;
    switch (result) {
      case PointParseSuccess(:final draft):
        Navigator.of(context).pop(draft);
      case PointParseFailure(:final message):
        setState(() {
          _retrying = false;
          _retryError = message;
        });
    }
  }

  void _useManualCoordinates() {
    if (!_formKey.currentState!.validate()) return;
    final latitude = double.parse(_latitudeController.text.trim());
    final longitude = double.parse(_longitudeController.text.trim());
    Navigator.of(context).pop(
      PointDraft(
        latitude: latitude,
        longitude: longitude,
        label: _nameController.text.trim(),
        source: PointDraftSource.manualCoordinates,
        originalText: widget.failure.originalText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortLinkFailure = switch (widget.failure.code) {
      PointParseErrorCode.shortLinkConnectivity ||
      PointParseErrorCode.shortLinkTimeout ||
      PointParseErrorCode.shortLinkRedirectLimit ||
      PointParseErrorCode.shortLinkRedirectLoop ||
      PointParseErrorCode.shortLinkInvalidDestination => true,
      _ => false,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Shared point recovery')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              shortLinkFailure
                  ? 'Could not open shared link'
                  : 'No coordinates found',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(widget.failure.message),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F7),
                border: Border.all(color: const Color(0xFFF0B9BC)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      widget.failure.originalText,
                      key: const Key('original-shared-text'),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy shared text'),
            ),
            if (shortLinkFailure) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _retrying ? null : _retry,
                icon: _retrying
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Retry link'),
              ),
            ],
            if (_retryError != null) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  _retryError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                setState(() => _showManualEntry = !_showManualEntry);
              },
              child: Text(
                _showManualEntry
                    ? 'Hide manual entry'
                    : 'Enter coordinates manually',
              ),
            ),
            if (_showManualEntry) ...[
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('manual-latitude-field'),
                      controller: _latitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _coordinateError(
                        value,
                        minimum: -90,
                        maximum: 90,
                        field: 'latitude',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('manual-longitude-field'),
                      controller: _longitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _coordinateError(
                        value,
                        minimum: -180,
                        maximum: 180,
                        field: 'longitude',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('manual-name-field'),
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Point name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a point name.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('manual-coordinate-continue'),
                      onPressed: _useManualCoordinates,
                      child: const Text('Continue to confirmation'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _coordinateError(
  String? raw, {
  required double minimum,
  required double maximum,
  required String field,
}) {
  final value = double.tryParse(raw?.trim() ?? '');
  if (value == null || !value.isFinite) {
    return 'Enter a valid $field.';
  }
  if (value < minimum || value > maximum) {
    return '${field[0].toUpperCase()}${field.substring(1)} must be between $minimum and $maximum.';
  }
  return null;
}
