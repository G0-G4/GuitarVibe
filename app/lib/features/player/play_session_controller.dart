import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/accompaniment.dart';
import '../../audio/beat_clock.dart';
import '../../domain/play_session.dart';
import '../../domain/song.dart';
import '../library/library_providers.dart';

class PlaySessionState {
  const PlaySessionState({
    required this.song,
    required this.snapshot,
    this.error,
  });

  final Song song;
  final PlaySessionSnapshot snapshot;
  final String? error;

  PlaySessionState copyWith({
    Song? song,
    PlaySessionSnapshot? snapshot,
    String? error,
    bool clearError = false,
  }) {
    return PlaySessionState(
      song: song ?? this.song,
      snapshot: snapshot ?? this.snapshot,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PlaySessionController extends Notifier<PlaySessionState?> {
  PlaySessionController(this.songId);

  final String songId;

  BeatClock? _clock;
  Accompaniment? _accompaniment;
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

    try {
      final accompaniment = Accompaniment();
      await accompaniment.prepare(song);
      if (_disposed) {
        await accompaniment.dispose();
        return;
      }

      final clock = BeatClock(tempoBpm: song.tempoBpm);
      // Count-in always uses the stopwatch. Audio becomes master after music starts.
      clock.onTick = _onTick;
      _clock = clock;
      _accompaniment = accompaniment;

      state = current.copyWith(
        snapshot: PlaySessionSnapshot(
          status: PlayStatus.countdown,
          currentBeat: -countIn.toDouble(),
          countInBeats: countIn,
        ),
        clearError: true,
      );

      clock.start(startBeat: -countIn.toDouble());
    } catch (e) {
      if (_disposed) return;
      state = current.copyWith(error: 'Could not start playback: $e');
    }
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

    state = current.copyWith(
      snapshot: current.snapshot.copyWith(
        status: status,
        currentBeat: beat,
      ),
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

    state = current.copyWith(
      snapshot: current.snapshot.copyWith(
        status: PlayStatus.finished,
        currentBeat: current.song.totalBeats,
      ),
    );
  }

  Future<void> _disposeResources() async {
    _clock?.dispose();
    _clock = null;
    final acc = _accompaniment;
    _accompaniment = null;
    await acc?.dispose();
  }
}

final playSessionProvider = NotifierProvider.autoDispose
    .family<PlaySessionController, PlaySessionState?, String>(
  PlaySessionController.new,
);
