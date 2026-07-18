import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../domain/guide_voicing.dart';
import '../domain/song.dart';

/// Preloaded one-shot guitar samples for low-latency guide playback.
///
/// Loads each needed note **once** at [prepare]. Hot path only seeks + plays
/// (no per-hit `setAsset`, which was stalling the UI isolate).
class GuitarSampleBank {
  GuitarSampleBank();

  final Map<int, _VoicePair> _notes = {};
  AudioPlayer? _mute;
  AudioPlayer? _muteUp;
  bool _ready = false;

  bool get isReady => _ready;

  /// Preload mute samples + every MIDI used by [song] chord events.
  Future<void> prepare(Song song) async {
    await dispose();

    final midis = <int>{};
    for (final e in song.allEvents) {
      midis.addAll(midiNotesForChord(e.chord, maxNotes: 5));
    }
    // Always keep a small mid-range set so mutes/unknown chords still work.
    midis.addAll(const [45, 52, 57, 60, 64]);

    final load = <Future<void>>[];

    for (final midi in midis) {
      final asset = guitarSampleAssetForMidi(midi);
      if (asset == null) continue;
      final pair = _VoicePair();
      _notes[midi] = pair;
      load.add(pair.load(asset));
    }

    final mute = AudioPlayer();
    final muteUp = AudioPlayer();
    _mute = mute;
    _muteUp = muteUp;
    load.add(mute.setAsset(guitarMuteAsset));
    load.add(muteUp.setAsset(guitarMuteUpAsset));

    await Future.wait(load);
    _ready = true;
  }

  /// Fire-and-forget note. Safe from the clock tick (does not await I/O).
  void playNote(int midi, {required double volume}) {
    if (!_ready) return;
    final v = volume.clamp(0.0, 1.0);
    if (v <= 0) return;
    final pair = _notes[midi];
    if (pair == null) return;
    pair.trigger(v);
  }

  void playMute({required bool upstroke, required double volume}) {
    if (!_ready) return;
    final v = volume.clamp(0.0, 1.0);
    if (v <= 0) return;
    final player = upstroke ? _muteUp : _mute;
    if (player == null) return;
    unawaited(_triggerPlayer(player, v));
  }

  Future<void> stopAll() async {
    final futures = <Future<void>>[];
    for (final pair in _notes.values) {
      futures.add(pair.stop());
    }
    final m = _mute;
    final u = _muteUp;
    if (m != null) futures.add(m.stop());
    if (u != null) futures.add(u.stop());
    await Future.wait(futures);
  }

  Future<void> dispose() async {
    _ready = false;
    await stopAll();
    for (final pair in _notes.values) {
      await pair.dispose();
    }
    _notes.clear();
    try {
      await _mute?.dispose();
    } catch (_) {}
    try {
      await _muteUp?.dispose();
    } catch (_) {}
    _mute = null;
    _muteUp = null;
  }
}

/// Two players per pitch so rapid re-triggers do not fully cut the previous.
class _VoicePair {
  final AudioPlayer _a = AudioPlayer();
  final AudioPlayer _b = AudioPlayer();
  bool _useA = true;

  Future<void> load(String asset) async {
    await Future.wait([
      _a.setAsset(asset),
      _b.setAsset(asset),
    ]);
  }

  void trigger(double volume) {
    final player = _useA ? _a : _b;
    _useA = !_useA;
    unawaited(_triggerPlayer(player, volume));
  }

  Future<void> stop() async {
    try {
      await Future.wait([_a.stop(), _b.stop()]);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    try {
      await _a.dispose();
    } catch (_) {}
    try {
      await _b.dispose();
    } catch (_) {}
  }
}

Future<void> _triggerPlayer(AudioPlayer player, double volume) async {
  try {
    // Order: volume first, then restart. Avoid stop() — seek(0)+play is enough
    // and cheaper on most platforms.
    await player.setVolume(volume);
    await player.seek(Duration.zero);
    unawaited(player.play());
  } catch (_) {
    // Audio glitches must not crash the session / jank the UI further.
  }
}
