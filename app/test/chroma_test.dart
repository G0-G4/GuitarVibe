import 'dart:math' as math;

import 'package:guitar_vibe/domain/chroma.dart';
import 'package:flutter_test/flutter_test.dart';

List<double> sine({
  required double hz,
  required double sampleRate,
  int n = 2048,
}) {
  return [
    for (var i = 0; i < n; i++) math.sin(2 * math.pi * hz * i / sampleRate),
  ];
}

void main() {
  group('chromaFromSamples', () {
    test('A4 sine peaks at pitch class 9', () {
      final samples = sine(hz: 440, sampleRate: 44100);
      final chroma = chromaFromSamples(samples, sampleRate: 44100);
      expect(chroma.length, 12);
      var maxI = 0;
      for (var i = 1; i < 12; i++) {
        if (chroma[i] > chroma[maxI]) maxI = i;
      }
      expect(maxI, 9); // A
    });

    test('C4 sine peaks at pitch class 0', () {
      final samples = sine(hz: 261.63, sampleRate: 44100);
      final chroma = chromaFromSamples(samples, sampleRate: 44100);
      var maxI = 0;
      for (var i = 1; i < 12; i++) {
        if (chroma[i] > chroma[maxI]) maxI = i;
      }
      expect(maxI, 0);
    });
  });

  group('rankChromaMatches', () {
    test('C major template ranks C highly', () {
      // Synthetic chroma with energy on C E G
      final chroma = List<double>.filled(12, 0.05);
      chroma[0] = 1;
      chroma[4] = 0.9;
      chroma[7] = 0.85;
      final ranked = rankChromaMatches(l2Normalize(chroma), topK: 3);
      expect(ranked, isNotEmpty);
      expect(ranked.first.symbol, 'C');
    });

    test('Am template ranks Am highly', () {
      final chroma = List<double>.filled(12, 0.05);
      chroma[9] = 1; // A
      chroma[0] = 0.9; // C
      chroma[4] = 0.85; // E
      final ranked = rankChromaMatches(l2Normalize(chroma), topK: 3);
      expect(ranked.first.symbol, 'Am');
    });
  });

  group('cosineSimilarity', () {
    test('identical vectors', () {
      expect(cosineSimilarity([1, 0, 1], [1, 0, 1]), closeTo(1, 1e-9));
    });

    test('orthogonal', () {
      expect(cosineSimilarity([1, 0], [0, 1]), closeTo(0, 1e-9));
    });
  });
}
