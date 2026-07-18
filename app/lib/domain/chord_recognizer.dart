// Pure chord recognition from AudioFeatures + mode.

import 'chord_guess.dart';
import 'chord_tones.dart';
import 'chroma.dart';
import 'recognition_config.dart';
import 'recognition_mode.dart';

/// Turns [AudioFeatures] into a [ChordGuess] and play-along match decisions.
class ChordRecognizer {
  ChordRecognizer({
    this.mode = RecognitionMode.chroma,
    this.config = RecognitionConfig.standard,
    this.allowedSymbols,
  });

  RecognitionMode mode;
  RecognitionConfig config;

  /// When non-null and non-empty, free chroma ranking is limited to these chords.
  Set<String>? allowedSymbols;

  // Hold filter state (pitchClassHeld).
  int? _holdPc;
  int _holdStartMs = 0;
  final List<int> _pcHistory = [];

  // Chroma free-guess hold (must stay stable before showing).
  String? _chromaHoldSymbol;
  int _chromaHoldStartMs = 0;

  void reset() {
    _holdPc = null;
    _holdStartMs = 0;
    _pcHistory.clear();
    _chromaHoldSymbol = null;
    _chromaHoldStartMs = 0;
  }

  /// Free recognition for Mic Lab.
  ChordGuess recognize(AudioFeatures f, {int nowMs = 0}) {
    if (f.rms < config.rmsSilence) {
      reset();
      return ChordGuess(
        rms: f.rms,
        chroma: f.chroma,
        yinHz: f.yinHz,
        yinConfidence: f.yinConfidence,
        isSilence: true,
      );
    }

    switch (mode) {
      case RecognitionMode.pitchClass:
        return _guessFromPitch(f, requireHold: false, nowMs: nowMs);
      case RecognitionMode.pitchClassHeld:
        return _guessFromPitch(f, requireHold: true, nowMs: nowMs);
      case RecognitionMode.chroma:
        return _guessFromChroma(f, nowMs: nowMs, requireYinSupport: false);
      case RecognitionMode.hybrid:
        return _guessFromChroma(
          f,
          nowMs: nowMs,
          requireYinSupport: config.requireYinForHybrid,
        );
    }
  }

  /// Whether features count as a hit for the expected song chord.
  bool matchesExpected(String expectedChord, AudioFeatures f, {int nowMs = 0}) {
    if (isNoChord(expectedChord)) return false;
    if (f.rms < config.rmsSilence) return false;

    switch (mode) {
      case RecognitionMode.pitchClass:
        return _pitchInChord(expectedChord, f, requireHold: false, nowMs: nowMs);
      case RecognitionMode.pitchClassHeld:
        return _pitchInChord(expectedChord, f, requireHold: true, nowMs: nowMs);
      case RecognitionMode.chroma:
        return _chromaMatchesExpected(expectedChord, f);
      case RecognitionMode.hybrid:
        // Hybrid play-along: chroma solid, or softer chroma + pitch tone.
        if (_chromaMatchesExpected(expectedChord, f)) return true;
        final soft = f.chroma.length == 12 &&
            isChromaTonal(
              f.chroma,
              minConcentration: config.chromaMinConcentration,
            ) &&
            chromaScoreForExpected(f.chroma, expectedChord) >=
                config.chromaMatchThreshold * 0.85;
        final pitchOk = _pitchInChord(
          expectedChord,
          f,
          requireHold: false,
          nowMs: nowMs,
        );
        return soft && pitchOk;
    }
  }

  bool _chromaMatchesExpected(String expected, AudioFeatures f) {
    if (f.chroma.length != 12) return false;
    if (!isChromaTonal(
      f.chroma,
      minConcentration: config.chromaMinConcentration,
    )) {
      return false;
    }
    return chromaScoreForExpected(f.chroma, expected) >=
        config.chromaMatchThreshold;
  }

  ChordGuess _guessFromPitch(
    AudioFeatures f, {
    required bool requireHold,
    required int nowMs,
  }) {
    final conf = f.yinConfidence ?? 0;
    final hz = f.yinHz;
    if (hz == null || conf < config.yinMinConfidence) {
      return ChordGuess(
        rms: f.rms,
        chroma: f.chroma,
        yinHz: hz,
        yinConfidence: conf,
        isSilence: false,
      );
    }

    var pc = pitchClassFromHz(hz);
    if (pc == null) {
      return ChordGuess(
        rms: f.rms,
        chroma: f.chroma,
        yinHz: hz,
        yinConfidence: conf,
        isSilence: false,
      );
    }

    if (requireHold) {
      pc = _smoothPc(pc);
      if (!_held(pc, nowMs)) {
        return ChordGuess(
          rms: f.rms,
          chroma: f.chroma,
          yinHz: hz,
          yinConfidence: conf,
          isSilence: false,
        );
      }
    }

    // Free mode: show pitch class as major root guess (honest monophonic limit).
    final symbol = chordSymbol(pc, '');
    return ChordGuess(
      symbol: symbol,
      confidence: conf,
      top: [RankedChord(symbol: symbol, score: conf)],
      chroma: f.chroma,
      yinHz: hz,
      yinConfidence: conf,
      rms: f.rms,
      isSilence: false,
    );
  }

  ChordGuess _guessFromChroma(
    AudioFeatures f, {
    required int nowMs,
    required bool requireYinSupport,
  }) {
    final empty = ChordGuess(
      rms: f.rms,
      chroma: f.chroma,
      yinHz: f.yinHz,
      yinConfidence: f.yinConfidence,
      isSilence: false,
    );

    if (f.chroma.length != 12) return empty;

    // Reject broadband / non-tonal frames (main noise false-positive source).
    if (!isChromaTonal(
      f.chroma,
      minConcentration: config.chromaMinConcentration,
    )) {
      _chromaHoldSymbol = null;
      final conc = chromaConcentration(f.chroma);
      return ChordGuess(
        rms: f.rms,
        chroma: f.chroma,
        yinHz: f.yinHz,
        yinConfidence: f.yinConfidence,
        isSilence: false,
        blockReason:
            'Flat spectrum (concentration ${conc.toStringAsFixed(2)} '
            '< ${config.chromaMinConcentration.toStringAsFixed(2)})',
      );
    }

    final ranked = rankChromaMatches(
      f.chroma,
      topK: 5,
      allowedSymbols: allowedSymbols,
    );
    if (ranked.isEmpty) {
      _chromaHoldSymbol = null;
      return empty;
    }

    final best = ranked.first;
    final second = ranked.length > 1 ? ranked[1].score : 0.0;
    // Smaller sets are less ambiguous — ease margin slightly.
    final marginNeed = (allowedSymbols != null && allowedSymbols!.length <= 8)
        ? config.chromaMargin * 0.5
        : config.chromaMargin;
    final margin = best.score - second;
    final top = [
      for (final r in ranked) RankedChord(symbol: r.symbol, score: r.score),
    ];

    // Hard reject weak or ambiguous frames (do not show a random "winner").
    if (best.score < config.chromaMinScore) {
      _chromaHoldSymbol = null;
      return ChordGuess(
        confidence: best.score,
        top: top,
        chroma: f.chroma,
        yinHz: f.yinHz,
        yinConfidence: f.yinConfidence,
        rms: f.rms,
        isSilence: false,
        blockReason:
            'Score ${best.score.toStringAsFixed(2)} < min '
            '${config.chromaMinScore.toStringAsFixed(2)} '
            '(top ${best.symbol})',
      );
    }
    if (margin < marginNeed) {
      _chromaHoldSymbol = null;
      final alt = ranked.length > 1 ? ranked[1].symbol : '?';
      return ChordGuess(
        confidence: best.score,
        top: top,
        chroma: f.chroma,
        yinHz: f.yinHz,
        yinConfidence: f.yinConfidence,
        rms: f.rms,
        isSilence: false,
        blockReason:
            'Ambiguous: ${best.symbol} vs $alt '
            '(margin ${margin.toStringAsFixed(2)} < '
            '${marginNeed.toStringAsFixed(2)})',
      );
    }

    if (requireYinSupport) {
      final conf = f.yinConfidence ?? 0;
      final hz = f.yinHz;
      if (hz == null || conf < config.yinMinConfidence) {
        // Keep ranking for UI but no committed symbol without pitch lock.
        _chromaHoldSymbol = null;
        return ChordGuess(
          confidence: best.score * 0.85,
          top: top,
          chroma: f.chroma,
          yinHz: hz,
          yinConfidence: conf,
          rms: f.rms,
          isSilence: false,
          blockReason:
              'Hybrid: need clear pitch (YIN). Turn off “Require pitch” '
              'or play a single note louder.',
        );
      }
      final pc = pitchClassFromHz(hz);
      final tones = pitchClassesForChord(best.symbol);
      if (pc == null || !tones.contains(pc)) {
        _chromaHoldSymbol = null;
        final heard = pc != null ? pitchClassNames[pc] : '?';
        return ChordGuess(
          confidence: best.score * 0.8,
          top: top,
          chroma: f.chroma,
          yinHz: hz,
          yinConfidence: conf,
          rms: f.rms,
          isSilence: false,
          blockReason:
              'Hybrid: pitch $heard not in ${best.symbol}. '
              'Lower strictness or disable pitch lock.',
        );
      }
    }

    // Temporal hold: symbol must stay stable across frames.
    if (!_chromaHeld(best.symbol, nowMs)) {
      return ChordGuess(
        confidence: best.score,
        top: top,
        chroma: f.chroma,
        yinHz: f.yinHz,
        yinConfidence: f.yinConfidence,
        rms: f.rms,
        isSilence: false,
        blockReason: 'Holding ${best.symbol}…',
      );
    }

    var conf = best.score;
    if (requireYinSupport) {
      conf = (conf + 0.08).clamp(0.0, 1.0);
    }

    return ChordGuess(
      symbol: best.symbol,
      confidence: conf,
      top: top,
      chroma: f.chroma,
      yinHz: f.yinHz,
      yinConfidence: f.yinConfidence,
      rms: f.rms,
      isSilence: false,
    );
  }

  bool _chromaHeld(String symbol, int nowMs) {
    if (_chromaHoldSymbol != symbol) {
      _chromaHoldSymbol = symbol;
      _chromaHoldStartMs = nowMs;
      return false;
    }
    return nowMs - _chromaHoldStartMs >= config.chromaHoldMs;
  }

  bool _pitchInChord(
    String expected,
    AudioFeatures f, {
    required bool requireHold,
    required int nowMs,
  }) {
    final conf = f.yinConfidence ?? 0;
    final hz = f.yinHz;
    if (hz == null || conf < config.yinMinConfidence) return false;
    var pc = pitchClassFromHz(hz);
    if (pc == null) return false;
    if (requireHold) {
      pc = _smoothPc(pc);
      if (!_held(pc, nowMs)) return false;
    }
    return pitchClassesForChord(expected).contains(pc);
  }

  int _smoothPc(int pc) {
    _pcHistory.add(pc);
    while (_pcHistory.length > config.medianWindow) {
      _pcHistory.removeAt(0);
    }
    final sorted = [..._pcHistory]..sort();
    return sorted[sorted.length ~/ 2];
  }

  bool _held(int pc, int nowMs) {
    if (_holdPc != pc) {
      _holdPc = pc;
      _holdStartMs = nowMs;
      return false;
    }
    return nowMs - _holdStartMs >= config.holdMs;
  }
}
