import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../library/library_providers.dart';

class SessionCompleteScreen extends ConsumerWidget {
  const SessionCompleteScreen({super.key, required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songAsync = ref.watch(songByIdProvider(songId));
    final theme = Theme.of(context);

    return songAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
      data: (song) {
        if (song == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not found')),
            body: const Center(child: Text('Song not found.')),
          );
        }

        final duration = song.estimatedDuration;
        final minutes = duration.inMinutes;
        final seconds = duration.inSeconds % 60;
        final durationLabel =
            '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Finished'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.go('/song/$songId'),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Icon(
                    Icons.check_circle_outline,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    song.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Played · $durationLabel',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scoring comes in a later phase.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => context.go('/song/$songId/play'),
                    icon: const Icon(Icons.replay),
                    label: const Text('Play again'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.library_music_outlined),
                    label: const Text('Back to library'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
