/// One ranked chord candidate from free recognition.
class RankedChord {
  const RankedChord({
    required this.symbol,
    required this.score,
  });

  final String symbol;
  final double score; // 0–1 similarity
}

/// Latest recognition result for UI / scoring.
class ChordGuess {
  const ChordGuess({
    this.symbol,
    this.confidence = 0,
    this.top = const [],
    this.chroma = const [],
    this.yinHz,
    this.yinConfidence,
    this.rms = 0,
    this.isSilence = true,
    this.blockReason,
  });

  /// Best guess symbol, e.g. `Am`, or null if silence/unknown.
  final String? symbol;
  final double confidence;
  final List<RankedChord> top;

  /// Length-12 chroma (may be empty if not computed).
  final List<double> chroma;

  final double? yinHz;
  final double? yinConfidence;
  final double rms;
  final bool isSilence;

  /// Why [symbol] is null despite having rankings (for Mic Lab debugging).
  final String? blockReason;

  static const silence = ChordGuess();
}

/// Features extracted from one PCM analysis frame (domain-level, no Flutter).
class AudioFeatures {
  const AudioFeatures({
    required this.rms,
    required this.chroma,
    this.chromaRaw = const [],
    this.yinHz,
    this.yinConfidence,
  });

  final double rms;

  /// Length 12, non-negative; preferably L2-normalized (after noise subtract).
  final List<double> chroma;

  /// Pre-normalize chroma energy (for calibration / debugging).
  final List<double> chromaRaw;

  final double? yinHz;
  final double? yinConfidence;
}
