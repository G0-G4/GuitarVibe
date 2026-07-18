import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Small pool of [AudioPlayer]s for overlapping one-shot samples.
///
/// Round-robin so rapid strums do not cut the previous note entirely.
class SampleVoicePool {
  SampleVoicePool({this.voiceCount = 12});

  final int voiceCount;
  final List<AudioPlayer> _players = [];
  int _next = 0;
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> prepare() async {
    if (_ready) return;
    for (var i = 0; i < voiceCount; i++) {
      _players.add(AudioPlayer());
    }
    _ready = true;
  }

  /// Play [asset] at [volume] (0–1). Fire-and-forget safe.
  Future<void> play(String asset, {double volume = 1.0}) async {
    if (!_ready || _players.isEmpty) return;
    final v = volume.clamp(0.0, 1.0);
    if (v <= 0) return;

    final player = _players[_next];
    _next = (_next + 1) % _players.length;

    try {
      // Stop previous voice content, load asset, play from start.
      await player.stop();
      await player.setAsset(asset);
      await player.setVolume(v);
      await player.seek(Duration.zero);
      // Don't await full playback — only start.
      unawaited(player.play());
    } catch (_) {
      // Audio glitches must not crash the session.
    }
  }

  Future<void> stopAll() async {
    for (final p in _players) {
      try {
        await p.stop();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await stopAll();
    for (final p in _players) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _players.clear();
    _ready = false;
  }
}
