import 'package:just_audio/just_audio.dart';

import '../domain/play_session.dart';
import '../domain/song.dart';

/// Plays a song's backing track when [Song.audio] is set.
///
/// Position is the master clock source for the session.
class BackingAudioPlayer {
  BackingAudioPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  Song? _song;
  bool _prepared = false;

  Stream<Duration> get positionStream => _player.positionStream;

  Duration get position => _player.position;

  bool get isPrepared => _prepared;

  /// Resolve asset path relative to the song pack.
  /// Convention: `assets/songs/<id>/<audio.file>`.
  static String assetPathFor(Song song) {
    final file = song.audio?.file;
    if (file == null) {
      throw StateError('Song ${song.id} has no audio');
    }
    if (file.startsWith('assets/')) return file;
    return 'assets/songs/${song.id}/$file';
  }

  Future<void> prepare(Song song) async {
    if (song.audio == null) {
      _prepared = false;
      return;
    }
    _song = song;
    final path = assetPathFor(song);
    await _player.setAsset(path);
    final volume = song.accompaniment.volume.clamp(0.0, 1.0);
    await _player.setVolume(volume);
    _prepared = true;
  }

  /// Seek to the media time that corresponds to [songBeat] and play.
  Future<void> startAtBeat(double songBeat) async {
    if (!_prepared || _song == null || _song!.audio == null) return;
    await seekToBeat(songBeat);
    await _player.play();
  }

  /// Seek without forcing play (used by scrub while paused/playing).
  ///
  /// Media time uses **authored** [Song.tempoBpm] (track is recorded at song tempo).
  Future<void> seekToBeat(double songBeat) async {
    if (!_prepared || _song == null || _song!.audio == null) return;
    final offset = _song!.audio!.offsetSec;
    final sec =
        offset + beatsToSeconds(songBeat.clamp(0, double.infinity), _song!.tempoBpm);
    await _player.seek(Duration(microseconds: (sec * 1e6).round()));
  }

  /// Practice playback rate (1.0 = song tempo). Pitch may shift with speed.
  Future<void> setPlaybackRate(double rate) async {
    if (!_prepared) return;
    final r = rate.clamp(minPlaybackRate, maxPlaybackRate).toDouble();
    await _player.setSpeed(r);
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.play();

  Future<void> stop() async {
    await _player.stop();
  }

  /// Convert audio position → song beat.
  double beatForPosition(Duration position, Song song) {
    final offset = song.audio?.offsetSec ?? 0;
    final sec = position.inMicroseconds / 1e6 - offset;
    return secondsToBeats(sec, song.tempoBpm);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
