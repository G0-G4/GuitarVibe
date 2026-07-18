import 'package:flutter/material.dart';

import '../../../domain/strum_pattern.dart';

/// Fixed strip showing one cycle of strum strokes with the current step
/// highlighted from the play clock.
class StrumPatternBar extends StatelessWidget {
  const StrumPatternBar({
    super.key,
    required this.pattern,
    required this.currentBeat,
    this.highlightActive = true,
  });

  final StrumPattern pattern;
  final double currentBeat;

  /// When false (e.g. count-in), show the pattern without an active pulse.
  final bool highlightActive;

  @override
  Widget build(BuildContext context) {
    if (pattern.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activeIndex =
        highlightActive && currentBeat >= 0 ? pattern.stepIndexAt(currentBeat) : -1;
    final name = pattern.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (name != null && name.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < pattern.steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _StrumStepChip(
                  token: pattern.steps[i],
                  isActive: i == activeIndex,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Static preview of a pattern (song detail). No clock highlight.
class StrumPatternPreview extends StatelessWidget {
  const StrumPatternPreview({super.key, required this.pattern});

  final StrumPattern pattern;

  @override
  Widget build(BuildContext context) {
    if (pattern.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = pattern.name ?? 'Strum';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final token in pattern.steps)
              _StrumStepChip(token: token, isActive: false, compact: true),
          ],
        ),
      ],
    );
  }
}

class _StrumStepChip extends StatelessWidget {
  const _StrumStepChip({
    required this.token,
    required this.isActive,
    this.compact = false,
  });

  final String token;
  final bool isActive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glyph = StrumPattern.glyphFor(token);
    final isRest = !StrumPattern.isStroke(token);

    final bg = isActive
        ? scheme.primaryContainer
        : scheme.surface.withValues(alpha: isRest ? 0.5 : 1);
    final fg = isActive
        ? scheme.onPrimaryContainer
        : isRest
            ? scheme.onSurface.withValues(alpha: 0.35)
            : scheme.onSurface;

    final size = compact ? 28.0 : 40.0;
    final fontSize = compact ? 18.0 : (isActive ? 26.0 : 22.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? scheme.primary : scheme.outlineVariant,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Text(
        glyph,
        style: theme.textTheme.titleLarge?.copyWith(
          color: fg,
          fontSize: fontSize,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
