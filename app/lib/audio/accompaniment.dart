import '../domain/song.dart';
import 'backing_audio_player.dart';
import 'metronome_player.dart';

/// Facade: prefer backing audio when present, else metronome.
///
/// Count-in always uses the metronome (when style ≠ `none`) so the user
/// can lock in before a backing track starts.
class Accompaniment {
  Accompaniment({
    MetronomePlayer? metronome,
    BackingAudioPlayer? backing,
  })  : _metronome = metronome ?? MetronomePlayer(),
        _backing = backing ?? BackingAudioPlayer();

  final MetronomePlayer _metronome;
  final BackingAudioPlayer _backing;

  bool _useAudio = false;
  bool _musicPlaying = false;

  bool get usesAudioMaster => _useAudio;

  BackingAudioPlayer get backing => _backing;

  Future<void> prepare(Song song) async {
    _useAudio = song.hasAudio;
    _musicPlaying = false;

    // Metronome for count-in (and full session when no audio).
    await _metronome.prepare(song);

    if (_useAudio) {
      await _backing.prepare(song);
    }
  }

  /// Called every clock tick with the current song beat (may be negative).
  Future<void> onBeat(double beat) async {
    // With backing audio as master after music starts, skip click track.
    if (_useAudio && _musicPlaying) return;
    await _metronome.onBeat(beat);
  }

  /// When song music starts (beat >= 0).
  Future<void> startMusicAtBeat(double beat) async {
    if (_useAudio) {
      _musicPlaying = true;
      await _backing.startAtBeat(beat);
    }
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
  }

  void resetMetronome() => _metronome.reset();

  Future<void> dispose() async {
    await _metronome.dispose();
    await _backing.dispose();
  }
}
