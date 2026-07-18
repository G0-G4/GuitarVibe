import 'package:chord_coach/domain/lyric_phrases.dart';
import 'package:chord_coach/domain/song.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildLyricPhrases', () {
    test('empty events → empty phrases', () {
      expect(buildLyricPhrases(const []), isEmpty);
    });

    test('single chord with lyrics keeps its duration', () {
      final phrases = buildLyricPhrases(const [
        ChordEvent(beat: 0, durationBeats: 4, chord: 'Am', lyrics: 'Hello'),
      ]);
      expect(phrases, hasLength(1));
      expect(phrases.first.beat, 0);
      expect(phrases.first.durationBeats, 4);
      expect(phrases.first.lyrics, 'Hello');
    });

    test('line under D–A–Bm spans three bars (12 beats)', () {
      // Sheet:
      // D           A             Bm
      // Я просыпаюсь в холодном поту,
      final phrases = buildLyricPhrases(const [
        ChordEvent(
          beat: 32,
          durationBeats: 4,
          chord: 'D',
          lyrics: 'Я просыпаюсь в холодном поту,',
        ),
        ChordEvent(beat: 36, durationBeats: 4, chord: 'A', lyrics: ''),
        ChordEvent(beat: 40, durationBeats: 4, chord: 'Bm', lyrics: ''),
        ChordEvent(
          beat: 44,
          durationBeats: 4,
          chord: 'F#',
          lyrics: 'Я просыпаюсь в кошмарном бреду,',
        ),
        ChordEvent(beat: 48, durationBeats: 4, chord: 'G', lyrics: ''),
      ]);

      expect(phrases, hasLength(2));
      expect(phrases[0].lyrics, 'Я просыпаюсь в холодном поту,');
      expect(phrases[0].beat, 32);
      expect(phrases[0].durationBeats, 12); // D+A+Bm
      expect(phrases[0].endBeat, 44);

      expect(phrases[1].lyrics, 'Я просыпаюсь в кошмарном бреду,');
      expect(phrases[1].beat, 44);
      expect(phrases[1].durationBeats, 8); // F#+G
    });

    test('intro empty chords produce no phrases', () {
      final phrases = buildLyricPhrases(const [
        ChordEvent(beat: 0, durationBeats: 4, chord: 'Bm', lyrics: ''),
        ChordEvent(beat: 4, durationBeats: 4, chord: 'A', lyrics: ''),
        ChordEvent(
          beat: 8,
          durationBeats: 4,
          chord: 'D',
          lyrics: 'Start',
        ),
      ]);
      expect(phrases, hasLength(1));
      expect(phrases.first.beat, 8);
      expect(phrases.first.durationBeats, 4);
    });

    test('each-line-has-lyrics (Zvezda style) stays one bar each', () {
      final phrases = buildLyricPhrases(const [
        ChordEvent(beat: 16, durationBeats: 4, chord: 'Am', lyrics: 'Белый снег'),
        ChordEvent(beat: 20, durationBeats: 4, chord: 'C', lyrics: 'серый лёд'),
      ]);
      expect(phrases, hasLength(2));
      expect(phrases[0].durationBeats, 4);
      expect(phrases[1].durationBeats, 4);
    });
  });
}
