import 'dart:async';

import '../domain/guide_schedule.dart';
import '../domain/song.dart';
import 'guitar_sample_bank.dart';

/// Synthetic guitar reference: soft pad on chord change + strum pattern hits.
///
/// Uses a [GuitarSampleBank] preloaded at session start so the clock tick
/// never does asset I/O (that was freezing the UI with open-chord polyphony).
class GuitarGuidePlayer {
  GuitarGuidePlayer({GuitarSampleBank? bank})
      : _bank = bank ?? GuitarSampleBank();

  final GuitarSampleBank _bank;
  final GuideScheduler _scheduler = GuideScheduler();

  bool _prepared = false;
  bool _enabled = true;
  double _volume = 0.55;
  Song? _song;

  /// When song has a strum pattern, skip pad entirely (strums carry harmony).
  static const double padSoloScale = 0.48;
  static const double strumDownScale = 0.78;
  static const double strumUpScale = 0.58;
  static const double muteDownScale = 0.85;
  static const double muteUpScale = 0.70;

  /// Cap strings per hit to keep macOS audio + UI smooth.
  static const int maxStringsPerHit = 4;

  /// Strum sweep across strings (ms between notes).
  static const int strumDownStaggerMs = 12;
  static const int strumUpStaggerMs = 10;

  double get volume => _volume;

  bool get isAudible => _enabled && _volume > 0;

  Future<void> prepare(
    Song song, {
    double? volume,
  }) async {
    _song = song;
    final style = song.accompaniment.style;
    _enabled = style != 'none';
    _volume = (volume ?? song.accompaniment.volume).clamp(0.0, 1.0);
    _scheduler.reset();

    if (!_enabled) {
      _prepared = true;
      return;
    }

    await _bank.prepare(song);
    _prepared = true;
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
  }

  void reset() => _scheduler.reset();

  /// Call on every clock tick. Intentionally non-blocking after scheduling.
  Future<void> onBeat(double beat) async {
    if (!_prepared || !_enabled || _volume <= 0) return;
    final song = _song;
    if (song == null) return;

    final actions = _scheduler.actionsFor(song, beat);
    if (!actions.hasPad && !actions.hasStrum) return;

    final hasStrumPattern = song.hasStrum;

    // With a strum pattern, skip pad — it doubled polyphony and muddied audio.
    if (actions.hasPad && !hasStrumPattern) {
      _playNotes(
        actions.padNotes,
        volume: _volume * padSoloScale,
        staggerMs: 4,
        bassHeavy: true,
      );
    }

    if (actions.mute) {
      _bank.playMute(
        upstroke: actions.muteUp,
        volume: _volume * (actions.muteUp ? muteUpScale : muteDownScale),
      );
      return;
    }

    if (actions.hasStrum) {
      final token = (actions.strumToken ?? 'D').toUpperCase();
      final isUp = token == 'U';
      _playNotes(
        actions.strumNotes,
        volume: _volume * (isUp ? strumUpScale : strumDownScale),
        staggerMs: isUp ? strumUpStaggerMs : strumDownStaggerMs,
        bassHeavy: !isUp,
        trebleHeavy: isUp,
      );
    }
  }

  void _playNotes(
    List<int> midiNotes, {
    required double volume,
    int staggerMs = 0,
    bool bassHeavy = false,
    bool trebleHeavy = false,
  }) {
    if (midiNotes.isEmpty || volume <= 0) return;

    // Thin open voicings (often 5–6 strings) for CPU.
    final notes = midiNotes.length > maxStringsPerHit
        ? _thin(midiNotes, maxStringsPerHit)
        : midiNotes;

    final n = notes.length;
    for (var i = 0; i < n; i++) {
      var stringGain = 1.0;
      if (n > 1) {
        final t = i / (n - 1);
        if (bassHeavy) {
          stringGain = 1.05 - 0.22 * t;
        } else if (trebleHeavy) {
          stringGain = 0.72 + 0.35 * t;
        } else {
          stringGain = 1.0 - 0.08 * t;
        }
      }
      final noteGain = (volume * stringGain).clamp(0.05, 1.0);
      final midi = notes[i];

      if (staggerMs > 0 && i > 0) {
        final delay = Duration(milliseconds: staggerMs * i);
        unawaited(Future<void>.delayed(delay, () {
          if (!_prepared) return;
          _bank.playNote(midi, volume: noteGain);
        }));
      } else {
        _bank.playNote(midi, volume: noteGain);
      }
    }
  }

  /// Keep bass + treble + evenly spaced middles (same idea as domain thin).
  List<int> _thin(List<int> sorted, int maxNotes) {
    if (sorted.length <= maxNotes) return sorted;
    if (maxNotes <= 1) return [sorted.first];
    if (maxNotes == 2) return [sorted.first, sorted.last];
    final out = <int>{sorted.first, sorted.last};
    final inner = maxNotes - 2;
    for (var k = 1; k <= inner; k++) {
      final t = k / (inner + 1);
      final idx = (t * (sorted.length - 1)).round().clamp(0, sorted.length - 1);
      out.add(sorted[idx]);
    }
    final list = out.toList()..sort();
    return list.take(maxNotes).toList();
  }

  Future<void> stop() async {
    _scheduler.reset();
    await _bank.stopAll();
  }

  Future<void> dispose() async {
    _prepared = false;
    _song = null;
    await _bank.dispose();
  }
}
