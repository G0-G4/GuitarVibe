// Room + guitar level calibration profiles and adaptive thresholds.

import 'recognition_config.dart';

/// Measured ambient noise (room) for gating and chroma subtraction.
class NoiseProfile {
  const NoiseProfile({
    required this.rmsMean,
    required this.rmsP95,
    required this.chromaMean,
    required this.calibratedAt,
  });

  final double rmsMean;
  final double rmsP95;

  /// Mean **raw** (pre-normalize) chroma energy, length 12.
  final List<double> chromaMean;
  final DateTime calibratedAt;

  Map<String, dynamic> toJson() => {
        'rmsMean': rmsMean,
        'rmsP95': rmsP95,
        'chromaMean': chromaMean,
        'calibratedAt': calibratedAt.toIso8601String(),
      };

  factory NoiseProfile.fromJson(Map<String, dynamic> json) {
    final raw = json['chromaMean'] as List<dynamic>? ?? const [];
    return NoiseProfile(
      rmsMean: (json['rmsMean'] as num?)?.toDouble() ?? 0,
      rmsP95: (json['rmsP95'] as num?)?.toDouble() ?? 0,
      chromaMean: raw.map((e) => (e as num).toDouble()).toList(),
      calibratedAt: DateTime.tryParse(json['calibratedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Typical playing loudness (optional second step).
class GuitarLevelProfile {
  const GuitarLevelProfile({
    required this.rmsMedian,
    required this.calibratedAt,
  });

  final double rmsMedian;
  final DateTime calibratedAt;

  Map<String, dynamic> toJson() => {
        'rmsMedian': rmsMedian,
        'calibratedAt': calibratedAt.toIso8601String(),
      };

  factory GuitarLevelProfile.fromJson(Map<String, dynamic> json) {
    return GuitarLevelProfile(
      rmsMedian: (json['rmsMedian'] as num?)?.toDouble() ?? 0,
      calibratedAt: DateTime.tryParse(json['calibratedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Persisted calibration state.
class CalibrationBundle {
  const CalibrationBundle({this.noise, this.guitar});

  final NoiseProfile? noise;
  final GuitarLevelProfile? guitar;

  bool get hasNoise => noise != null;
  bool get hasGuitar => guitar != null;
  bool get isEmpty => noise == null && guitar == null;

  CalibrationBundle copyWith({
    NoiseProfile? noise,
    GuitarLevelProfile? guitar,
    bool clearNoise = false,
    bool clearGuitar = false,
  }) {
    return CalibrationBundle(
      noise: clearNoise ? null : (noise ?? this.noise),
      guitar: clearGuitar ? null : (guitar ?? this.guitar),
    );
  }

  Map<String, dynamic> toJson() => {
        if (noise != null) 'noise': noise!.toJson(),
        if (guitar != null) 'guitar': guitar!.toJson(),
      };

  factory CalibrationBundle.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CalibrationBundle();
    final n = json['noise'];
    final g = json['guitar'];
    return CalibrationBundle(
      noise: n is Map<String, dynamic> ? NoiseProfile.fromJson(n) : null,
      guitar: g is Map<String, dynamic> ? GuitarLevelProfile.fromJson(g) : null,
    );
  }

  static const empty = CalibrationBundle();
}

/// One analysis frame sample used while calibrating.
class CalibrationFrame {
  const CalibrationFrame({
    required this.rms,
    required this.chromaRaw,
  });

  final double rms;
  final List<double> chromaRaw;
}

/// Build a noise profile from quiet frames.
///
/// Rejects loud outliers (speech). Returns null if the room is too loud
/// overall, too few good frames, or too many spikes.
NoiseProfile? buildNoiseProfile(
  List<CalibrationFrame> frames, {
  DateTime? now,
  double maxOutlierFraction = 0.35,
  int minGoodFrames = 8,
  double maxQuietMedian = 0.06,
}) {
  if (frames.length < minGoodFrames) return null;

  final rmsList = frames.map((f) => f.rms).toList()..sort();
  final median = _percentile(rmsList, 0.50);
  // Room cal must be mostly quiet; fail if ambient is already high.
  if (median > maxQuietMedian) return null;

  // Spikes: speech/claps above quiet baseline.
  final threshold = (median * 3.0).clamp(median + 0.008, 0.2);
  final good = frames.where((f) => f.rms <= threshold).toList();
  final outlierFrac = 1.0 - good.length / frames.length;
  if (outlierFrac > maxOutlierFraction) return null;
  if (good.length < minGoodFrames) return null;

  final goodRms = good.map((f) => f.rms).toList()..sort();
  final mean = goodRms.reduce((a, b) => a + b) / goodRms.length;
  final p95 = _percentile(goodRms, 0.95);

  final chromaSum = List<double>.filled(12, 0);
  var chromaCount = 0;
  for (final f in good) {
    if (f.chromaRaw.length != 12) continue;
    for (var i = 0; i < 12; i++) {
      chromaSum[i] += f.chromaRaw[i];
    }
    chromaCount++;
  }
  if (chromaCount == 0) return null;
  final chromaMean = [for (final s in chromaSum) s / chromaCount];

  return NoiseProfile(
    rmsMean: mean,
    rmsP95: p95,
    chromaMean: chromaMean,
    calibratedAt: now ?? DateTime.now(),
  );
}

/// Build guitar level from loud frames (strumming).
GuitarLevelProfile? buildGuitarLevelProfile(
  List<CalibrationFrame> frames, {
  NoiseProfile? noise,
  DateTime? now,
  int minLoudFrames = 6,
}) {
  final floor = noise?.rmsP95 ?? 0.01;
  final minRms = floor * 2.0;
  final loud = frames.where((f) => f.rms >= minRms).toList();
  if (loud.length < minLoudFrames) return null;

  final rms = loud.map((f) => f.rms).toList()..sort();
  final median = _percentile(rms, 0.50);
  return GuitarLevelProfile(
    rmsMedian: median,
    calibratedAt: now ?? DateTime.now(),
  );
}

/// Adaptive thresholds from calibration (or balanced defaults).
RecognitionConfig configFromCalibration(CalibrationBundle bundle) {
  final base = RecognitionConfig.balanced;
  final noise = bundle.noise;
  if (noise == null) return base;

  final floor = noise.rmsP95;
  final double silence;
  if (bundle.guitar != null) {
    final g = bundle.guitar!.rmsMedian;
    // Mid-point between noise floor and playing level.
    silence = ((floor + g) / 2.0) * 0.85;
  } else {
    // Only room cal: gate a bit above measured ambient.
    silence = floor * 2.5;
  }

  // With noise subtract available, allow slightly softer chroma score.
  final hasChromaProfile = noise.chromaMean.length == 12;
  return base.copyWith(
    rmsSilence: silence.clamp(0.008, 0.08),
    chromaMinScore: hasChromaProfile ? 0.48 : base.chromaMinScore,
    chromaMatchThreshold: hasChromaProfile ? 0.46 : base.chromaMatchThreshold,
    chromaMinConcentration:
        hasChromaProfile ? 0.40 : base.chromaMinConcentration,
  );
}

double _percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0;
  if (sorted.length == 1) return sorted.first;
  final idx = (p * (sorted.length - 1)).clamp(0, sorted.length - 1);
  final lo = idx.floor();
  final hi = idx.ceil();
  if (lo == hi) return sorted[lo];
  final t = idx - lo;
  return sorted[lo] * (1 - t) + sorted[hi] * t;
}
