import '../domain/song.dart';
import 'backing_audio_player.dart';
import 'guitar_guide_player.dart';
import 'metronome_player.dart';

/// Facade: prefer backing audio when present, else metronome + guitar guide.
///
/// Count-in always uses the metronome (when style ≠ `none`) so the user
/// can lock in before a backing track starts.
///
/// Guitar guide (pad + strum samples) runs on the metronome path only;
/// when backing audio is master after music starts, guide is silent.
class Accompaniment {
  Accompaniment({
    MetronomePlayer? metronome,
    BackingAudioPlayer? backing,
    GuitarGuidePlayer? guide,
  })  : _metronome = metronome ?? MetronomePlayer(),
        _backing = backing ?? BackingAudioPlayer(),
        _guide = guide ?? GuitarGuidePlayer();

  final MetronomePlayer _metronome;
  final BackingAudioPlayer _backing;
  final GuitarGuidePlayer _guide;

  bool _useAudio = false;
  bool _musicPlaying = false;

  bool get usesAudioMaster => _useAudio;

  BackingAudioPlayer get backing => _backing;

  /// Prepare players for [song].
  ///
  /// When [preferBackingAudio] is true and the song declares audio, tries to
  /// load the track as master clock. Soft-fails to metronome + guide if the
  /// asset is missing. When false, always uses the synthetic path even if a
  /// track is available.
  Future<void> prepare(
    Song song, {
    double? metronomeVolume,
    double? guideVolume,
    double? backingVolume,
    bool preferBackingAudio = true,
    double? mapTempoBpm,
    double? audioOffsetSec,
  }) async {
    _musicPlaying = false;

    // Metronome for count-in (and full session when no / unused audio).
    await _metronome.prepare(song, volume: metronomeVolume);
    await _guide.prepare(song, volume: guideVolume);

    if (song.hasAudio && preferBackingAudio) {
      final ok = await _backing.prepare(
        song,
        volume: backingVolume ?? song.accompaniment.volume,
        mapTempoBpm: mapTempoBpm ?? song.tempoBpm,
        offsetSec: audioOffsetSec ?? song.audio?.offsetSec,
      );
      _useAudio = ok;
    } else {
      _useAudio = false;
    }
  }

  /// Live metronome gain 0–1 (0 = fully off).
  Future<void> setMetronomeVolume(double volume) =>
      _metronome.setVolume(volume);

  double get metronomeVolume => _metronome.volume;

  /// Live guitar guide gain 0–1 (0 = fully off). Synth path only.
  Future<void> setGuideVolume(double volume) => _guide.setVolume(volume);

  double get guideVolume => _guide.volume;

  /// Live backing-track gain 0–1 (Recording path).
  Future<void> setBackingVolume(double volume) => _backing.setVolume(volume);

  /// Update chart ↔ media mapping for seeks (map BPM / offset).
  void setMapTiming({double? mapTempoBpm, double? offsetSec}) {
    _backing.setMapTiming(mapTempoBpm: mapTempoBpm, offsetSec: offsetSec);
  }

  /// Called every clock tick with the current song beat (may be negative).
  Future<void> onBeat(double beat) async {
    // With backing audio as master after music starts, skip click + guide.
    if (_useAudio && _musicPlaying) return;
    await _metronome.onBeat(beat);
    await _guide.onBeat(beat);
  }

  /// When song music starts (beat >= 0).
  Future<void> startMusicAtBeat(double beat) async {
    if (_useAudio) {
      _musicPlaying = true;
      await _backing.startAtBeat(beat);
    }
  }

  /// Seek accompaniment to [beat]. Starts music if scrubbing past count-in
  /// onto a backing track. Respects [playing] (pause after seek if false).
  Future<void> seekToBeat(double beat, {required bool playing}) async {
    _metronome.reset();
    _guide.reset();
    if (!_useAudio) {
      // Metronome path: guide will re-fire chord/step on next ticks.
      return;
    }

    if (beat < 0) {
      // Still in count-in: stop any started track.
      if (_musicPlaying) {
        await _backing.stop();
        _musicPlaying = false;
      }
      return;
    }

    if (!_musicPlaying) {
      if (playing) {
        _musicPlaying = true;
        await _backing.startAtBeat(beat);
      } else {
        // Prepare position while paused; play on resume.
        _musicPlaying = true;
        await _backing.seekToBeat(beat);
        await _backing.pause();
      }
      return;
    }

    await _backing.seekToBeat(beat);
    if (playing) {
      await _backing.resume();
    } else {
      await _backing.pause();
    }
  }

  /// Rate for backing audio (1.0 = normal). Chart map BPM does not use this.
  Future<void> setPlaybackRate(double rate) async {
    if (!_useAudio) return;
    await _backing.setPlaybackRate(rate);
  }

  Future<void> pause() async {
    if (_useAudio && _musicPlaying) {
      await _backing.pause();
    }
  }

  Future<void> resume() async {
    if (_useAudio && _musicPlaying) {
      await _backing.resume();
    }
  }

  Future<void> stop() async {
    _musicPlaying = false;
    if (_useAudio) {
      await _backing.stop();
    }
    await _metronome.stop();
    await _guide.stop();
  }

  void resetMetronome() {
    _metronome.reset();
    _guide.reset();
  }

  Future<void> dispose() async {
    await _metronome.dispose();
    await _backing.dispose();
    await _guide.dispose();
  }
}
