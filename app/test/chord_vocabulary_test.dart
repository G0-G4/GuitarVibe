import 'package:chord_coach/domain/chord_guess.dart';
import 'package:chord_coach/domain/chord_recognizer.dart';
import 'package:chord_coach/domain/chord_vocabulary.dart';
import 'package:chord_coach/domain/chroma.dart';
import 'package:chord_coach/domain/recognition_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChordVocabulary', () {
    test('allowedSymbolsOrNull null when disabled', () {
      const v = ChordVocabulary(enabled: false, symbols: {'C', 'Am'});
      expect(v.allowedSymbolsOrNull, isNull);
    });

    test('allowedSymbolsOrNull when enabled', () {
      const v = ChordVocabulary(enabled: true, symbols: {'C', 'Am'});
      expect(v.allowedSymbolsOrNull, {'C', 'Am'});
    });

    test('json round-trip', () {
      final v = ChordVocabulary.empty.applyPreset(ChordVocabulary.beginner);
      final back = ChordVocabulary.fromJson(v.toJson());
      expect(back.enabled, isTrue);
      expect(back.symbols, ChordVocabulary.beginner);
    });
  });

  group('rankChromaMatches with allowedSymbols', () {
    test('only ranks within set', () {
      final chroma = l2Normalize([
        1.0, 0.05, 0.05, 0.05, 0.9, 0.05, 0.05, 0.85, 0.05, 0.05, 0.05, 0.05,
      ]);
      final ranked = rankChromaMatches(
        chroma,
        topK: 5,
        allowedSymbols: {'Am', 'F'},
      );
      expect(ranked, isNotEmpty);
      for (final r in ranked) {
        expect({'Am', 'F'}.contains(r.symbol), isTrue);
      }
      expect(ranked.any((r) => r.symbol == 'C'), isFalse);
    });

    test('Am wins when only Am allowed', () {
      final chroma = l2Normalize([
        1.0, 0.05, 0.05, 0.05, 0.9, 0.05, 0.05, 0.2, 0.05, 0.95, 0.05, 0.05,
      ]);
      final ranked = rankChromaMatches(
        chroma,
        topK: 1,
        allowedSymbols: {'Am'},
      );
      expect(ranked.single.symbol, 'Am');
    });
  });

  group('ChordRecognizer with vocabulary', () {
    test('free guess stays inside set after hold', () {
      final r = ChordRecognizer(
        mode: RecognitionMode.chroma,
        allowedSymbols: {'C', 'G', 'Am', 'F'},
      );
      final chroma = l2Normalize([
        1.0, 0.05, 0.05, 0.05, 0.9, 0.05, 0.05, 0.85, 0.05, 0.05, 0.05, 0.05,
      ]);
      final f = AudioFeatures(rms: 0.1, chroma: chroma);
      r.recognize(f, nowMs: 0);
      final g = r.recognize(f, nowMs: 200);
      if (g.symbol != null) {
        expect({'C', 'G', 'Am', 'F'}.contains(g.symbol), isTrue);
      }
      for (final t in g.top) {
        expect({'C', 'G', 'Am', 'F'}.contains(t.symbol), isTrue);
      }
    });
  });
}
