import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/accompaniment_mode.dart';
import '../../domain/play_session.dart';
import '../library/library_providers.dart';
import '../scoring/widgets/live_feedback_badge.dart';
import '../settings/settings_providers.dart';
import 'play_session_controller.dart';
import 'widgets/chord_scroller.dart';
import 'widgets/countdown_overlay.dart';
import 'widgets/lyrics_scroller.dart';
import 'widgets/play_transport.dart';
import 'widgets/strum_pattern_bar.dart';

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
    final guideVolume = ref.watch(guideVolumeProvider);
    final backingVolume = ref.watch(backingVolumeProvider);
    final accompanimentMode = ref.watch(accompanimentModeProvider);

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

        final theme = Theme.of(context);
        final error = session?.error;
        final scoringError = session?.scoringError;
        final scoringActive = session?.scoringActive ?? false;
        final effectiveTempo =
            session?.effectiveTempoBpm ?? song.tempoBpm;
        final controller =
            ref.read(playSessionProvider(widget.songId).notifier);
        // Shared geometry so lyric phrases align in time with chord cards.
        const scrollerPxPerBeat = 100.0;
        const scrollerPlayheadFraction = 0.28;

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
                      const SizedBox(height: 12),
                      Expanded(
                        flex: 3,
                        child: ChordScroller(
                          events: song.allEvents,
                          currentBeat: snapshot.currentBeat,
                          totalBeats: song.totalBeats,
                          pxPerBeat: scrollerPxPerBeat,
                          playheadFraction: scrollerPlayheadFraction,
                          onSeek: snapshot.status == PlayStatus.finished ||
                                  snapshot.status == PlayStatus.idle
                              ? null
                              : controller.seekToBeat,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        flex: 2,
                        child: LyricsScroller(
                          events: song.allEvents,
                          currentBeat: snapshot.currentBeat,
                          pxPerBeat: scrollerPxPerBeat,
                          playheadFraction: scrollerPlayheadFraction,
                        ),
                      ),
                      if (song.hasStrum) ...[
                        const SizedBox(height: 10),
                        StrumPatternBar(
                          pattern: song.strum!,
                          currentBeat: snapshot.currentBeat,
                        ),
                      ],
                      if (scoringActive) ...[
                        const SizedBox(height: 10),
                        LiveFeedbackBadge(
                          grade: session?.lastHit,
                          streak: session?.liveScore?.currentStreak ?? 0,
                          epoch: session?.lastHitEpoch ?? 0,
                        ),
                      ],
                      const SizedBox(height: 8),
                      PlayTransport(
                        song: song,
                        snapshot: snapshot,
                        effectiveTempoBpm: effectiveTempo,
                        metronomeVolume: metronomeVolume,
                        secondaryVolume: (session?.usesAudioMaster ?? false)
                            ? backingVolume
                            : guideVolume,
                        usesAudioMaster: session?.usesAudioMaster ?? false,
                        // User preference (session may soft-fail to guide).
                        accompanimentMode: song.hasAudio
                            ? accompanimentMode
                            : AccompanimentMode.generated,
                        audioOffsetSec: session?.audioOffsetSec ??
                            (song.audio?.offsetSec ?? 0),
                        isOffsetOverridden:
                            session?.isOffsetOverridden ?? false,
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
                        onSecondaryVolume: (v) {
                          if (session?.usesAudioMaster ?? false) {
                            ref
                                .read(backingVolumeProvider.notifier)
                                .setVolume(v);
                          } else {
                            ref
                                .read(guideVolumeProvider.notifier)
                                .setVolume(v);
                          }
                        },
                        onToggleSecondaryMute: () {
                          if (session?.usesAudioMaster ?? false) {
                            ref
                                .read(backingVolumeProvider.notifier)
                                .toggleMute();
                          } else {
                            ref
                                .read(guideVolumeProvider.notifier)
                                .toggleMute();
                          }
                        },
                        onAccompanimentMode: (mode) async {
                          await ref
                              .read(accompanimentModeProvider.notifier)
                              .setMode(mode);
                          if (!mounted) return;
                          _navigatedToComplete = false;
                          await controller.restart();
                        },
                        onNudgeOffset: controller.nudgeAudioOffset,
                        onResetOffset: controller.resetAudioOffset,
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
