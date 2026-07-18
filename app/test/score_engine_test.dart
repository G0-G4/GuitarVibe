import 'package:chord_coach/domain/score.dart';
import 'package:chord_coach/domain/song.dart';
import 'package:flutter_test/flutter_test.dart';

/// C major triad tones: C=261.63, E=329.63, G=392.00
const cHz = 261.63;
const eHz = 329.63;
const gHz = 392.0;
const aHz = 440.0; // not in C major

List<ChordEvent> _events(List<(double beat, String chord)> items) {
  return [
    for (final (beat, chord) in items)
      ChordEvent(beat: beat, durationBeats: 4, chord: chord),
  ];
}

void main() {
  group('gradeForDelta', () {
    test('early / good / late / outside', () {
      expect(gradeForDelta(-0.4), HitGrade.early);
      expect(gradeForDelta(-0.1), HitGrade.good);
      expect(gradeForDelta(0), HitGrade.good);
      expect(gradeForDelta(0.2), HitGrade.good);
      expect(gradeForDelta(0.5), HitGrade.late);
      expect(gradeForDelta(-0.6), isNull);
      expect(gradeForDelta(0.9), isNull);
    });
  });

  group('ScoreEngine', () {
    test('good hit on chord tone near onset', () {
      final engine = ScoreEngine(_events([(0, 'C'), (4, 'G')]));
      engine.onPitch(hz: cHz, beat: 0.05);
      expect(engine.lastGrade, HitGrade.good);
      expect(engine.summary.good, 1);
      expect(engine.summary.hits, 1);
    });

    test('early hit', () {
      final engine = ScoreEngine(_events([(0, 'C')]));
      engine.onPitch(hz: eHz, beat: -0.3);
      expect(engine.lastGrade, HitGrade.early);
      expect(engine.summary.early, 1);
    });

    test('late hit', () {
      final engine = ScoreEngine(_events([(0, 'C')]));
      engine.onPitch(hz: gHz, beat: 0.5);
      expect(engine.lastGrade, HitGrade.late);
    });

    test('wrong pitch ignored until miss', () {
      final engine = ScoreEngine(_events([(0, 'C')]));
      engine.onPitch(hz: aHz, beat: 0.0); // A not in C
      expect(engine.lastGrade, isNull);
      engine.onBeat(0.8);
      expect(engine.lastGrade, HitGrade.miss);
      expect(engine.summary.miss, 1);
    });

    test('miss when window expires', () {
      final engine = ScoreEngine(_events([(0, 'C'), (4, 'G')]));
      engine.onBeat(1.0);
      expect(engine.summary.miss, 1);
      expect(engine.lastGrade, HitGrade.miss);
    });

    test('skips NC events', () {
      final engine = ScoreEngine(_events([
        (0, 'N.C.'),
        (4, 'C'),
      ]));
      engine.onPitch(hz: cHz, beat: 4.0);
      expect(engine.summary.total, 1);
      expect(engine.lastGrade, HitGrade.good);
    });

    test('streak increments and resets on miss', () {
      final engine = ScoreEngine(_events([
        (0, 'C'),
        (4, 'G'),
        (8, 'Am'),
      ]));
      engine.onPitch(hz: cHz, beat: 0);
      engine.onPitch(hz: gHz, beat: 4);
      expect(engine.summary.currentStreak, 2);
      expect(engine.summary.maxStreak, 2);
      engine.onBeat(9); // miss Am
      expect(engine.summary.currentStreak, 0);
      expect(engine.summary.maxStreak, 2);
      expect(engine.summary.miss, 1);
    });

    test('accuracy percent', () {
      final engine = ScoreEngine(_events([
        (0, 'C'),
        (4, 'G'),
      ]));
      engine.onPitch(hz: cHz, beat: 0);
      engine.onBeat(5);
      expect(engine.summary.accuracyPercent, 50);
    });

    test('low confidence ignored', () {
      final engine = ScoreEngine(_events([(0, 'C')]));
      engine.onPitch(hz: cHz, beat: 0, confidence: 0.1);
      expect(engine.lastGrade, isNull);
    });

    test('only first hit grades event', () {
      final engine = ScoreEngine(_events([(0, 'C')]));
      engine.onPitch(hz: cHz, beat: 0);
      engine.onPitch(hz: eHz, beat: 0.1);
      expect(engine.summary.good, 1);
      expect(engine.summary.total, 1);
    });
  });
}
