import 'package:flutter/material.dart';

import '../../../domain/song.dart';

/// Horizontal chord timeline with a fixed playhead.
///
/// Position: `x = playheadX + (event.beat - currentBeat) * pxPerBeat`.
///
/// When [onSeek] is set, the user can scrub:
/// - **Drag** horizontally (timeline follows the finger; drag right → earlier).
/// - **Tap** to bring the beat under the finger to the playhead.
class ChordScroller extends StatefulWidget {
  const ChordScroller({
    super.key,
    required this.events,
    required this.currentBeat,
    this.totalBeats = 0,
    this.onSeek,
    this.pxPerBeat = 100,
    this.playheadFraction = 0.28,
  });

  final List<ChordEvent> events;
  final double currentBeat;

  /// Song length in beats; used to clamp scrub targets.
  final double totalBeats;

  /// When non-null, drag/tap seek is enabled.
  final ValueChanged<double>? onSeek;

  final double pxPerBeat;

  /// Playhead X as a fraction of width (0–1).
  final double playheadFraction;

  @override
  State<ChordScroller> createState() => _ChordScrollerState();
}

class _ChordScrollerState extends State<ChordScroller> {
  /// Preview beat while dragging (null when not scrubbing).
  double? _previewBeat;

  double? _dragStartBeat;
  double? _dragStartX;
  bool _didDrag = false;

  double get _displayBeat => _previewBeat ?? widget.currentBeat;

  double get _maxBeat {
    final t = widget.totalBeats;
    if (t > 0) return t;
    if (widget.events.isEmpty) return 0;
    return widget.events
        .map((e) => e.endBeat)
        .reduce((a, b) => a > b ? a : b);
  }

  double _clampBeat(double beat) =>
      beat.clamp(0.0, _maxBeat > 0 ? _maxBeat : 0.0).toDouble();

  void _commitSeek(double beat) {
    final onSeek = widget.onSeek;
    if (onSeek == null) return;
    onSeek(_clampBeat(beat));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canSeek = widget.onSeek != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final playheadX = width * widget.playheadFraction;
        final displayBeat = _displayBeat;

        Widget lane = ClipRect(
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
              for (final event in widget.events)
                _ChordCard(
                  event: event,
                  currentBeat: displayBeat,
                  playheadX: playheadX,
                  pxPerBeat: widget.pxPerBeat,
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

        if (!canSeek) return lane;

        return MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              // Absolute: beat under the tap moves to the playhead.
              final x = details.localPosition.dx;
              final target =
                  displayBeat + (x - playheadX) / widget.pxPerBeat;
              _commitSeek(target);
            },
            onPanStart: (details) {
              _didDrag = false;
              _dragStartBeat = displayBeat;
              _dragStartX = details.localPosition.dx;
              setState(() => _previewBeat = displayBeat);
            },
            onPanUpdate: (details) {
              final startBeat = _dragStartBeat;
              final startX = _dragStartX;
              if (startBeat == null || startX == null) return;

              final dx = details.localPosition.dx - startX;
              if (dx.abs() > 2) _didDrag = true;

              // Drag content right → earlier in the song.
              final next = _clampBeat(startBeat - dx / widget.pxPerBeat);
              setState(() => _previewBeat = next);
            },
            onPanEnd: (_) {
              final preview = _previewBeat;
              final dragged = _didDrag;
              setState(() {
                _previewBeat = null;
                _dragStartBeat = null;
                _dragStartX = null;
                _didDrag = false;
              });
              // Commit drag seeks only; pure taps use onTapUp (absolute).
              if (preview != null && dragged) {
                _commitSeek(preview);
              }
            },
            onPanCancel: () {
              setState(() {
                _previewBeat = null;
                _dragStartBeat = null;
                _dragStartX = null;
                _didDrag = false;
              });
            },
            child: lane,
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
