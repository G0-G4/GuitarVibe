// Lightweight noise isolation helpers (no ML).

import 'dart:math' as math;

/// Simple one-pole high-pass (~cutoffHz) to cut rumble / AC thump.
List<double> highPassSamples(
  List<double> samples, {
  required double sampleRate,
  double cutoffHz = 80,
}) {
  if (samples.isEmpty || sampleRate <= 0) return samples;
  final rc = 1.0 / (2 * math.pi * cutoffHz);
  final dt = 1.0 / sampleRate;
  final alpha = rc / (rc + dt);

  final out = List<double>.filled(samples.length, 0);
  out[0] = samples[0];
  for (var i = 1; i < samples.length; i++) {
    out[i] = alpha * (out[i - 1] + samples[i] - samples[i - 1]);
  }
  return out;
}

/// Subtract a measured noise chroma mean from raw chroma energy.
///
/// [noiseMean] should be the same scale as raw (pre-normalize) chroma.
/// Result is non-negative residual energy (not yet L2-normalized).
List<double> subtractChromaNoise(
  List<double> rawChroma, {
  List<double>? noiseMean,
  double gain = 1.0,
}) {
  if (rawChroma.length != 12) {
    return List<double>.filled(12, 0);
  }
  if (noiseMean == null || noiseMean.length != 12) {
    return List<double>.from(rawChroma);
  }
  final g = gain.clamp(0.0, 1.5);
  return [
    for (var i = 0; i < 12; i++)
      math.max(0.0, rawChroma[i] - g * noiseMean[i]),
  ];
}
