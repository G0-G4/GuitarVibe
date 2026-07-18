// Pure chroma analysis: FFT, fold to 12 bins, template cosine match.

import 'dart:math' as math;
import 'dart:typed_data';

import 'chord_tones.dart';

/// L2-normalize a vector in place-friendly copy; empty → zeros.
List<double> l2Normalize(List<double> v) {
  var sumSq = 0.0;
  for (final x in v) {
    sumSq += x * x;
  }
  if (sumSq <= 1e-20) {
    return List<double>.filled(v.length, 0);
  }
  final inv = 1.0 / math.sqrt(sumSq);
  return [for (final x in v) x * inv];
}

/// Fraction of L1 energy in the strongest [topK] chroma bins (0–1).
///
/// Clear chords concentrate energy; broadband noise is flatter (~topK/12).
double chromaConcentration(List<double> chroma, {int topK = 3}) {
  if (chroma.isEmpty) return 0;
  final sorted = [...chroma]..sort((a, b) => b.compareTo(a));
  final k = math.min(topK, sorted.length);
  var top = 0.0;
  var total = 0.0;
  for (var i = 0; i < sorted.length; i++) {
    total += sorted[i];
    if (i < k) top += sorted[i];
  }
  if (total <= 1e-12) return 0;
  return top / total;
}

/// Whether chroma looks tonal enough to attempt a chord guess.
bool isChromaTonal(
  List<double> chroma, {
  double minConcentration = 0.48,
}) {
  if (chroma.length != 12) return false;
  return chromaConcentration(chroma) >= minConcentration;
}

/// Cosine similarity of two equal-length non-negative vectors.
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || a.length != b.length) return 0;
  var dot = 0.0;
  var na = 0.0;
  var nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na <= 1e-20 || nb <= 1e-20) return 0;
  return dot / (math.sqrt(na) * math.sqrt(nb));
}

/// RMS of float samples in [-1, 1].
double computeRms(List<double> samples) {
  if (samples.isEmpty) return 0;
  var s = 0.0;
  for (final x in samples) {
    s += x * x;
  }
  return math.sqrt(s / samples.length);
}

/// Convert PCM16 little-endian mono bytes to float samples [-1, 1].
List<double> pcm16ToFloat(Uint8List pcm16) {
  final n = pcm16.length ~/ 2;
  final out = List<double>.filled(n, 0);
  final bd = ByteData.sublistView(pcm16);
  for (var i = 0; i < n; i++) {
    out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

/// Raw (pre-normalize) 12-bin chroma energy from float samples.
List<double> chromaRawFromSamples(
  List<double> samples, {
  required double sampleRate,
}) {
  if (samples.isEmpty || sampleRate <= 0) {
    return List<double>.filled(12, 0);
  }

  var n = 1;
  while (n < samples.length) {
    n <<= 1;
  }
  // Cap FFT size for CPU (max 4096).
  if (n > 4096) n = 4096;

  final re = Float64List(n);
  final im = Float64List(n);
  final take = math.min(samples.length, n);
  final denom = math.max(1, take - 1);
  for (var i = 0; i < take; i++) {
    // Hann window
    final w = 0.5 * (1 - math.cos(2 * math.pi * i / denom));
    re[i] = samples[i] * w;
  }

  _fftInPlace(re, im);

  final chroma = List<double>.filled(12, 0);
  final half = n ~/ 2;
  for (var k = 1; k < half; k++) {
    final mag = math.sqrt(re[k] * re[k] + im[k] * im[k]);
    if (mag <= 0) continue;
    final hz = k * sampleRate / n;
    if (hz < 60 || hz > 2000) continue; // guitar body range focus
    final midi = 69 + 12 * (math.log(hz / 440) / math.ln2);
    if (!midi.isFinite) continue;
    final pc = midi.round() % 12;
    final idx = pc < 0 ? pc + 12 : pc;
    // Mild high-frequency de-emphasis
    final weight = 1.0 / (1.0 + (hz / 800));
    chroma[idx] += mag * weight;
  }

  return chroma;
}

/// Build L2-normalized 12-bin chroma from time-domain float samples.
List<double> chromaFromSamples(
  List<double> samples, {
  required double sampleRate,
}) {
  return l2Normalize(chromaRawFromSamples(samples, sampleRate: sampleRate));
}

/// Qualities used for free recognition ranking (smaller set → fewer false hits).
const freeRecognitionQualities = <({String suffix, List<int> intervals})>[
  (suffix: '', intervals: [0, 4, 7]),
  (suffix: 'm', intervals: [0, 3, 7]),
  (suffix: '7', intervals: [0, 4, 7, 10]),
  (suffix: 'maj7', intervals: [0, 4, 7, 11]),
  (suffix: 'm7', intervals: [0, 3, 7, 10]),
  (suffix: 'sus4', intervals: [0, 5, 7]),
];

/// Rank recognition vocabulary chords by chroma cosine similarity.
///
/// Uses a restricted quality set for free lab; [qualities] can override.
/// When [allowedSymbols] is non-null and non-empty, only those chords are scored.
List<({String symbol, double score})> rankChromaMatches(
  List<double> chroma, {
  int topK = 5,
  List<({String suffix, List<int> intervals})>? qualities,
  Set<String>? allowedSymbols,
}) {
  if (chroma.length != 12) return const [];

  final scored = <({String symbol, double score})>[];

  if (allowedSymbols != null && allowedSymbols.isNotEmpty) {
    for (final raw in allowedSymbols) {
      final symbol = normalizeChordSymbol(raw);
      if (symbol.isEmpty || isNoChord(symbol)) continue;
      final template = _templateForSymbol(symbol);
      if (template == null) continue;
      final score = cosineSimilarity(chroma, l2Normalize(template));
      scored.add((symbol: symbol, score: score));
    }
  } else {
    final qs = qualities ?? freeRecognitionQualities;
    for (var root = 0; root < 12; root++) {
      for (final q in qs) {
        final template = List<double>.filled(12, 0);
        // Emphasize root slightly — helps vs noise / inversion ambiguity.
        for (var i = 0; i < q.intervals.length; i++) {
          final iv = q.intervals[i];
          template[(root + iv) % 12] = i == 0 ? 1.2 : 1.0;
        }
        final tNorm = l2Normalize(template);
        final score = cosineSimilarity(chroma, tNorm);
        scored.add((symbol: chordSymbol(root, q.suffix), score: score));
      }
    }
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  if (scored.length <= topK) return scored;
  return scored.sublist(0, topK);
}

/// Binary-ish template with root emphasis for a chord symbol.
List<double>? _templateForSymbol(String symbol) {
  final parsed = parseChord(symbol);
  if (parsed == null) return null;
  final intervals = intervalsForQuality(parsed.quality);
  if (intervals.isEmpty) return null;
  final template = List<double>.filled(12, 0);
  for (var i = 0; i < intervals.length; i++) {
    template[(parsed.root + intervals[i]) % 12] = i == 0 ? 1.2 : 1.0;
  }
  return template;
}

/// Similarity of observed chroma to the expected chord's template.
double chromaScoreForExpected(List<double> chroma, String expectedChord) {
  final template = l2Normalize(chromaTemplateForChord(expectedChord));
  if (template.every((e) => e == 0)) return 0;
  return cosineSimilarity(chroma, template);
}

/// In-place Cooley–Tukey radix-2 FFT (length must be power of 2).
void _fftInPlace(Float64List re, Float64List im) {
  final n = re.length;
  // Bit-reversal permutation
  var j = 0;
  for (var i = 1; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }

  for (var len = 2; len <= n; len <<= 1) {
    final ang = -2 * math.pi / len;
    final wlenRe = math.cos(ang);
    final wlenIm = math.sin(ang);
    for (var i = 0; i < n; i += len) {
      var wRe = 1.0;
      var wIm = 0.0;
      final half = len >> 1;
      for (var k = 0; k < half; k++) {
        final uRe = re[i + k];
        final uIm = im[i + k];
        final vRe = re[i + k + half] * wRe - im[i + k + half] * wIm;
        final vIm = re[i + k + half] * wIm + im[i + k + half] * wRe;
        re[i + k] = uRe + vRe;
        im[i + k] = uIm + vIm;
        re[i + k + half] = uRe - vRe;
        im[i + k + half] = uIm - vIm;
        final nextWRe = wRe * wlenRe - wIm * wlenIm;
        wIm = wRe * wlenIm + wIm * wlenRe;
        wRe = nextWRe;
      }
    }
  }
}
