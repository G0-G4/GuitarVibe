import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/play_session.dart';
import '../library/library_providers.dart';
import 'play_session_controller.dart';
import 'widgets/chord_scroller.dart';
import 'widgets/countdown_overlay.dart';
import 'widgets/play_transport.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.songId});

  final String songId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _navigatedToComplete = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(playSessionProvider(widget.songId));
    final songAsync = ref.watch(songByIdProvider(widget.songId));

    // Navigate when finished.
    ref.listen(playSessionProvider(widget.songId), (prev, next) {
      if (_navigatedToComplete) return;
      if (next?.snapshot.status == PlayStatus.finished) {
        _navigatedToComplete = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.go('/song/${widget.songId}/complete');
        });
      }
    });

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

        final snapshot = session?.snapshot ??
            PlaySessionSnapshot(
              status: PlayStatus.idle,
              currentBeat: -countInBeatsFor(song).toDouble(),
              countInBeats: countInBeatsFor(song),
            );

        final event = snapshot.currentEvent(song);
        final lyrics = event?.lyrics ?? '';
        final theme = Theme.of(context);
        final error = session?.error;

        return Scaffold(
          appBar: AppBar(
            title: Text(song.title),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Text(
                    '${song.tempoBpm.round()} BPM',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        song.artist,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          error,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Expanded(
                        flex: 3,
                        child: ChordScroller(
                          events: song.allEvents,
                          currentBeat: snapshot.currentBeat,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 72,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: Text(
                              lyrics.isEmpty ? '—' : lyrics,
                              key: ValueKey(lyrics),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      PlayTransport(
                        song: song,
                        snapshot: snapshot,
                        onPause: () => ref
                            .read(playSessionProvider(widget.songId).notifier)
                            .pause(),
                        onResume: () => ref
                            .read(playSessionProvider(widget.songId).notifier)
                            .resume(),
                        onRestart: () {
                          _navigatedToComplete = false;
                          ref
                              .read(
                                playSessionProvider(widget.songId).notifier,
                              )
                              .restart();
                        },
                      ),
                    ],
                  ),
                ),
                CountdownOverlay(snapshot: snapshot),
              ],
            ),
          ),
        );
      },
    );
  }
}
