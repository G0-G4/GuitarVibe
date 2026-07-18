import 'package:flutter/material.dart';

import '../../../domain/play_session.dart';
import '../../../domain/song.dart';

class PlayTransport extends StatefulWidget {
  const PlayTransport({
    super.key,
    required this.song,
    required this.snapshot,
    required this.effectiveTempoBpm,
    required this.metronomeVolume,
    required this.guideVolume,
    required this.onPause,
    required this.onResume,
    required this.onRestart,
    required this.onSeek,
    required this.onNudgeTempo,
    required this.onResetTempo,
    required this.onMetronomeVolume,
    required this.onToggleMetronomeMute,
    required this.onGuideVolume,
    required this.onToggleGuideMute,
  });

  final Song song;
  final PlaySessionSnapshot snapshot;
  final double effectiveTempoBpm;

  /// Metronome click gain 0–1 (0 = fully off).
  final double metronomeVolume;

  /// Guitar guide (pad + strum) gain 0–1 (0 = fully off).
  final double guideVolume;

  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onNudgeTempo;
  final VoidCallback onResetTempo;
  final ValueChanged<double> onMetronomeVolume;
  final VoidCallback onToggleMetronomeMute;
  final ValueChanged<double> onGuideVolume;
  final VoidCallback onToggleGuideMute;

  @override
  State<PlayTransport> createState() => _PlayTransportState();
}

class _PlayTransportState extends State<PlayTransport> {
  /// Local scrub position while the user drags; null when not scrubbing.
  double? _scrubBeat;

  bool get _isTempoOverridden =>
      (widget.effectiveTempoBpm - widget.song.tempoBpm).abs() > 0.01;

  bool get _canControl {
    final s = widget.snapshot.status;
    return s == PlayStatus.playing ||
        s == PlayStatus.countdown ||
        s == PlayStatus.paused;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final song = widget.song;
    final snapshot = widget.snapshot;
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

    final sliderMax = total > 0 ? total : 1.0;
    final displayBeat = _scrubBeat ?? beat.clamp(0.0, sliderMax).toDouble();

    final effective = widget.effectiveTempoBpm.round();
    final songBpm = song.tempoBpm.round();

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
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            min: 0,
            max: sliderMax,
            value: displayBeat.clamp(0.0, sliderMax),
            onChanged: !_canControl || total <= 0
                ? null
                : (v) {
                    setState(() => _scrubBeat = v);
                  },
            onChangeEnd: !_canControl || total <= 0
                ? null
                : (v) {
                    setState(() => _scrubBeat = null);
                    widget.onSeek(v);
                  },
          ),
        ),
        const SizedBox(height: 8),
        _TempoRow(
          effectiveBpm: effective,
          songBpm: songBpm,
          isOverridden: _isTempoOverridden,
          enabled: _canControl,
          onNudge: widget.onNudgeTempo,
          onReset: widget.onResetTempo,
        ),
        const SizedBox(height: 8),
        _VolumeRow(
          label: 'Click',
          volume: widget.metronomeVolume,
          enabled: _canControl,
          muteTooltip: 'Mute metronome',
          unmuteTooltip: 'Unmute metronome',
          activeIcon: Icons.music_note,
          onChanged: widget.onMetronomeVolume,
          onToggleMute: widget.onToggleMetronomeMute,
        ),
        _VolumeRow(
          label: 'Guide',
          volume: widget.guideVolume,
          enabled: _canControl,
          muteTooltip: 'Mute guitar guide',
          unmuteTooltip: 'Unmute guitar guide',
          activeIcon: Icons.queue_music,
          onChanged: widget.onGuideVolume,
          onToggleMute: widget.onToggleGuideMute,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: widget.onRestart,
              icon: const Icon(Icons.replay),
              tooltip: 'Restart',
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: !canToggle
                  ? null
                  : (isPaused ? widget.onResume : widget.onPause),
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              label: Text(isPaused ? 'Resume' : 'Pause'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TempoRow extends StatelessWidget {
  const _TempoRow({
    required this.effectiveBpm,
    required this.songBpm,
    required this.isOverridden,
    required this.enabled,
    required this.onNudge,
    required this.onReset,
  });

  final int effectiveBpm;
  final int songBpm;
  final bool isOverridden;
  final bool enabled;
  final ValueChanged<double> onNudge;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = isOverridden
        ? '$effectiveBpm BPM · song $songBpm'
        : '$effectiveBpm BPM';

    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isOverridden
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            _TempoChip(
              label: '−10',
              onPressed: enabled ? () => onNudge(-10) : null,
            ),
            _TempoChip(
              label: '−5',
              onPressed: enabled ? () => onNudge(-5) : null,
            ),
            _TempoChip(
              label: 'Reset',
              onPressed: enabled && isOverridden ? onReset : null,
            ),
            _TempoChip(
              label: '+5',
              onPressed: enabled ? () => onNudge(5) : null,
            ),
            _TempoChip(
              label: '+10',
              onPressed: enabled ? () => onNudge(10) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _TempoChip extends StatelessWidget {
  const _TempoChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.volume,
    required this.enabled,
    required this.muteTooltip,
    required this.unmuteTooltip,
    required this.activeIcon,
    required this.onChanged,
    required this.onToggleMute,
  });

  final String label;
  final double volume;
  final bool enabled;
  final String muteTooltip;
  final String unmuteTooltip;
  final IconData activeIcon;
  final ValueChanged<double> onChanged;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = volume <= 0;
    final pct = (volume * 100).round();

    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        IconButton(
          onPressed: enabled ? onToggleMute : null,
          tooltip: muted ? unmuteTooltip : muteTooltip,
          icon: Icon(
            muted
                ? Icons.volume_off
                : volume < 0.35
                    ? Icons.volume_down
                    : activeIcon,
          ),
        ),
        Expanded(
          child: Slider(
            min: 0,
            max: 1,
            value: volume.clamp(0.0, 1.0),
            onChanged: enabled ? onChanged : null,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            muted ? 'Off' : '$pct%',
            textAlign: TextAlign.end,
            style: theme.textTheme.labelMedium?.copyWith(
              color: muted
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
