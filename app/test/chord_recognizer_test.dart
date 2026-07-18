import 'package:chord_coach/domain/chord_guess.dart';
import 'package:chord_coach/domain/chord_recognizer.dart';
import 'package:chord_coach/domain/chroma.dart';
import 'package:chord_coach/domain/recognition_mode.dart';
import 'package:flutter_test/flutter_test.dart';

AudioFeatures _cMajorFeatures({double rms = 0.1}) {
  final chroma = List<double>.filled(12, 0.02);
  chroma[0] = 1;
  chroma[4] = 0.9;
  chroma[7] = 0.85;
  return AudioFeatures(
    rms: rms,
    chroma: l2Normalize(chroma),
    yinHz: 261.63,
    yinConfidence: 0.95,
  );
}

AudioFeatures _flatNoiseFeatures() {
  // Nearly flat chroma — broadband noise after normalize.
  final chroma = List<double>.generate(12, (i) => 0.8 + (i % 3) * 0.05);
  return AudioFeatures(
    rms: 0.08,
    chroma: l2Normalize(chroma),
    yinHz: null,
    yinConfidence: null,
  );
}

AudioFeatures _aPitchFeatures() {
  return const AudioFeatures(
    rms: 0.1,
    chroma: [],
    yinHz: 440,
    yinConfidence: 0.95,
  );
}

void main() {
  group('ChordRecognizer free guess', () {
    test('chroma mode guesses C after hold', () {
      final r = ChordRecognizer(mode: RecognitionMode.chroma);
      final f = _cMajorFeatures();
      // First frames build hold — no symbol yet.
      final early = r.recognize(f, nowMs: 0);
      expect(early.symbol, isNull);
      expect(early.blockReason, isNotNull);
      final late = r.recognize(f, nowMs: 200);
      expect(late.isSilence, isFalse);
      expect(late.symbol, 'C');
      expect(late.confidence, greaterThan(0.4));
    });

    test('chroma rejects flat noise', () {
      final r = ChordRecognizer(mode: RecognitionMode.chroma);
      final g = r.recognize(_flatNoiseFeatures(), nowMs: 500);
      expect(g.symbol, isNull);
    });

    test('pitch mode reports pitch-class major root', () {
      final r = ChordRecognizer(mode: RecognitionMode.pitchClass);
      final g = r.recognize(_aPitchFeatures());
      expect(g.symbol, 'A');
    });

    test('silence when rms low', () {
      final r = ChordRecognizer(mode: RecognitionMode.chroma);
      final g = r.recognize(
        const AudioFeatures(rms: 0.001, chroma: []),
      );
      expect(g.isSilence, isTrue);
      expect(g.symbol, isNull);
    });

    test('hybrid needs yin support for symbol', () {
      final r = ChordRecognizer(mode: RecognitionMode.hybrid);
      final chromaOnly = AudioFeatures(
        rms: 0.1,
        chroma: _cMajorFeatures().chroma,
      );
      final noPitch = r.recognize(chromaOnly, nowMs: 0);
      expect(noPitch.symbol, isNull);

      // Hold requires stable frames over chromaHoldMs.
      expect(r.recognize(_cMajorFeatures(), nowMs: 0).symbol, isNull);
      final withPitch = r.recognize(_cMajorFeatures(), nowMs: 200);
      expect(withPitch.symbol, 'C');
    });
  });

  group('matchesExpected', () {
    test('pitchClass matches tone in C', () {
      final r = ChordRecognizer(mode: RecognitionMode.pitchClass);
      expect(
        r.matchesExpected(
          'C',
          const AudioFeatures(
            rms: 0.1,
            chroma: [],
            yinHz: 261.63,
            yinConfidence: 0.95,
          ),
        ),
        isTrue,
      );
      expect(r.matchesExpected('C', _aPitchFeatures()), isFalse);
    });

    test('chroma matches expected Am', () {
      final r = ChordRecognizer(mode: RecognitionMode.chroma);
      final chroma = List<double>.filled(12, 0.02);
      chroma[9] = 1;
      chroma[0] = 0.9;
      chroma[4] = 0.85;
      final f = AudioFeatures(rms: 0.1, chroma: l2Normalize(chroma));
      expect(r.matchesExpected('Am', f), isTrue);
      expect(r.matchesExpected('G', f), isFalse);
    });

    test('chroma rejects flat noise for expected chord', () {
      final r = ChordRecognizer(mode: RecognitionMode.chroma);
      expect(r.matchesExpected('C', _flatNoiseFeatures()), isFalse);
    });
  });

  group('chromaConcentration', () {
    test('peaked > flat', () {
      final peaked = l2Normalize([1, 0.05, 0.05, 0.05, 0.9, 0.05, 0.05, 0.8, 0.05, 0.05, 0.05, 0.05]);
      final flat = l2Normalize(List<double>.filled(12, 1));
      expect(chromaConcentration(peaked), greaterThan(chromaConcentration(flat)));
      expect(isChromaTonal(peaked), isTrue);
      expect(isChromaTonal(flat), isFalse);
    });
  });
}
