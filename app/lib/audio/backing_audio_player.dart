import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/play_session.dart';
import '../domain/song.dart';

/// Plays a song's backing track when [Song.audio] is set.
///
/// Position is the master clock source for the session.
/// If the asset is missing or fails to load, [prepare] soft-fails and
/// [isPrepared] stays false (caller should fall back to metronome).
///
/// Beat ↔ media mapping uses **session map tempo** and **offset**, not only
/// authored [Song.tempoBpm], so the chart can be calibrated to the recording
/// without changing playback speed.
class BackingAudioPlayer {
  BackingAudioPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  Song? _song;
  bool _prepared = false;
  String? _lastError;

  /// Chart ↔ media tempo (BPM). Defaults to song tempo on prepare.
  double _mapTempoBpm = 120;

  /// Media time (sec) that maps to song beat 0.
  double _offsetSec = 0;

  Stream<Duration> get positionStream => _player.positionStream;

  Duration get position => _player.position;

  bool get isPrepared => _prepared;

  /// Last load failure message (null when prepared or never attempted).
  String? get lastError => _lastError;

  double get mapTempoBpm => _mapTempoBpm;

  double get offsetSec => _offsetSec;

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

  /// Load the song's backing asset. Returns `true` on success.
  ///
  /// On failure (missing asset, codec error, etc.) returns `false` and leaves
  /// the player unprepared so accompaniment can use metronome + guide.
  Future<bool> prepare(
    Song song, {
    double volume = 0.7,
    double? mapTempoBpm,
    double? offsetSec,
  }) async {
    _lastError = null;
    if (song.audio == null) {
      _prepared = false;
      _song = null;
      return false;
    }
    _song = song;
    _mapTempoBpm = mapTempoBpm ?? song.tempoBpm;
    _offsetSec = offsetSec ?? song.audio!.offsetSec;
    final path = assetPathFor(song);
    try {
      await _player.setAsset(path);
      await _player.setVolume(volume.clamp(0.0, 1.0));
      // Chart calibration does not change playback rate (always 1.0).
      await _player.setSpeed(1.0);
      _prepared = true;
      return true;
    } catch (e, st) {
      _prepared = false;
      _lastError = 'Could not load backing audio ($path): $e';
      debugPrint('BackingAudioPlayer.prepare failed: $e\n$st');
      return false;
    }
  }

  /// Live track volume 0–1.
  Future<void> setVolume(double volume) async {
    if (!_prepared) return;
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Update chart ↔ media mapping (does not seek by itself).
  void setMapTiming({double? mapTempoBpm, double? offsetSec}) {
    if (mapTempoBpm != null && mapTempoBpm > 0) {
      _mapTempoBpm = mapTempoBpm;
    }
    if (offsetSec != null) {
      _offsetSec = offsetSec;
    }
  }

  /// Seek to the media time that corresponds to [songBeat] and play.
  Future<void> startAtBeat(double songBeat) async {
    if (!_prepared || _song == null || _song!.audio == null) return;
    await seekToBeat(songBeat);
    await _player.play();
  }

  /// Seek without forcing play (used by scrub while paused/playing).
  Future<void> seekToBeat(double songBeat) async {
    if (!_prepared || _song == null || _song!.audio == null) return;
    final sec = _offsetSec +
        beatsToSeconds(songBeat.clamp(0, double.infinity), _mapTempoBpm);
    await _player.seek(Duration(microseconds: (sec * 1e6).round()));
  }

  /// Optional practice playback rate (pitch may shift). Default path keeps 1.0.
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

  /// Convert audio position → song beat using current map timing.
  double beatForPosition(Duration position) {
    final sec = position.inMicroseconds / 1e6 - _offsetSec;
    return secondsToBeats(sec, _mapTempoBpm);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
