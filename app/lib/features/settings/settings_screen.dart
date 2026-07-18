import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/recognition_mode.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String _labSubtitle(WidgetRef ref) {
    final cal = ref.watch(calibrationProvider);
    final room = cal.hasNoise ? 'room ok' : 'room not set';
    final g = cal.hasGuitar ? 'guitar ok' : 'guitar not set';
    return 'Test recognition & calibrate ($room · $g)';
  }

  static String _chordsSubtitle(WidgetRef ref) {
    final v = ref.watch(chordVocabularyProvider);
    if (!v.enabled) return 'Filter off — full vocabulary';
    return 'On · ${v.symbols.length} chords';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoringEnabled = ref.watch(scoringEnabledProvider);
    final mode = ref.watch(recognitionModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Score with microphone'),
            subtitle: Text(
              'Listen to your guitar and show Good / Early / Late / Miss. '
              'Requires microphone permission.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            value: scoringEnabled,
            onChanged: (v) =>
                ref.read(scoringEnabledProvider.notifier).setEnabled(v),
          ),
          const Divider(height: 1),
          _MetronomeVolumeTile(theme: theme),
          const Divider(height: 1),
          _GuideVolumeTile(theme: theme),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Recognition mode',
              style: theme.textTheme.titleSmall,
            ),
          ),
          for (final m in RecognitionMode.values)
            ListTile(
              enabled: scoringEnabled,
              selected: mode == m,
              title: Text(m.label),
              subtitle: Text(
                m.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              leading: Icon(
                mode == m
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: mode == m
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              onTap: scoringEnabled
                  ? () =>
                      ref.read(recognitionModeProvider.notifier).setMode(m)
                  : null,
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.library_music_outlined),
            title: const Text('My chords'),
            subtitle: Text(
              _chordsSubtitle(ref),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/chords'),
          ),
          ListTile(
            leading: const Icon(Icons.graphic_eq),
            title: const Text('Mic Lab'),
            subtitle: Text(
              _labSubtitle(ref),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/lab'),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Tips',
              style: theme.textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(
              'Play near the mic and keep metronome / guide volume moderate '
              '(or mute) so they do not drown out your guitar. Prefer '
              'headphones when the guitar guide is on and scoring is enabled. '
              'Use Mic Lab to calibrate room/guitar noise isolation and '
              'compare modes.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetronomeVolumeTile extends ConsumerWidget {
  const _MetronomeVolumeTile({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(metronomeVolumeProvider);
    return _VolumeSliderTile(
      theme: theme,
      title: 'Metronome volume',
      subtitle:
          'Click track during count-in and metronome play-along. '
          'Drag to 0 or tap the icon to mute completely.',
      volume: volume,
      icon: Icons.music_note,
      onMute: () => ref.read(metronomeVolumeProvider.notifier).toggleMute(),
      onChanged: (v) =>
          ref.read(metronomeVolumeProvider.notifier).setVolume(v),
    );
  }
}

class _GuideVolumeTile extends ConsumerWidget {
  const _GuideVolumeTile({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(guideVolumeProvider);
    return _VolumeSliderTile(
      theme: theme,
      title: 'Guitar guide volume',
      subtitle:
          'Synthetic guitar pad + strum pattern so you can hear the '
          'chords and rhythm. Headphones recommended when scoring.',
      volume: volume,
      icon: Icons.queue_music,
      onMute: () => ref.read(guideVolumeProvider.notifier).toggleMute(),
      onChanged: (v) => ref.read(guideVolumeProvider.notifier).setVolume(v),
    );
  }
}

class _VolumeSliderTile extends StatelessWidget {
  const _VolumeSliderTile({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.volume,
    required this.icon,
    required this.onMute,
    required this.onChanged,
  });

  final ThemeData theme;
  final String title;
  final String subtitle;
  final double volume;
  final IconData icon;
  final VoidCallback onMute;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = volume <= 0;
    final pct = (volume * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                muted ? Icons.volume_off : icon,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                muted ? 'Off' : '$pct%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: muted
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: muted ? 'Unmute' : 'Mute',
                onPressed: onMute,
                icon: Icon(
                  muted
                      ? Icons.volume_off
                      : volume < 0.35
                          ? Icons.volume_down
                          : Icons.volume_up,
                ),
              ),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 1,
                  value: volume.clamp(0.0, 1.0),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
