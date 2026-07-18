import 'dart:async';

import '../domain/guide_schedule.dart';
import '../domain/guide_voicing.dart';
import '../domain/song.dart';
import 'sample_voice_pool.dart';

/// Synthetic guitar reference: soft pad on chord change + strum pattern hits.
///
/// Uses bundled Karplus–Strong pluck samples (`assets/audio/guitar/`).
class GuitarGuidePlayer {
  GuitarGuidePlayer({SampleVoicePool? pool}) : _pool = pool ?? SampleVoicePool();

  final SampleVoicePool _pool;
  final GuideScheduler _scheduler = GuideScheduler();

  bool _prepared = false;
  bool _enabled = true;
  double _volume = 0.55;
  Song? _song;

  /// When song has a strum pattern, pad is quieter so attacks dominate.
  static const double padWithStrumScale = 0.32;
  static const double padSoloScale = 0.55;
  static const double strumNoteScale = 0.72;
  static const double muteScale = 0.55;

  /// Stagger between notes in a strum (ms).
  static const int strumStaggerMs = 16;

  double get volume => _volume;

  bool get isAudible => _enabled && _volume > 0;

  Future<void> prepare(
    Song song, {
    double? volume,
  }) async {
    _song = song;
    final style = song.accompaniment.style;
    // Guide follows pad-style songs; also allow plain metronome style.
    _enabled = style != 'none';
    _volume = (volume ?? song.accompaniment.volume).clamp(0.0, 1.0);
    _scheduler.reset();

    if (!_enabled) {
      _prepared = true;
      return;
    }

    await _pool.prepare();
    _prepared = true;
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
  }

  void reset() => _scheduler.reset();

  /// Call on every clock tick with current song beat.
  Future<void> onBeat(double beat) async {
    if (!_prepared || !_enabled || _volume <= 0) return;
    final song = _song;
    if (song == null) return;

    final actions = _scheduler.actionsFor(song, beat);
    if (!actions.hasPad && !actions.hasStrum) return;

    final hasStrumPattern = song.hasStrum;

    if (actions.hasPad) {
      final scale = hasStrumPattern ? padWithStrumScale : padSoloScale;
      await _playNotes(
        actions.padNotes,
        volume: _volume * scale,
        staggerMs: hasStrumPattern ? 0 : 12,
      );
    }

    if (actions.mute) {
      await _pool.play(
        guitarMuteAsset,
        volume: _volume * muteScale,
      );
      return;
    }

    if (actions.hasStrum) {
      await _playNotes(
        actions.strumNotes,
        volume: _volume * strumNoteScale,
        staggerMs: strumStaggerMs,
      );
    }
  }

  Future<void> _playNotes(
    List<int> midiNotes, {
    required double volume,
    int staggerMs = 0,
  }) async {
    if (midiNotes.isEmpty || volume <= 0) return;

    for (var i = 0; i < midiNotes.length; i++) {
      final asset = guitarSampleAssetForMidi(midiNotes[i]);
      if (asset == null) continue;
      // Slight roll-off on upper notes so strums aren't piercing.
      final noteGain = volume * (1.0 - i * 0.06).clamp(0.55, 1.0);
      if (staggerMs > 0 && i > 0) {
        final delay = Duration(milliseconds: staggerMs * i);
        unawaited(Future<void>.delayed(delay, () async {
          if (!_prepared) return;
          await _pool.play(asset, volume: noteGain);
        }));
      } else {
        await _pool.play(asset, volume: noteGain);
      }
    }
  }

  Future<void> stop() async {
    _scheduler.reset();
    await _pool.stopAll();
  }

  Future<void> dispose() async {
    _prepared = false;
    _song = null;
    await _pool.dispose();
  }
}
