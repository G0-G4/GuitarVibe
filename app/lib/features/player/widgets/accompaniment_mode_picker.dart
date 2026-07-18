import 'package:flutter/material.dart';

import '../../../domain/accompaniment_mode.dart';

/// Segmented control: Recording (backing audio) vs Guide (metronome + synth).
///
/// Only meaningful when the song has a backing track available.
class AccompanimentModePicker extends StatelessWidget {
  const AccompanimentModePicker({
    super.key,
    required this.mode,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });

  final AccompanimentMode mode;
  final ValueChanged<AccompanimentMode> onChanged;
  final bool enabled;

  /// Smaller padding for the player transport strip.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Text(
            'Accompaniment',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
        ],
        SegmentedButton<AccompanimentMode>(
          segments: const [
            ButtonSegment<AccompanimentMode>(
              value: AccompanimentMode.audio,
              label: Text('Recording'),
              icon: Icon(Icons.audiotrack, size: 18),
            ),
            ButtonSegment<AccompanimentMode>(
              value: AccompanimentMode.generated,
              label: Text('Guide'),
              icon: Icon(Icons.music_note, size: 18),
            ),
          ],
          selected: {mode},
          onSelectionChanged: !enabled
              ? null
              : (next) {
                  if (next.isEmpty) return;
                  onChanged(next.first);
                },
          showSelectedIcon: false,
          style: compact
              ? ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    theme.textTheme.labelMedium,
                  ),
                )
              : null,
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text(
            mode == AccompanimentMode.audio
                ? 'Play along with the real track (master clock).'
                : 'Metronome + synthetic guitar guide — free tempo practice.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
