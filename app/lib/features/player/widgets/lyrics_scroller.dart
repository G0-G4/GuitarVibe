import 'package:flutter/material.dart';

import '../../../domain/song.dart';

/// Horizontal lyrics timeline, same beat geometry as [ChordScroller].
///
/// Position: `x = playheadX + (event.beat - currentBeat) * pxPerBeat`.
/// Upcoming lines approach from the right; past lines drift left and fade.
///
/// Uses the same [pxPerBeat] / [playheadFraction] as the chord lane so
/// lyric phrases stay time-aligned with their chords.
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

    // Only timed lyric spans; empty-lyric chords don't leave blank cards.
    final lyricEvents =
        events.where((e) => e.lyrics.trim().isNotEmpty).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final playheadX = width * playheadFraction;

        if (lyricEvents.isEmpty) {
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
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              // Soft playhead (aligned with chord lane).
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
              for (final event in lyricEvents)
                _LyricCard(
                  event: event,
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
    required this.event,
    required this.currentBeat,
    required this.playheadX,
    required this.pxPerBeat,
    required this.height,
    required this.viewportWidth,
  });

  final ChordEvent event;
  final double currentBeat;
  final double playheadX;
  final double pxPerBeat;
  final double height;
  final double viewportWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final left = playheadX + (event.beat - currentBeat) * pxPerBeat;
    // Give text room to read; min wider than chord cards for longer phrases.
    final cardWidth =
        (event.durationBeats * pxPerBeat).clamp(120.0, 520.0).toDouble();

    // Cull far off-screen (generous margin for long cards).
    if (left + cardWidth < -40 || left > viewportWidth + 40) {
      return const SizedBox.shrink();
    }

    final isCurrent = currentBeat >= event.beat &&
        currentBeat < event.endBeat &&
        currentBeat >= 0;
    final isPast = currentBeat >= event.endBeat;

    // Fade past lyrics; emphasize current; slightly soft upcoming.
    final opacity = isCurrent
        ? 1.0
        : isPast
            ? 0.35
            : 0.75;

    final fg = isCurrent
        ? scheme.onSurface
        : isPast
            ? scheme.onSurface.withValues(alpha: 0.45)
            : scheme.onSurfaceVariant;

    final weight = isCurrent ? FontWeight.w700 : FontWeight.w500;
    final size = isCurrent ? 22.0 : 18.0;

    return Positioned(
      left: left,
      top: 8,
      width: cardWidth - 12,
      height: height - 16,
      child: Opacity(
        opacity: opacity,
        child: Align(
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isCurrent
                  ? scheme.primaryContainer.withValues(alpha: 0.55)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCurrent ? 10 : 4,
                vertical: 6,
              ),
              child: Text(
                event.lyrics,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
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
