import 'package:chord_coach/domain/guide_voicing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('midiNotesForChord', () {
    test('C open shape in range', () {
      final notes = midiNotesForChord('C');
      expect(notes, isNotEmpty);
      expect(notes.length, greaterThanOrEqualTo(3));
      for (final n in notes) {
        expect(n, inInclusiveRange(guideMidiMin, guideMidiMax));
      }
      // Pitch classes C E G
      expect(notes.map((m) => m % 12).toSet(), {0, 4, 7});
    });

    test('Am open shape', () {
      final notes = midiNotesForChord('Am');
      expect(notes, openGuitarVoicings['Am']);
      expect(notes.map((m) => m % 12).toSet(), {9, 0, 4});
    });

    test('G7 open shape includes 7th', () {
      final notes = midiNotesForChord('G7');
      expect(notes, isNotEmpty);
      expect(notes.map((m) => m % 12).toSet(), containsAll([7, 11, 2, 5]));
    });

    test('N.C. empty', () {
      expect(midiNotesForChord('N.C.'), isEmpty);
    });

    test('invalid empty', () {
      expect(midiNotesForChord('xyz'), isEmpty);
    });

    test('sorted ascending', () {
      final notes = midiNotesForChord('F');
      final sorted = [...notes]..sort();
      expect(notes, sorted);
    });

    test('maxNotes thins open voicing', () {
      final full = midiNotesForChord('G', maxNotes: 6);
      final thin = midiNotesForChord('G', maxNotes: 4);
      expect(thin.length, lessThanOrEqualTo(4));
      expect(thin.first, full.first);
      expect(thin.last, full.last);
    });
  });

  group('guitarSampleAssetForMidi', () {
    test('in range', () {
      expect(guitarSampleAssetForMidi(60), 'assets/audio/guitar/n60.wav');
      expect(guitarSampleAssetForMidi(40), 'assets/audio/guitar/n40.wav');
    });

    test('out of range', () {
      expect(guitarSampleAssetForMidi(39), isNull);
      expect(guitarSampleAssetForMidi(80), isNull);
    });
  });
}
