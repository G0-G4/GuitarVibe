/// Tunable thresholds for recognition (single place to tweak).
class RecognitionConfig {
  const RecognitionConfig({
    this.rmsSilence = 0.022,
    this.chromaMinScore = 0.58,
    this.chromaMatchThreshold = 0.55,
    this.chromaMargin = 0.08,
    this.chromaMinConcentration = 0.48,
    this.chromaHoldMs = 140,
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

  static const standard = RecognitionConfig();
}
