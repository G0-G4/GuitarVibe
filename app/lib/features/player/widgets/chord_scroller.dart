import 'package:flutter/material.dart';

import '../../../domain/song.dart';

/// Horizontal chord timeline with a fixed playhead.
///
/// Position: `x = playheadX + (event.beat - currentBeat) * pxPerBeat`.
class ChordScroller extends StatelessWidget {
  const ChordScroller({
    super.key,
    required this.events,
    required this.currentBeat,
    this.pxPerBeat = 100,
    this.playheadFraction = 0.28,
  });

  final List<ChordEvent> events;
  final double currentBeat;
  final double pxPerBeat;

  /// Playhead X as a fraction of width (0–1).
  final double playheadFraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final playheadX = width * playheadFraction;

        return ClipRect(
          child: Stack(
            children: [
              // Lane background
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              // Chord cards
              for (final event in events)
                _ChordCard(
                  event: event,
                  currentBeat: currentBeat,
                  playheadX: playheadX,
                  pxPerBeat: pxPerBeat,
                  height: height,
                ),
              // Playhead
              Positioned(
                left: playheadX - 1.5,
                top: 8,
                bottom: 8,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChordCard extends StatelessWidget {
  const _ChordCard({
    required this.event,
    required this.currentBeat,
    required this.playheadX,
    required this.pxPerBeat,
    required this.height,
  });

  final ChordEvent event;
  final double currentBeat;
  final double playheadX;
  final double pxPerBeat;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final left = playheadX + (event.beat - currentBeat) * pxPerBeat;
    final cardWidth =
        (event.durationBeats * pxPerBeat).clamp(56.0, 400.0).toDouble();

    // Cull off-screen
    if (left + cardWidth < -20 || left > MediaQuery.sizeOf(context).width + 20) {
      return const SizedBox.shrink();
    }

    final isCurrent =
        currentBeat >= event.beat && currentBeat < event.endBeat && currentBeat >= 0;
    final isPast = currentBeat >= event.endBeat;

    final bg = isCurrent
        ? scheme.primaryContainer
        : isPast
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.5)
            : scheme.surface;
    final fg = isCurrent
        ? scheme.onPrimaryContainer
        : isPast
            ? scheme.onSurface.withValues(alpha: 0.4)
            : scheme.onSurface;

    return Positioned(
      left: left,
      top: 16,
      width: cardWidth - 8,
      height: height - 32,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrent ? scheme.primary : scheme.outlineVariant,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            event.chord,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: fg,
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
              fontSize: isCurrent ? 32 : 24,
            ),
          ),
        ),
      ),
    );
  }
}
