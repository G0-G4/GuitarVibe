/// Tunable thresholds for recognition (single place to tweak).
class RecognitionConfig {
  const RecognitionConfig({
    this.rmsSilence = 0.012,
    this.chromaMinScore = 0.50,
    this.chromaMatchThreshold = 0.48,
    this.chromaMargin = 0.06,
    this.chromaMinConcentration = 0.42,
    this.chromaHoldMs = 100,
    this.holdMs = 100,
    this.yinMinConfidence = 0.80,
    this.medianWindow = 5,
  });

  /// RMS below this (0–1 float samples) → silence / no guess.
  final double rmsSilence;

  /// Minimum cosine score to show a free-lab guess.
  final double chromaMinScore;

  /// Minimum cosine vs *expected* template to count as a play-along hit.
  final double chromaMatchThreshold;

  /// top1 − top2 must exceed this or the frame is rejected (ambiguous/noise).
  final double chromaMargin;

  /// Top-3 chroma bins must hold at least this fraction of L1 energy.
  /// Flat noise fails; clear chords pass.
  final double chromaMinConcentration;

  /// Same chroma symbol must persist this long before free-lab shows it.
  final int chromaHoldMs;

  /// Min continuous match time for [RecognitionMode.pitchClassHeld].
  final int holdMs;

  final double yinMinConfidence;

  /// Odd window for median pitch-class smooth.
  final int medianWindow;

  /// Balanced defaults for uncalibrated use (usable without being noisy).
  static const balanced = RecognitionConfig();

  /// Alias kept for older call sites.
  static const standard = balanced;

  RecognitionConfig copyWith({
    double? rmsSilence,
    double? chromaMinScore,
    double? chromaMatchThreshold,
    double? chromaMargin,
    double? chromaMinConcentration,
    int? chromaHoldMs,
    int? holdMs,
    double? yinMinConfidence,
    int? medianWindow,
  }) {
    return RecognitionConfig(
      rmsSilence: rmsSilence ?? this.rmsSilence,
      chromaMinScore: chromaMinScore ?? this.chromaMinScore,
      chromaMatchThreshold: chromaMatchThreshold ?? this.chromaMatchThreshold,
      chromaMargin: chromaMargin ?? this.chromaMargin,
      chromaMinConcentration:
          chromaMinConcentration ?? this.chromaMinConcentration,
      chromaHoldMs: chromaHoldMs ?? this.chromaHoldMs,
      holdMs: holdMs ?? this.holdMs,
      yinMinConfidence: yinMinConfidence ?? this.yinMinConfidence,
      medianWindow: medianWindow ?? this.medianWindow,
    );
  }
}
