import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/song.dart';
import '../player/widgets/strum_pattern_bar.dart';
import 'library_providers.dart';

class SongDetailScreen extends ConsumerWidget {
  const SongDetailScreen({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songAsync = ref.watch(songByIdProvider(songId));

    return songAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('$error')),
      ),
      data: (song) {
        if (song == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not found')),
            body: const Center(child: Text('Song not found.')),
          );
        }
        return _SongDetailBody(song: song);
      },
    );
  }
}

class _SongDetailBody extends StatelessWidget {
  const _SongDetailBody({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeSig = '${song.timeSignature[0]}/${song.timeSignature[1]}';

    return Scaffold(
      appBar: AppBar(
        title: Text(song.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(song.artist, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(label: '${song.tempoBpm.round()} BPM'),
              _MetaChip(label: timeSig),
              if (song.key != null) _MetaChip(label: 'Key ${song.key}'),
              if (song.capo > 0) _MetaChip(label: 'Capo ${song.capo}'),
              _MetaChip(
                label: song.hasAudio ? 'Backing audio' : 'Metronome / synth',
              ),
              if (song.hasStrum)
                _MetaChip(
                  label: song.strum!.name != null &&
                          song.strum!.name!.isNotEmpty
                      ? 'Strum: ${song.strum!.name}'
                      : 'Strum pattern',
                ),
              ...song.tags.map((t) => _MetaChip(label: t)),
            ],
          ),
          if (song.hasStrum) ...[
            const SizedBox(height: 16),
            StrumPatternPreview(pattern: song.strum!),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/song/${song.id}/play'),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play'),
          ),
          const SizedBox(height: 32),
          Text('Chords & lyrics', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final section in song.sections) ...[
            Text(section.name, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _SectionChordSheet(section: section),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _SectionChordSheet extends StatelessWidget {
  const _SectionChordSheet({required this.section});

  final SongSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final event in section.events)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        event.chord,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        event.lyrics.isEmpty ? '—' : event.lyrics,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      '${event.durationBeats.toStringAsFixed(event.durationBeats.truncateToDouble() == event.durationBeats ? 0 : 1)}b',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
