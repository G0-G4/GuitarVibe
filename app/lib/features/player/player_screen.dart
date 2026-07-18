import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/play_session.dart';
import '../library/library_providers.dart';
import '../scoring/widgets/live_feedback_badge.dart';
import '../settings/settings_providers.dart';
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
    final metronomeVolume = ref.watch(metronomeVolumeProvider);

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
        final scoringError = session?.scoringError;
        final scoringActive = session?.scoringActive ?? false;
        final effectiveTempo =
            session?.effectiveTempoBpm ?? song.tempoBpm;
        final controller =
            ref.read(playSessionProvider(widget.songId).notifier);

        return Scaffold(
          appBar: AppBar(
            title: Text(song.title),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Text(
                    '${effectiveTempo.round()} BPM',
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
                      if (scoringError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          scoringError,
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
                          totalBeats: song.totalBeats,
                          onSeek: snapshot.status == PlayStatus.finished ||
                                  snapshot.status == PlayStatus.idle
                              ? null
                              : controller.seekToBeat,
                        ),
                      ),
                      if (scoringActive) ...[
                        const SizedBox(height: 12),
                        LiveFeedbackBadge(
                          grade: session?.lastHit,
                          streak: session?.liveScore?.currentStreak ?? 0,
                          epoch: session?.lastHitEpoch ?? 0,
                        ),
                      ],
                      const SizedBox(height: 12),
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
                        effectiveTempoBpm: effectiveTempo,
                        metronomeVolume: metronomeVolume,
                        onPause: controller.pause,
                        onResume: controller.resume,
                        onRestart: () {
                          _navigatedToComplete = false;
                          controller.restart();
                        },
                        onSeek: controller.seekToBeat,
                        onNudgeTempo: controller.nudgeTempo,
                        onResetTempo: controller.resetTempo,
                        onMetronomeVolume: (v) => ref
                            .read(metronomeVolumeProvider.notifier)
                            .setVolume(v),
                        onToggleMetronomeMute: () => ref
                            .read(metronomeVolumeProvider.notifier)
                            .toggleMute(),
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
