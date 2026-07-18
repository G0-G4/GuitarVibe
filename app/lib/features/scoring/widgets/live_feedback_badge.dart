import 'package:flutter/material.dart';

import '../../../domain/score.dart';

/// Colored chip showing the latest hit grade (Good / Early / Late / Miss).
class LiveFeedbackBadge extends StatelessWidget {
  const LiveFeedbackBadge({
    super.key,
    required this.grade,
    this.streak = 0,
  });

  final HitGrade? grade;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (grade == null) {
      return SizedBox(
        height: 40,
        child: Center(
          child: Text(
            'Listen…',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    final style = _styleFor(grade!, theme.colorScheme);

    return SizedBox(
      height: 40,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: Row(
            key: ValueKey('${grade!.name}-$streak'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: style.fg.withValues(alpha: 0.35)),
                ),
                child: Text(
                  style.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: style.fg,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (streak > 1) ...[
                const SizedBox(width: 8),
                Text(
                  '×$streak',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: style.fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static ({String label, Color bg, Color fg}) _styleFor(
    HitGrade grade,
    ColorScheme scheme,
  ) {
    switch (grade) {
      case HitGrade.good:
        return (
          label: 'GOOD',
          bg: Colors.green.shade100,
          fg: Colors.green.shade900,
        );
      case HitGrade.early:
        return (
          label: 'EARLY',
          bg: Colors.blue.shade100,
          fg: Colors.blue.shade900,
        );
      case HitGrade.late:
        return (
          label: 'LATE',
          bg: Colors.amber.shade100,
          fg: Colors.amber.shade900,
        );
      case HitGrade.miss:
        return (
          label: 'MISS',
          bg: Colors.red.shade100,
          fg: Colors.red.shade900,
        );
    }
  }
}
