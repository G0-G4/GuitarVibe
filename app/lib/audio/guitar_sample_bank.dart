import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../domain/guide_voicing.dart';
import '../domain/song.dart';

/// How aggressively a previous hit should yield to the next event.
enum NoteReleaseStyle {
  /// Next strum: residual under the new attack (crossfade feel).
  stroke,

  /// Pad chord change: slightly longer hand-off.
  pad,

  /// Palm mute: quick ease-out without a digital click.
  mute,
}

/// Preloaded one-shot guitar samples for low-latency guide playback.
///
/// Loads each needed note **once** at [prepare]. Hot path only seeks + plays
/// (no per-hit `setAsset`). Soft-release uses few fire-and-forget platform
/// calls so the UI isolate is not flooded with sequential `setVolume` awaits.
class GuitarSampleBank {
  GuitarSampleBank();

  final Map<int, _VoicePair> _notes = {};
  AudioPlayer? _mute;
  AudioPlayer? _muteUp;
  bool _ready = false;

  /// Voices started by recent hits; dampen/silence only touch these.
  final List<_VoiceSlot> _ringing = [];

  bool get isReady => _ready;

  /// Preload mute samples + every MIDI used by [song] chord events.
  Future<void> prepare(Song song) async {
    await dispose();

    final midis = <int>{};
    for (final e in song.allEvents) {
      midis.addAll(midiNotesForChord(e.chord, maxNotes: 5));
    }
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
    final slot = pair.trigger(v);
    _ringing.add(slot);
  }

  /// Soft-release currently ringing notes under the next hit.
  ///
  /// When [afterNewAttack] is true (default), release is deferred to a
  /// microtask so the caller can start the new stroke first.
  void dampenNotes({
    NoteReleaseStyle style = NoteReleaseStyle.stroke,
    bool afterNewAttack = true,
  }) {
    if (!_ready || _ringing.isEmpty) return;
    final prev = List<_VoiceSlot>.of(_ringing);
    _ringing.clear();

    void release() {
      for (var i = 0; i < prev.length; i++) {
        final bias = prev.length <= 1 ? 0.0 : i / (prev.length - 1);
        prev[i].softRelease(style: style, stringBias: bias);
      }
    }

    if (afterNewAttack) {
      scheduleMicrotask(release);
    } else {
      release();
    }
  }

  /// Hard stop of currently ringing note voices.
  void silenceNotes() {
    if (!_ready || _ringing.isEmpty) return;
    final prev = List<_VoiceSlot>.of(_ringing);
    _ringing.clear();
    for (final slot in prev) {
      unawaited(slot.hardStop());
    }
  }

  /// Palm mute: quickly ease out ringing notes.
  ///
  /// Optional quiet chuck when [volume] &gt; 0; pass 0 for silence-only.
  void playMute({required bool upstroke, required double volume}) {
    if (!_ready) return;

    if (_ringing.isNotEmpty) {
      final prev = List<_VoiceSlot>.of(_ringing);
      _ringing.clear();
      for (final slot in prev) {
        slot.softRelease(style: NoteReleaseStyle.mute);
      }
    }

    final v = volume.clamp(0.0, 1.0);
    if (v <= 0.001) return;

    final player = upstroke ? _muteUp : _mute;
    if (player == null) return;
    unawaited(_startPlayer(player, v));
  }

  Future<void> stopAll() async {
    _ringing.clear();
    final futures = <Future<void>>[];
    for (final pair in _notes.values) {
      futures.add(pair.stopBoth());
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

/// Two alternating slots per pitch so old ring can fade under a new hit.
class _VoicePair {
  final _VoiceSlot a = _VoiceSlot();
  final _VoiceSlot b = _VoiceSlot();
  bool _useA = true;

  Future<void> load(String asset) async {
    await Future.wait([a.load(asset), b.load(asset)]);
  }

  _VoiceSlot trigger(double volume) {
    final slot = _useA ? a : b;
    _useA = !_useA;
    slot.start(volume);
    return slot;
  }

  Future<void> stopBoth() async {
    await Future.wait([a.hardStop(), b.hardStop()]);
  }

  Future<void> dispose() async {
    await stopBoth();
    await a.dispose();
    await b.dispose();
  }
}

/// One [AudioPlayer] with a generation id so release is cancelled on re-trigger.
class _VoiceSlot {
  final AudioPlayer player = AudioPlayer();
  int _gen = 0;
  double _peak = 0;
  Timer? _releaseTimer1;
  Timer? _releaseTimer2;

  Future<void> load(String asset) => player.setAsset(asset);

  void start(double volume) {
    _cancelReleaseTimers();
    _gen++;
    final id = _gen;
    _peak = volume;
    unawaited(_start(id, volume));
  }

  Future<void> _start(int id, double volume) async {
    try {
      if (id != _gen) return;
      await player.setVolume(volume);
      if (id != _gen) return;
      await player.seek(Duration.zero);
      if (id != _gen) return;
      unawaited(player.play());
    } catch (_) {}
  }

  /// Cheap residual: 1–2 fire-and-forget `setVolume` + delayed `stop`.
  ///
  /// Avoids multi-step await loops that flood the UI isolate with platform
  /// channel completions on every stroke.
  void softRelease({
    NoteReleaseStyle style = NoteReleaseStyle.stroke,
    double stringBias = 0,
  }) {
    final id = _gen;
    final peak = _peak;
    if (peak <= 0) return;

    _cancelReleaseTimers();

    final bias = stringBias.clamp(0.0, 1.0);
    // Bass lingers slightly; treble tucks sooner.
    final linger = 1.0 + 0.12 * (1.0 - bias);
    final bright = 1.0 - 0.06 * bias;

    late final double g1;
    late final double g2;
    late final int ms1;
    late final int ms2;

    switch (style) {
      case NoteReleaseStyle.stroke:
        // ~220 ms total, 2 volume steps — continuous enough, cheap.
        g1 = 0.48 * bright;
        g2 = 0.14 * bright;
        ms1 = (85 * linger).round();
        ms2 = (130 * linger).round();
      case NoteReleaseStyle.pad:
        g1 = 0.58 * bright;
        g2 = 0.18 * bright;
        ms1 = (100 * linger).round();
        ms2 = (160 * linger).round();
      case NoteReleaseStyle.mute:
        // Single drop then stop — mute sample is usually off.
        g1 = 0.18;
        g2 = 0.0;
        ms1 = 18;
        ms2 = 28;
    }

    // First drop immediately (no await chain on this call stack).
    unawaited(_setVol(peak * g1));

    _releaseTimer1 = Timer(Duration(milliseconds: ms1), () {
      if (id != _gen) return;
      if (g2 > 0) {
        unawaited(_setVol(peak * g2));
      } else {
        unawaited(player.stop());
      }
    });

    if (g2 > 0) {
      _releaseTimer2 = Timer(Duration(milliseconds: ms1 + ms2), () {
        if (id != _gen) return;
        unawaited(player.stop());
      });
    }
  }

  Future<void> _setVol(double v) async {
    try {
      await player.setVolume(v.clamp(0.0, 1.0));
    } catch (_) {}
  }

  void _cancelReleaseTimers() {
    _releaseTimer1?.cancel();
    _releaseTimer2?.cancel();
    _releaseTimer1 = null;
    _releaseTimer2 = null;
  }

  Future<void> hardStop() async {
    _cancelReleaseTimers();
    _gen++;
    _peak = 0;
    try {
      await player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await hardStop();
    try {
      await player.dispose();
    } catch (_) {}
  }
}

Future<void> _startPlayer(AudioPlayer player, double volume) async {
  try {
    await player.setVolume(volume);
    await player.seek(Duration.zero);
    unawaited(player.play());
  } catch (_) {
    // Audio glitches must not crash the session / jank the UI further.
  }
}
