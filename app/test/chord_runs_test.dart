import 'package:guitar_vibe/domain/chord_runs.dart';
import 'package:guitar_vibe/domain/song.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergeChordRuns', () {
    test('empty events → empty runs', () {
      expect(mergeChordRuns(const []), isEmpty);
    });

    test('same chord split across lyric lines becomes one span', () {
      final runs = mergeChordRuns(const [
        ChordEvent(beat: 0, durationBeats: 2, chord: 'E', lyrics: 'В лесу она'),
        ChordEvent(beat: 2, durationBeats: 2, chord: 'A'),
        ChordEvent(
          beat: 4,
          durationBeats: 2,
          chord: 'A',
          lyrics: 'Зимой и летом',
        ),
        ChordEvent(beat: 6, durationBeats: 2, chord: 'D'),
      ]);
      expect(runs.map((e) => e.chord), ['E', 'A', 'D']);
      expect(runs[1].beat, 2);
      expect(runs[1].durationBeats, 4);
    });

    test('same chord after a gap stays separate', () {
      final runs = mergeChordRuns(const [
        ChordEvent(beat: 0, durationBeats: 4, chord: 'A'),
        ChordEvent(beat: 8, durationBeats: 4, chord: 'A'),
      ]);
      expect(runs, hasLength(2));
    });

    test('alternating chords are untouched', () {
      final runs = mergeChordRuns(const [
        ChordEvent(beat: 0, durationBeats: 4, chord: 'A'),
        ChordEvent(beat: 4, durationBeats: 4, chord: 'D'),
        ChordEvent(beat: 8, durationBeats: 4, chord: 'A'),
      ]);
      expect(runs.map((e) => e.beat), [0, 4, 8]);
    });
  });
}
