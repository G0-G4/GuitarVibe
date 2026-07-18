// User-tunable recognition thresholds (persisted separately from calibration).

import 'recognition_config.dart';

/// Manual overrides applied on top of calibration-derived config.
class ThresholdPrefs {
  const ThresholdPrefs({
    this.sensitivity = 0.55,
    this.chromaMinScore,
    this.chromaMargin,
    this.chromaMinConcentration,
    this.chromaHoldMs,
    this.rmsSilence,
    this.requireYinForHybrid = true,
    this.useAdvanced = false,
  });

  /// 0.0 = very sensitive (easy activate), 1.0 = strict (few false hits).
  /// Used when [useAdvanced] is false.
  final double sensitivity;

  /// When true, explicit fields below override the sensitivity curve.
  final bool useAdvanced;

  final double? chromaMinScore;
  final double? chromaMargin;
  final double? chromaMinConcentration;
  final int? chromaHoldMs;
  final double? rmsSilence;

  /// Hybrid free-guess: require YIN pitch ∈ chord tones before activating.
  final bool requireYinForHybrid;

  static const defaults = ThresholdPrefs();

  ThresholdPrefs copyWith({
    double? sensitivity,
    bool? useAdvanced,
    double? chromaMinScore,
    double? chromaMargin,
    double? chromaMinConcentration,
    int? chromaHoldMs,
    double? rmsSilence,
    bool? requireYinForHybrid,
    bool clearChromaMinScore = false,
    bool clearChromaMargin = false,
    bool clearConcentration = false,
    bool clearHoldMs = false,
    bool clearRmsSilence = false,
  }) {
    return ThresholdPrefs(
      sensitivity: sensitivity ?? this.sensitivity,
      useAdvanced: useAdvanced ?? this.useAdvanced,
      chromaMinScore:
          clearChromaMinScore ? null : (chromaMinScore ?? this.chromaMinScore),
      chromaMargin:
          clearChromaMargin ? null : (chromaMargin ?? this.chromaMargin),
      chromaMinConcentration: clearConcentration
          ? null
          : (chromaMinConcentration ?? this.chromaMinConcentration),
      chromaHoldMs: clearHoldMs ? null : (chromaHoldMs ?? this.chromaHoldMs),
      rmsSilence: clearRmsSilence ? null : (rmsSilence ?? this.rmsSilence),
      requireYinForHybrid: requireYinForHybrid ?? this.requireYinForHybrid,
    );
  }

  /// Map sensitivity 0..1 → concrete chroma thresholds.
  RecognitionConfig configFromSensitivity(RecognitionConfig base) {
    final s = sensitivity.clamp(0.0, 1.0);
    // Easy ←——————————————————————————————→ Strict
    final minScore = _lerp(0.38, 0.62, s);
    final margin = _lerp(0.02, 0.12, s);
    final conc = _lerp(0.32, 0.52, s);
    final hold = _lerp(40, 200, s).round();
    // Gate: slightly lower when sensitive (easier to open).
    final gateScale = _lerp(0.75, 1.25, s);

    return base.copyWith(
      chromaMinScore: minScore,
      chromaMatchThreshold: (minScore - 0.02).clamp(0.30, 0.70),
      chromaMargin: margin,
      chromaMinConcentration: conc,
      chromaHoldMs: hold,
      rmsSilence: (base.rmsSilence * gateScale).clamp(0.005, 0.10),
    );
  }

  /// Apply prefs on top of a calibration-derived base config.
  RecognitionConfig applyTo(RecognitionConfig base) {
    if (!useAdvanced) {
      return configFromSensitivity(base);
    }

    return base.copyWith(
      chromaMinScore: chromaMinScore ?? base.chromaMinScore,
      chromaMatchThreshold: chromaMinScore != null
          ? (chromaMinScore! - 0.02).clamp(0.30, 0.70)
          : base.chromaMatchThreshold,
      chromaMargin: chromaMargin ?? base.chromaMargin,
      chromaMinConcentration:
          chromaMinConcentration ?? base.chromaMinConcentration,
      chromaHoldMs: chromaHoldMs ?? base.chromaHoldMs,
      rmsSilence: rmsSilence ?? base.rmsSilence,
    );
  }

  Map<String, dynamic> toJson() => {
        'sensitivity': sensitivity,
        'useAdvanced': useAdvanced,
        if (chromaMinScore != null) 'chromaMinScore': chromaMinScore,
        if (chromaMargin != null) 'chromaMargin': chromaMargin,
        if (chromaMinConcentration != null)
          'chromaMinConcentration': chromaMinConcentration,
        if (chromaHoldMs != null) 'chromaHoldMs': chromaHoldMs,
        if (rmsSilence != null) 'rmsSilence': rmsSilence,
        'requireYinForHybrid': requireYinForHybrid,
      };

  factory ThresholdPrefs.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return ThresholdPrefs(
      sensitivity: (json['sensitivity'] as num?)?.toDouble() ?? 0.55,
      useAdvanced: json['useAdvanced'] as bool? ?? false,
      chromaMinScore: (json['chromaMinScore'] as num?)?.toDouble(),
      chromaMargin: (json['chromaMargin'] as num?)?.toDouble(),
      chromaMinConcentration:
          (json['chromaMinConcentration'] as num?)?.toDouble(),
      chromaHoldMs: (json['chromaHoldMs'] as num?)?.toInt(),
      rmsSilence: (json['rmsSilence'] as num?)?.toDouble(),
      requireYinForHybrid: json['requireYinForHybrid'] as bool? ?? true,
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
