import 'package:flutter/material.dart';

import '../../../domain/calibration.dart';
import '../mic_lab_controller.dart';

class CalibrationCard extends StatelessWidget {
  const CalibrationCard({
    super.key,
    required this.calibration,
    required this.phase,
    required this.progress,
    required this.message,
    required this.error,
    required this.rmsSilence,
    required this.onCalibrateRoom,
    required this.onCalibrateGuitar,
    required this.onReset,
  });

  final CalibrationBundle calibration;
  final CalibrationPhase phase;
  final double progress;
  final String? message;
  final String? error;
  final double rmsSilence;
  final VoidCallback onCalibrateRoom;
  final VoidCallback onCalibrateGuitar;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = phase != CalibrationPhase.idle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Calibration', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Adapt to this room and your playing level. '
              'Helps ignore background noise without missing real chords.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _statusLine(calibration),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gate RMS: ${rmsSilence.toStringAsFixed(3)}'
              '${calibration.noise != null ? ' · noise p95 ${calibration.noise!.rmsP95.toStringAsFixed(3)}' : ''}'
              '${calibration.guitar != null ? ' · guitar ${calibration.guitar!.rmsMedian.toStringAsFixed(3)}' : ''}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (busy) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text(
                message ?? 'Calibrating…',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
            if (message != null && !busy) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onCalibrateRoom,
                  icon: const Icon(Icons.hearing_disabled, size: 18),
                  label: const Text('1. Calibrate room'),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onCalibrateGuitar,
                  icon: const Icon(Icons.music_note, size: 18),
                  label: const Text('2. Calibrate guitar'),
                ),
                TextButton(
                  onPressed: busy || calibration.isEmpty ? null : onReset,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLine(CalibrationBundle c) {
    final room = c.hasNoise ? 'Room: ok' : 'Room: not set';
    final guitar = c.hasGuitar ? 'Guitar: ok' : 'Guitar: not set';
    return '$room · $guitar';
  }
}
