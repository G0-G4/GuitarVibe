import 'package:flutter/material.dart';

import '../../../domain/recognition_config.dart';
import '../../../domain/threshold_prefs.dart';

/// Sensitivity + advanced threshold sliders for Mic Lab.
class ThresholdsCard extends StatelessWidget {
  const ThresholdsCard({
    super.key,
    required this.prefs,
    required this.effective,
    required this.onSensitivity,
    required this.onUseAdvanced,
    required this.onRequireYin,
    required this.onAdvancedChanged,
    required this.onReset,
  });

  final ThresholdPrefs prefs;
  final RecognitionConfig effective;
  final ValueChanged<double> onSensitivity;
  final ValueChanged<bool> onUseAdvanced;
  final ValueChanged<bool> onRequireYin;
  final void Function({
    double? chromaMinScore,
    double? chromaMargin,
    double? chromaMinConcentration,
    int? chromaHoldMs,
    double? rmsSilence,
  }) onAdvancedChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Thresholds', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'If the right chord appears in Alternatives but does not activate, '
              'lower sensitivity (slide left) or open Advanced.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Sensitive', style: theme.textTheme.labelSmall),
                Expanded(
                  child: Slider(
                    value: prefs.sensitivity.clamp(0.0, 1.0),
                    onChanged: prefs.useAdvanced ? null : onSensitivity,
                  ),
                ),
                Text('Strict', style: theme.textTheme.labelSmall),
              ],
            ),
            Text(
              'Active: min score ${effective.chromaMinScore.toStringAsFixed(2)} · '
              'margin ${effective.chromaMargin.toStringAsFixed(2)} · '
              'conc ${effective.chromaMinConcentration.toStringAsFixed(2)} · '
              'hold ${effective.chromaHoldMs} ms · '
              'gate ${effective.rmsSilence.toStringAsFixed(3)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hybrid: require pitch lock'),
              subtitle: Text(
                'Off = activate from chroma only (easier for full strums)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              value: prefs.requireYinForHybrid,
              onChanged: onRequireYin,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Advanced thresholds'),
              value: prefs.useAdvanced,
              onChanged: onUseAdvanced,
            ),
            if (prefs.useAdvanced) ...[
              _slider(
                theme,
                label: 'Min score',
                value: effective.chromaMinScore,
                min: 0.30,
                max: 0.70,
                onChanged: (v) => onAdvancedChanged(chromaMinScore: v),
              ),
              _slider(
                theme,
                label: 'Margin (top1−top2)',
                value: effective.chromaMargin,
                min: 0.0,
                max: 0.15,
                onChanged: (v) => onAdvancedChanged(chromaMargin: v),
              ),
              _slider(
                theme,
                label: 'Concentration',
                value: effective.chromaMinConcentration,
                min: 0.25,
                max: 0.60,
                onChanged: (v) => onAdvancedChanged(chromaMinConcentration: v),
              ),
              _slider(
                theme,
                label: 'Hold (ms)',
                value: effective.chromaHoldMs.toDouble(),
                min: 0,
                max: 300,
                divisions: 30,
                onChanged: (v) => onAdvancedChanged(chromaHoldMs: v.round()),
              ),
              _slider(
                theme,
                label: 'RMS gate',
                value: effective.rmsSilence,
                min: 0.005,
                max: 0.06,
                onChanged: (v) => onAdvancedChanged(rmsSilence: v),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onReset,
                child: const Text('Reset thresholds'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(
    ThemeData theme, {
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.labelMedium)),
            Text(
              divisions != null ? value.round().toString() : value.toStringAsFixed(2),
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
