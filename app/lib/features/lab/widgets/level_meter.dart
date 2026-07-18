import 'package:flutter/material.dart';

class LevelMeter extends StatelessWidget {
  const LevelMeter({
    super.key,
    required this.rms,
    this.silenceThreshold = 0.015,
  });

  final double rms;
  final double silenceThreshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = (rms / 0.2).clamp(0.0, 1.0);
    final active = rms >= silenceThreshold;
    final color = active ? Colors.green : theme.colorScheme.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Level', style: theme.textTheme.labelLarge),
            const Spacer(),
            Text(
              active ? 'Signal' : 'Silence',
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: level,
            minHeight: 10,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
      ],
    );
  }
}
