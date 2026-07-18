import 'package:flutter/material.dart';

import '../../../domain/accompaniment_mode.dart';
import '../../../domain/play_session.dart';
import '../../../domain/song.dart';
import 'accompaniment_mode_picker.dart';

class PlayTransport extends StatefulWidget {
  const PlayTransport({
    super.key,
    required this.song,
    required this.snapshot,
    required this.effectiveTempoBpm,
    required this.metronomeVolume,
    required this.secondaryVolume,
    required this.usesAudioMaster,
    required this.accompanimentMode,
    required this.audioOffsetSec,
    required this.isOffsetOverridden,
    required this.onPause,
    required this.onResume,
    required this.onRestart,
    required this.onSeek,
    required this.onNudgeTempo,
    required this.onResetTempo,
    required this.onMetronomeVolume,
    required this.onToggleMetronomeMute,
    required this.onSecondaryVolume,
    required this.onToggleSecondaryMute,
    required this.onAccompanimentMode,
    required this.onNudgeOffset,
    required this.onResetOffset,
  });

  final Song song;
  final PlaySessionSnapshot snapshot;
  final double effectiveTempoBpm;

  /// Metronome click gain 0–1 (0 = fully off).
  final double metronomeVolume;

  /// Guide volume (synth) or Track volume (recording), depending on mode.
  final double secondaryVolume;

  /// True when the session plays a real backing track as master clock.
  final bool usesAudioMaster;

  /// Preferred / selected accompaniment mode (only when song has audio).
  final AccompanimentMode accompanimentMode;

  /// Session media offset (sec) for beat 0.
  final double audioOffsetSec;

  final bool isOffsetOverridden;

  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onNudgeTempo;
  final VoidCallback onResetTempo;
  final ValueChanged<double> onMetronomeVolume;
  final VoidCallback onToggleMetronomeMute;
  final ValueChanged<double> onSecondaryVolume;
  final VoidCallback onToggleSecondaryMute;
  final ValueChanged<AccompanimentMode> onAccompanimentMode;
  final ValueChanged<double> onNudgeOffset;
  final VoidCallback onResetOffset;

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

    final secondaryLabel = widget.usesAudioMaster ? 'Track' : 'Guide';
    final secondaryIcon =
        widget.usesAudioMaster ? Icons.audiotrack : Icons.queue_music;

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
        if (song.hasAudio) ...[
          AccompanimentModePicker(
            mode: widget.accompanimentMode,
            compact: true,
            enabled: _canControl,
            onChanged: widget.onAccompanimentMode,
          ),
          const SizedBox(height: 8),
        ],
        _TempoRow(
          effectiveBpm: effective,
          songBpm: songBpm,
          isOverridden: _isTempoOverridden,
          enabled: _canControl,
          isMapMode: widget.usesAudioMaster,
          onNudge: widget.onNudgeTempo,
          onReset: widget.onResetTempo,
        ),
        if (widget.usesAudioMaster) ...[
          const SizedBox(height: 6),
          _OffsetRow(
            offsetSec: widget.audioOffsetSec,
            isOverridden: widget.isOffsetOverridden,
            enabled: _canControl,
            onNudge: widget.onNudgeOffset,
            onReset: widget.onResetOffset,
          ),
        ],
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
          label: secondaryLabel,
          volume: widget.secondaryVolume,
          enabled: _canControl,
          muteTooltip: widget.usesAudioMaster
              ? 'Mute track'
              : 'Mute guitar guide',
          unmuteTooltip: widget.usesAudioMaster
              ? 'Unmute track'
              : 'Unmute guitar guide',
          activeIcon: secondaryIcon,
          onChanged: widget.onSecondaryVolume,
          onToggleMute: widget.onToggleSecondaryMute,
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
    required this.isMapMode,
    required this.onNudge,
    required this.onReset,
  });

  final int effectiveBpm;
  final int songBpm;
  final bool isOverridden;
  final bool enabled;
  final bool isMapMode;
  final ValueChanged<double> onNudge;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = isMapMode
        ? (isOverridden
            ? '$effectiveBpm map · song $songBpm'
            : '$effectiveBpm BPM · chart map')
        : (isOverridden
            ? '$effectiveBpm BPM · song $songBpm'
            : '$effectiveBpm BPM');

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
        if (isMapMode) ...[
          const SizedBox(height: 2),
          Text(
            'Sync chart to track (does not speed up the recording)',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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

class _OffsetRow extends StatelessWidget {
  const _OffsetRow({
    required this.offsetSec,
    required this.isOverridden,
    required this.enabled,
    required this.onNudge,
    required this.onReset,
  });

  final double offsetSec;
  final bool isOverridden;
  final bool enabled;
  final ValueChanged<double> onNudge;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ms = (offsetSec * 1000).round();

    return Column(
      children: [
        Text(
          'Offset $ms ms',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isOverridden
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Shift beat 0 vs the recording',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            _TempoChip(
              label: '−100ms',
              onPressed: enabled ? () => onNudge(-0.1) : null,
            ),
            _TempoChip(
              label: '−50ms',
              onPressed: enabled ? () => onNudge(-0.05) : null,
            ),
            _TempoChip(
              label: 'Reset',
              onPressed: enabled && isOverridden ? onReset : null,
            ),
            _TempoChip(
              label: '+50ms',
              onPressed: enabled ? () => onNudge(0.05) : null,
            ),
            _TempoChip(
              label: '+100ms',
              onPressed: enabled ? () => onNudge(0.1) : null,
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
