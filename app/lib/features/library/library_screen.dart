import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/song.dart';
import 'library_providers.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(bundledSongsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GuitarVibe'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Mic Lab',
            icon: const Icon(Icons.graphic_eq),
            onPressed: () => context.push('/lab'),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text('Failed to load songs:\n$error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(bundledSongsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (songs) {
          if (songs.isEmpty) {
            return const Center(child: Text('No songs in the library yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: songs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final song = songs[index];
              return _SongTile(song: song);
            },
          );
        },
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeSig = '${song.timeSignature[0]}/${song.timeSignature[1]}';
    final duration = song.estimatedDuration;
    final durationLabel =
        '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(song.title, style: theme.textTheme.titleMedium),
        subtitle: Text(
          [
            song.artist,
            '${song.tempoBpm.round()} BPM',
            timeSig,
            if (song.key != null) 'Key ${song.key}',
            durationLabel,
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (song.hasAudio)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.audiotrack, size: 18),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push('/song/${song.id}'),
      ),
    );
  }
}
