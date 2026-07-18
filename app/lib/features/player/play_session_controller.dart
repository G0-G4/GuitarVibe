import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/accompaniment.dart';
import '../../audio/beat_clock.dart';
import '../../audio/mic_pitch_source.dart';
import '../../domain/chord_guess.dart';
import '../../domain/play_session.dart';
import '../../domain/score.dart';
import '../../domain/song.dart';
import '../library/library_providers.dart';
import '../scoring/scoring_providers.dart';
import '../settings/settings_providers.dart';

class PlaySessionState {
  const PlaySessionState({
    required this.song,
    required this.snapshot,
    this.error,
    this.lastHit,
    this.lastHitEpoch = 0,
    this.liveScore,
    this.scoringActive = false,
    this.scoringError,
  });

  final Song song;
  final PlaySessionSnapshot snapshot;
  final String? error;

  /// Latest hit grade for live badge.
  final HitGrade? lastHit;

  /// Bumps on every new grade so the badge re-flashes even late→late.
  final int lastHitEpoch;

  /// Running score snapshot (null if scoring inactive).
  final SessionScore? liveScore;

  /// True when mic + engine are active this session.
  final bool scoringActive;

  /// Mic/permission issue (session still plays).
  final String? scoringError;

  PlaySessionState copyWith({
    Song? song,
    PlaySessionSnapshot? snapshot,
    String? error,
    bool clearError = false,
    HitGrade? lastHit,
    bool clearLastHit = false,
    int? lastHitEpoch,
    SessionScore? liveScore,
    bool? scoringActive,
    String? scoringError,
    bool clearScoringError = false,
  }) {
    return PlaySessionState(
      song: song ?? this.song,
      snapshot: snapshot ?? this.snapshot,
      error: clearError ? null : (error ?? this.error),
      lastHit: clearLastHit ? null : (lastHit ?? this.lastHit),
      lastHitEpoch: lastHitEpoch ?? this.lastHitEpoch,
      liveScore: liveScore ?? this.liveScore,
      scoringActive: scoringActive ?? this.scoringActive,
      scoringError:
          clearScoringError ? null : (scoringError ?? this.scoringError),
    );
  }
}

class PlaySessionController extends Notifier<PlaySessionState?> {
  PlaySessionController(this.songId);

  final String songId;

  BeatClock? _clock;
  Accompaniment? _accompaniment;
  ScoreEngine? _scoreEngine;
  MicAnalysisSource? _mic;
  StreamSubscription<AudioFeatures>? _featuresSub;
  bool _musicStarted = false;
  bool _finishing = false;
  bool _disposed = false;

  @override
  PlaySessionState? build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _disposeResources();
    });

    // Load song asynchronously; auto-start count-in when ready.
    Future.microtask(_bootstrap);
    return null;
  }

  Future<void> _bootstrap() async {
    try {
      final song = await ref.read(songByIdProvider(songId).future);
      if (_disposed || song == null) return;
      final countIn = countInBeatsFor(song);
      state = PlaySessionState(
        song: song,
        snapshot: PlaySessionSnapshot(
          status: PlayStatus.idle,
          currentBeat: -countIn.toDouble(),
          countInBeats: countIn,
        ),
      );
      await start();
    } catch (_) {
      // Leave state null; screen handles missing song.
    }
  }

  Future<void> start() async {
    final current = state;
    if (_disposed || current == null) return;

    await _disposeResources();
    if (_disposed) return;

    _musicStarted = false;
    _finishing = false;

    final song = current.song;
    final countIn = countInBeatsFor(song);
    final scoringWanted = ref.read(scoringEnabledProvider);
    final mode = ref.read(recognitionModeProvider);
    final cal = ref.read(calibrationProvider);
    final config = ref.read(effectiveRecognitionConfigProvider);

    try {
      final accompaniment = Accompaniment();
      await accompaniment.prepare(song);
      if (_disposed) {
        await accompaniment.dispose();
        return;
      }

      final clock = BeatClock(tempoBpm: song.tempoBpm);
      clock.onTick = _onTick;
      _clock = clock;
      _accompaniment = accompaniment;

      ScoreEngine? engine;
      String? scoringError;
      var scoringActive = false;

      if (scoringWanted) {
        engine = ScoreEngine(song.allEvents, mode: mode, config: config);
        _scoreEngine = engine;
        try {
          final mic = MicAnalysisSource(
            noiseChromaMean: cal.noise?.chromaMean,
          );
          await mic.start();
          if (_disposed) {
            await mic.dispose();
            return;
          }
          _mic = mic;
          _featuresSub = mic.features.listen(_onFeatures);
          scoringActive = true;
        } catch (e) {
          scoringError = 'Mic unavailable: $e';
          engine = null;
          _scoreEngine = null;
        }
      }

      // Clear previous complete-screen score when restarting.
      ref.read(lastSessionScoreProvider.notifier).clear();

      state = current.copyWith(
        snapshot: PlaySessionSnapshot(
          status: PlayStatus.countdown,
          currentBeat: -countIn.toDouble(),
          countInBeats: countIn,
        ),
        clearError: true,
        clearLastHit: true,
        liveScore: scoringActive ? engine?.summary : null,
        scoringActive: scoringActive,
        scoringError: scoringError,
        clearScoringError: scoringError == null,
      );

      clock.start(startBeat: -countIn.toDouble());
    } catch (e) {
      if (_disposed) return;
      state = current.copyWith(error: 'Could not start playback: $e');
    }
  }

  void _onFeatures(AudioFeatures features) {
    if (_disposed) return;
    final current = state;
    if (current == null) return;
    if (current.snapshot.status != PlayStatus.playing &&
        current.snapshot.status != PlayStatus.countdown) {
      return;
    }

    final engine = _scoreEngine;
    final clock = _clock;
    if (engine == null || clock == null) return;

    final prevGrade = engine.lastGrade;
    final prevTotal = engine.summary.total;
    final prevStreak = engine.summary.currentStreak;
    engine.onFeatures(
      features,
      beat: clock.currentBeat,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );

    final gradeChanged = engine.lastGrade != prevGrade;
    final scoreChanged = engine.summary.total != prevTotal ||
        engine.summary.currentStreak != prevStreak;
    // Also push when live badge must clear (engine null, UI still showing hit).
    final badgeStale =
        engine.lastGrade == null && current.lastHit != null;
    final epochChanged = engine.lastGradeEpoch != current.lastHitEpoch;
    if (!gradeChanged && !scoreChanged && !badgeStale && !epochChanged) {
      return;
    }

    // Engine is source of truth for the badge — never keep a stale lastHit.
    state = current.copyWith(
      lastHit: engine.lastGrade,
      clearLastHit: engine.lastGrade == null,
      lastHitEpoch: engine.lastGradeEpoch,
      liveScore: engine.summary,
    );
  }

  void _onTick(double beat) {
    if (_disposed) return;
    final current = state;
    if (current == null) return;
    if (current.snapshot.status == PlayStatus.paused) return;

    final song = current.song;
    var status = current.snapshot.status;

    if (beat < 0) {
      status = PlayStatus.countdown;
    } else if (beat >= song.totalBeats) {
      _finish();
      return;
    } else {
      if (!_musicStarted) {
        _musicStarted = true;
        final acc = _accompaniment;
        final clock = _clock;
        // Fire-and-forget start; re-anchor clock if audio is master.
        Future<void>(() async {
          await acc?.startMusicAtBeat(0);
          if (_disposed || acc == null || clock == null) return;
          if (acc.usesAudioMaster) {
            clock.masterPosition = () => acc.backing.position;
            clock.seekBeat(0);
          }
        });
      }
      status = PlayStatus.playing;
    }

    // Metronome clicks (count-in + metronome-only sessions).
    _accompaniment?.onBeat(beat);

    // Score window expiry (misses) + clear stale live feedback flash.
    final engine = _scoreEngine;
    HitGrade? lastHit = current.lastHit;
    var clearLastHit = false;
    SessionScore? liveScore = current.liveScore;
    var lastHitEpoch = current.lastHitEpoch;
    if (engine != null &&
        (status == PlayStatus.playing || status == PlayStatus.countdown)) {
      engine.onBeat(beat);
      // Always sync from engine. Using current.lastHit when engine already
      // cleared lastGrade re-stuck GOOD forever (tick/features race).
      lastHit = engine.lastGrade;
      clearLastHit = engine.lastGrade == null;
      lastHitEpoch = engine.lastGradeEpoch;
      liveScore = engine.summary;
    }

    state = current.copyWith(
      snapshot: current.snapshot.copyWith(
        status: status,
        currentBeat: beat,
      ),
      lastHit: lastHit,
      clearLastHit: clearLastHit,
      lastHitEpoch: lastHitEpoch,
      liveScore: liveScore,
    );
  }

  Future<void> pause() async {
    final current = state;
    if (current == null) return;
    if (current.snapshot.status != PlayStatus.playing &&
        current.snapshot.status != PlayStatus.countdown) {
      return;
    }
    _clock?.pause();
    await _accompaniment?.pause();
    state = current.copyWith(
      snapshot: current.snapshot.copyWith(status: PlayStatus.paused),
    );
  }

  Future<void> resume() async {
    final current = state;
    if (current == null) return;
    if (current.snapshot.status != PlayStatus.paused) return;

    final beat = current.snapshot.currentBeat;
    final status =
        beat < 0 ? PlayStatus.countdown : PlayStatus.playing;

    state = current.copyWith(
      snapshot: current.snapshot.copyWith(status: status),
    );
    await _accompaniment?.resume();
    _clock?.resume();
  }

  Future<void> restart() async {
    await start();
  }

  void _finish() {
    if (_finishing || _disposed) return;
    _finishing = true;
    final current = state;
    if (current == null) return;

    _clock?.stop();
    _accompaniment?.stop();

    // Close any remaining open windows as miss.
    final engine = _scoreEngine;
    if (engine != null) {
      engine.onBeat(current.song.totalBeats + 10);
      final summary = engine.summary;
      ref.read(lastSessionScoreProvider.notifier).setScore(summary);
      state = current.copyWith(
        snapshot: current.snapshot.copyWith(
          status: PlayStatus.finished,
          currentBeat: current.song.totalBeats,
        ),
        lastHit: engine.lastGrade,
        clearLastHit: engine.lastGrade == null,
        lastHitEpoch: engine.lastGradeEpoch,
        liveScore: summary,
      );
    } else {
      // Scoring off or mic failed — publish empty summary for the complete UI.
      final wanted = ref.read(scoringEnabledProvider);
      ref.read(lastSessionScoreProvider.notifier).setScore(
            SessionScore(scoringEnabled: wanted),
          );
      state = current.copyWith(
        snapshot: current.snapshot.copyWith(
          status: PlayStatus.finished,
          currentBeat: current.song.totalBeats,
        ),
      );
    }

    // Stop mic after publishing score.
    unawaited(_stopMic());
  }

  Future<void> _stopMic() async {
    await _featuresSub?.cancel();
    _featuresSub = null;
    final mic = _mic;
    _mic = null;
    await mic?.dispose();
  }

  Future<void> _disposeResources() async {
    _clock?.dispose();
    _clock = null;
    final acc = _accompaniment;
    _accompaniment = null;
    await acc?.dispose();
    _scoreEngine = null;
    await _stopMic();
  }
}

final playSessionProvider = NotifierProvider.autoDispose
    .family<PlaySessionController, PlaySessionState?, String>(
  PlaySessionController.new,
);
