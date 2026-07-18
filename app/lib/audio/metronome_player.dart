import 'package:just_audio/just_audio.dart';

import '../domain/song.dart';

/// Plays accent / normal click samples on beat boundaries.
class MetronomePlayer {
  MetronomePlayer({
    this.clickAsset = 'assets/audio/click.wav',
    this.accentAsset = 'assets/audio/click_accent.wav',
  });

  final String clickAsset;
  final String accentAsset;

  final AudioPlayer _click = AudioPlayer();
  final AudioPlayer _accent = AudioPlayer();

  bool _prepared = false;
  bool _enabled = true;
  double _volume = 0.7;
  int _beatsPerBar = 4;
  int? _lastClickedBeat;

  /// Current click gain 0–1. Zero skips playback (fully off).
  double get volume => _volume;

  bool get isAudible => _enabled && _volume > 0;

  Future<void> prepare(
    Song song, {
    double? volume,
  }) async {
    _beatsPerBar = song.timeSignature.isNotEmpty ? song.timeSignature[0] : 4;
    if (_beatsPerBar <= 0) _beatsPerBar = 4;

    final style = song.accompaniment.style;
    _enabled = style != 'none';
    // Prefer explicit user volume; fall back to song accompaniment default.
    _volume = (volume ?? song.accompaniment.volume).clamp(0.0, 1.0);

    if (!_enabled) {
      _prepared = true;
      return;
    }

    await Future.wait([
      _click.setAsset(clickAsset),
      _accent.setAsset(accentAsset),
    ]);
    await _applyVolume();
    _prepared = true;
    _lastClickedBeat = null;
  }

  /// Live volume change (0 = fully mute, no click scheduling work beyond skip).
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (!_prepared || !_enabled) return;
    await _applyVolume();
  }

  Future<void> _applyVolume() async {
    try {
      await Future.wait([
        _click.setVolume(_volume * 0.75),
        _accent.setVolume(_volume),
      ]);
    } catch (_) {}
  }

  /// Call on every clock tick. Fires at most once per integer beat.
  ///
  /// Clicks during count-in (`beat < 0`) and while playing.
  Future<void> onBeat(double beat) async {
    if (!_prepared || !_enabled || _volume <= 0) return;

    // Floor toward -inf so -0.1 → -1, 0.0 → 0, 3.9 → 3
    final integerBeat = beat.floor();

    // Only click once we've reached/passed that integer beat.
    if (_lastClickedBeat != null && integerBeat <= _lastClickedBeat!) {
      return;
    }

    // Skip if we jumped far ahead (pause/seek edge cases): click current only.
    _lastClickedBeat = integerBeat;

    final isAccent = _isAccent(integerBeat);
    final player = isAccent ? _accent : _click;
    try {
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {
      // Audio glitches should not crash the session.
    }
  }

  bool _isAccent(int integerBeat) {
    // Map count-in and song beats so bar starts accent.
    // Beat 0, 4, 8... and also -4, 0 aligned: accent when beat % bar == 0.
    final mod = integerBeat % _beatsPerBar;
    // In Dart, (-4) % 4 == 0, (-3) % 4 == -3 — normalize.
    final normalized = mod < 0 ? mod + _beatsPerBar : mod;
    return normalized == 0;
  }

  void reset() {
    _lastClickedBeat = null;
  }

  Future<void> stop() async {
    try {
      await _click.stop();
      await _accent.stop();
    } catch (_) {}
    _lastClickedBeat = null;
  }

  Future<void> dispose() async {
    await stop();
    await _click.dispose();
    await _accent.dispose();
  }
}
