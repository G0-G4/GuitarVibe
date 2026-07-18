import 'package:flutter/material.dart';

import '../../../domain/play_session.dart';
import '../../../domain/song.dart';

class PlayTransport extends StatelessWidget {
  const PlayTransport({
    super.key,
    required this.song,
    required this.snapshot,
    required this.onPause,
    required this.onResume,
    required this.onRestart,
  });

  final Song song;
  final PlaySessionSnapshot snapshot;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final beatsPerBar =
        song.timeSignature.isNotEmpty ? song.timeSignature[0] : 4;
    final beat = snapshot.currentBeat;
    final bar = barNumber(beat, beatsPerBar);
    final inBar = beatInBar(beat, beatsPerBar);
    final total = song.totalBeats;

    final isPaused = snapshot.status == PlayStatus.paused;
    final canToggle = snapshot.status == PlayStatus.playing ||
        snapshot.status == PlayStatus.countdown ||
        snapshot.status == PlayStatus.paused;

    String positionLabel;
    if (beat < 0) {
      positionLabel = 'Count-in · ${snapshot.countdownBeatsLeft}';
    } else {
      positionLabel =
          'Bar $bar · beat ${inBar.toStringAsFixed(1)} / ${total.toStringAsFixed(0)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          positionLabel,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total <= 0
                ? 0
                : (beat.clamp(0, total) / total).clamp(0.0, 1.0),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: onRestart,
              icon: const Icon(Icons.replay),
              tooltip: 'Restart',
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: !canToggle
                  ? null
                  : (isPaused ? onResume : onPause),
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              label: Text(isPaused ? 'Resume' : 'Pause'),
            ),
          ],
        ),
      ],
    );
  }
}
