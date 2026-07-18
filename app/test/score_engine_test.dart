import 'package:guitar_vibe/domain/score.dart';
import 'package:guitar_vibe/domain/song.dart';
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

/// Feed enough consecutive matching frames to accept a hit.
void _hit(
  ScoreEngine engine, {
  required double hz,
  required double beat,
  double confidence = 1.0,
}) {
  for (var i = 0; i < ScoreEngine.requiredMatchFrames; i++) {
    engine.onPitch(hz: hz, beat: beat, confidence: confidence);
  }
}

void main() {
  group('gradeForDelta', () {
    test('early / good / late / outside (casual windows)', () {
      // earlyStart=-0.70, goodStart=-0.40, goodEnd=0.55, lateEnd=1.05
      expect(gradeForDelta(-0.55), HitGrade.early);
      expect(gradeForDelta(-0.3), HitGrade.good);
      expect(gradeForDelta(0), HitGrade.good);
      expect(gradeForDelta(0.4), HitGrade.good);
      expect(gradeForDelta(0.55), HitGrade.good);
      expect(gradeForDelta(0.7), HitGrade.late);
      expect(gradeForDelta(1.0), HitGrade.late);
      expect(gradeForDelta(-0.8), isNull);
      expect(gradeForDelta(1.2), isNull);
    });
  });

  group('ScoreEngine', () {
    test('good hit on chord tone near onset', () {
      final engine = ScoreEngine(_events([(0, 'C'), (4, 'G')]));
      _hit(engine, hz: cHz, beat: 0.05);
      expect(engine.lastGrade, HitGrade.good);
      expect(engine.summary.good, 1);
      expect(engine.summary.hits, 1);
    });

    test('single matching frame is not enough', () {
      final engine = ScoreEngine(_events([(0, 'C')]));
      engine.onPitch(hz: cHz, beat: 0.05);
      expect(engine.lastGrade, isNull);
      expect(engine.summary.total, 0);
      // Second consecutive frame completes the hit.
      engine.onPitch(hz: cHz, beat: 0.06);
      expect(engine.lastGrade, HitGrade.good);
    });

    test('early hit', () {
      final engine = ScoreEngine(_events([(0, 'C')]));
      _hit(engine, hz: eHz, beat: -0.55); // earlyStart..goodStart
      expect(engine.lastGrade, HitGrade.early);
      expect(engine.summary.early, 1);
    });

    test('late hit', () {
      final engine = ScoreEngine(_events([(0, 'C')]));
      _hit(engine, hz: gHz, beat: 0.75); // past goodEnd (0.55), within lateEnd
      expect(engine.lastGrade, HitGrade.late);
    });

    test('wrong pitch ignored until miss', () {
      final engine = ScoreEngine(_events([(0, 'C')]));
      _hit(engine, hz: aHz, beat: 0.0); // A not in C
      expect(engine.lastGrade, isNull);
      engine.onBeat(1.1); // past lateEnd (1.05)
      expect(engine.lastGrade, HitGrade.miss);
      expect(engine.summary.miss, 1);
    });

    test('miss when window expires', () {
      final engine = ScoreEngine(_events([(0, 'C'), (4, 'G')]));
      engine.onBeat(1.1); // past lateEnd
      expect(engine.summary.miss, 1);
      expect(engine.lastGrade, HitGrade.miss);
    });

    test('skips NC events', () {
      final engine = ScoreEngine(_events([
        (0, 'N.C.'),
        (4, 'C'),
      ]));
      _hit(engine, hz: cHz, beat: 4.0);
      expect(engine.summary.total, 1);
      expect(engine.lastGrade, HitGrade.good);
    });

    test('streak increments and resets on miss', () {
      final engine = ScoreEngine(_events([
        (0, 'C'),
        (4, 'G'),
        (8, 'Am'),
      ]));
      _hit(engine, hz: cHz, beat: 0);
      _hit(engine, hz: gHz, beat: 4);
      expect(engine.summary.currentStreak, 2);
      expect(engine.summary.maxStreak, 2);
      engine.onBeat(9.1); // past Am lateEnd (8 + 1.05)
      expect(engine.summary.currentStreak, 0);
      expect(engine.summary.maxStreak, 2);
      expect(engine.summary.miss, 1);
    });

    test('accuracy percent', () {
      final engine = ScoreEngine(_events([
        (0, 'C'),
        (4, 'G'),
      ]));
      _hit(engine, hz: cHz, beat: 0);
      engine.onBeat(5.1); // miss G (lateEnd 4 + 1.05)
      expect(engine.summary.accuracyPercent, 50);
    });

    test('low confidence ignored', () {
      final engine = ScoreEngine(_events([(0, 'C')]));
      _hit(engine, hz: cHz, beat: 0, confidence: 0.1);
      expect(engine.lastGrade, isNull);
    });

    test('only first hit grades event', () {
      final engine = ScoreEngine(_events([(0, 'C')]));
      _hit(engine, hz: cHz, beat: 0);
      _hit(engine, hz: eHz, beat: 0.1);
      expect(engine.summary.good, 1);
      expect(engine.summary.total, 1);
    });

    test('lastGrade clears after hold beats (no sticky GOOD)', () {
      final engine = ScoreEngine(_events([(0, 'C'), (4, 'G')]));
      _hit(engine, hz: cHz, beat: 0);
      expect(engine.lastGrade, HitGrade.good);

      // Still within flash window.
      engine.onBeat(0.5);
      expect(engine.lastGrade, HitGrade.good);

      // Past lastGradeHoldBeats → back to "Listen…".
      engine.onBeat(ScoreEngine.lastGradeHoldBeats + 0.05);
      expect(engine.lastGrade, isNull);
      expect(engine.summary.good, 1); // score kept; only live badge clears
    });

    test('lastGrade clears when next event early window opens', () {
      final engine = ScoreEngine(_events([(0, 'C'), (2, 'G')]));
      _hit(engine, hz: cHz, beat: 0);
      expect(engine.lastGrade, HitGrade.good);

      // G early window starts at 2 + earlyStart (-0.70) = 1.30
      // (also past lastGradeHoldBeats from beat 0)
      engine.onBeat(1.35);
      expect(engine.lastGrade, isNull);
    });

    test('sustained ring on same pitch does not auto-score next same chord', () {
      final engine = ScoreEngine(_events([(0, 'C'), (4, 'C')]));
      _hit(engine, hz: cHz, beat: 0);
      expect(engine.summary.good, 1);

      // Continuous C into the next window without a gap — must not free-hit.
      _hit(engine, hz: cHz, beat: 4.0);
      _hit(engine, hz: cHz, beat: 4.1);
      expect(engine.summary.good, 1);
      expect(engine.summary.total, 1);

      // Non-match re-arms, then a fresh multi-frame play scores.
      engine.onPitch(hz: aHz, beat: 4.2); // A not in C → gap
      _hit(engine, hz: cHz, beat: 4.3);
      expect(engine.summary.good, 2);
    });

    test('chord change after hit still scores without silence', () {
      final engine = ScoreEngine(_events([(0, 'C'), (4, 'G')]));
      _hit(engine, hz: cHz, beat: 0);
      // Different chord re-arms after debounce; needs full match streak.
      _hit(engine, hz: gHz, beat: 4.0);
      expect(engine.summary.good, 2);
      expect(engine.lastGrade, HitGrade.good);
    });

    test('broken match streak does not score', () {
      final engine = ScoreEngine(_events([(0, 'C')]));
      engine.onPitch(hz: cHz, beat: 0.0);
      engine.onPitch(hz: aHz, beat: 0.05); // breaks streak
      engine.onPitch(hz: cHz, beat: 0.1); // only 1 frame again
      expect(engine.lastGrade, isNull);
      expect(engine.summary.total, 0);
    });

    test('grades from first match frame not confirm frame (no false Late)', () {
      final engine = ScoreEngine(_events([(0, 'C'), (4, 'G')]));
      // First frame still inside Good (goodEnd=0.55); confirm frame is Late.
      engine.onPitch(hz: cHz, beat: 0.50);
      engine.onPitch(hz: cHz, beat: 0.70);
      expect(engine.lastGrade, HitGrade.good);
      expect(engine.summary.good, 1);
      expect(engine.summary.late, 0);
    });

    test('after Late, on-time next chord grades Good not sticky Late', () {
      final engine = ScoreEngine(_events([(0, 'C'), (4, 'G')]));
      _hit(engine, hz: cHz, beat: 0.75); // Late
      expect(engine.lastGrade, HitGrade.late);
      final epochAfterLate = engine.lastGradeEpoch;

      // Flash still showing Late, but next hit is on time.
      _hit(engine, hz: gHz, beat: 4.0);
      expect(engine.lastGrade, HitGrade.good);
      expect(engine.summary.late, 1);
      expect(engine.summary.good, 1);
      expect(engine.lastGradeEpoch, greaterThan(epochAfterLate));
    });

    test('lastGrade clears so badge returns to Listen', () {
      final engine = ScoreEngine(_events([(0, 'C'), (4, 'G')]));
      _hit(engine, hz: cHz, beat: 0.75);
      expect(engine.lastGrade, HitGrade.late);
      engine.onBeat(0.75 + ScoreEngine.lastGradeHoldBeats + 0.01);
      expect(engine.lastGrade, isNull);
    });

    test('reopenFromBeat forward marks skipped as miss', () {
      final engine = ScoreEngine(_events([(0, 'C'), (4, 'G'), (8, 'Am')]));
      engine.reopenFromBeat(8);
      expect(engine.summary.miss, 2);
      expect(engine.summary.hits, 0);
      expect(engine.isComplete, isFalse);
      // First open target is Am @ 8; A is a chord tone of Am.
      _hit(engine, hz: aHz, beat: 8.0);
      expect(engine.summary.miss, 2);
      expect(engine.summary.hits, 1);
    });

    test('reopenFromBeat backward clears grades for retry', () {
      final engine = ScoreEngine(_events([(0, 'C'), (4, 'G')]));
      _hit(engine, hz: cHz, beat: 0.0);
      expect(engine.summary.good, 1);

      engine.reopenFromBeat(0);
      expect(engine.summary.good, 0);
      expect(engine.summary.miss, 0);
      expect(engine.lastGrade, isNull);

      // Can score C again.
      _hit(engine, hz: cHz, beat: 0.0);
      expect(engine.summary.good, 1);
    });

    test('reopenFromBeat keeps earlier grades when seeking mid-song', () {
      final engine = ScoreEngine(_events([(0, 'C'), (4, 'G'), (8, 'Am')]));
      _hit(engine, hz: cHz, beat: 0.0);
      expect(engine.summary.good, 1);

      engine.reopenFromBeat(4);
      expect(engine.summary.good, 1);
      expect(engine.summary.miss, 0);
      // G is open again (cleared if it had been graded; was not).
      _hit(engine, hz: gHz, beat: 4.0);
      expect(engine.summary.good, 2);
    });
  });
}
