import 'package:flutter/material.dart';

import '../../../domain/lyric_phrases.dart';
import '../../../domain/song.dart';

/// Horizontal lyrics timeline, same beat geometry as [ChordScroller].
///
/// A multi-chord line (D–A–Bm under one lyric) becomes one wide card whose
/// **width = full phrase duration** and whose text is **centered** under that
/// span — like a ChordPro sheet, not glued under the first chord only.
class LyricsScroller extends StatelessWidget {
  const LyricsScroller({
    super.key,
    required this.events,
    required this.currentBeat,
    this.pxPerBeat = 100,
    this.playheadFraction = 0.28,
  });

  final List<ChordEvent> events;
  final double currentBeat;
  final double pxPerBeat;

  /// Playhead X as a fraction of width (0–1). Match [ChordScroller].
  final double playheadFraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phrases = buildLyricPhrases(events);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final playheadX = width * playheadFraction;

        if (phrases.isEmpty) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'No lyrics',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        return ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Positioned(
                left: playheadX - 1,
                top: 6,
                bottom: 6,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              for (final phrase in phrases)
                _LyricCard(
                  phrase: phrase,
                  currentBeat: currentBeat,
                  playheadX: playheadX,
                  pxPerBeat: pxPerBeat,
                  height: height,
                  viewportWidth: width,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LyricCard extends StatelessWidget {
  const _LyricCard({
    required this.phrase,
    required this.currentBeat,
    required this.playheadX,
    required this.pxPerBeat,
    required this.height,
    required this.viewportWidth,
  });

  final LyricPhrase phrase;
  final double currentBeat;
  final double playheadX;
  final double pxPerBeat;
  final double height;
  final double viewportWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Full multi-chord span in pixels (no tight max — width = time).
    final spanPx = phrase.durationBeats * pxPerBeat;
    final cardWidth = spanPx.clamp(80.0, double.infinity).toDouble();
    final left = playheadX + (phrase.beat - currentBeat) * pxPerBeat;

    // Cull only when entirely off-screen.
    if (left + cardWidth < -20 || left > viewportWidth + 20) {
      return const SizedBox.shrink();
    }

    final isCurrent = currentBeat >= phrase.beat &&
        currentBeat < phrase.endBeat &&
        currentBeat >= 0;
    final isPast = currentBeat >= phrase.endBeat;

    final opacity = isCurrent
        ? 1.0
        : isPast
            ? 0.38
            : 0.78;

    final fg = isCurrent
        ? scheme.onPrimaryContainer
        : isPast
            ? scheme.onSurface.withValues(alpha: 0.4)
            : scheme.onSurface;

    final weight = isCurrent ? FontWeight.w700 : FontWeight.w500;
    final size = isCurrent ? 20.0 : 17.0;

    // Full-width bar so the span under D–A–Bm is obvious; text centered
    // under the whole group (not left-glued under D).
    return Positioned(
      left: left,
      top: 10,
      width: cardWidth,
      height: height - 20,
      child: Opacity(
        opacity: opacity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isCurrent
                ? scheme.primaryContainer.withValues(alpha: 0.7)
                : scheme.surface.withValues(alpha: isPast ? 0.25 : 0.45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrent
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.5),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Center(
              child: Text(
                phrase.lyrics,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: weight,
                  fontSize: size,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
