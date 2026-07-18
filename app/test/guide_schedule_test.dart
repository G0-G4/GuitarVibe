import 'package:chord_coach/domain/guide_schedule.dart';
import 'package:chord_coach/domain/song.dart';
import 'package:flutter_test/flutter_test.dart';

Song _song({
  required List<Map<String, dynamic>> events,
  Object? strum,
}) {
  return Song.fromJson({
    'schemaVersion': 1,
    'id': 't',
    'title': 'T',
    'artist': 'A',
    'tempoBpm': 90,
    'timeSignature': [4, 4],
    'strum': ?strum,
    'sections': [
      {
        'id': 'a',
        'name': 'A',
        'events': events,
      }
    ],
    'accompaniment': {'style': 'metronome_and_pad', 'volume': 0.7},
  });
}

void main() {
  group('GuideScheduler pad', () {
    test('silent during count-in', () {
      final song = _song(events: [
        {'beat': 0, 'durationBeats': 4, 'chord': 'C'},
      ]);
      final s = GuideScheduler();
      expect(s.actionsFor(song, -1).hasPad, isFalse);
      expect(s.actionsFor(song, -0.1).hasPad, isFalse);
    });

    test('fires pad once per chord', () {
      final song = _song(events: [
        {'beat': 0, 'durationBeats': 4, 'chord': 'C'},
        {'beat': 4, 'durationBeats': 4, 'chord': 'G'},
      ]);
      final s = GuideScheduler();

      final a0 = s.actionsFor(song, 0);
      expect(a0.hasPad, isTrue);
      expect(a0.padNotes, isNotEmpty);

      final a1 = s.actionsFor(song, 0.5);
      expect(a1.hasPad, isFalse);

      final a2 = s.actionsFor(song, 4.0);
      expect(a2.hasPad, isTrue);
      expect(a2.padNotes.map((m) => m % 12).toSet(), {7, 11, 2});
    });

    test('reset re-fires chord', () {
      final song = _song(events: [
        {'beat': 0, 'durationBeats': 8, 'chord': 'Am'},
      ]);
      final s = GuideScheduler();
      expect(s.actionsFor(song, 1).hasPad, isTrue);
      expect(s.actionsFor(song, 2).hasPad, isFalse);
      s.reset();
      expect(s.actionsFor(song, 2.5).hasPad, isTrue);
    });
  });

  group('GuideScheduler strum', () {
    test('fires on D/U steps, not on rest', () {
      final song = _song(
        events: [
          {'beat': 0, 'durationBeats': 8, 'chord': 'C'},
        ],
        strum: {
          'name': 'Six',
          'unitBeats': 0.5,
          'steps': ['D', '.', 'D', 'U', '.', 'D', 'U', '.'],
        },
      );
      final s = GuideScheduler();

      // beat 0 → step 0 D
      final d0 = s.actionsFor(song, 0.0);
      expect(d0.strumToken?.toUpperCase(), 'D');
      expect(d0.hasStrum, isTrue);
      expect(d0.padNotes, isNotEmpty); // first chord pad too

      // still same step
      expect(s.actionsFor(song, 0.2).hasStrum, isFalse);

      // beat 0.5 → step 1 rest
      final rest = s.actionsFor(song, 0.5);
      expect(rest.strumToken, '.');
      expect(rest.hasStrum, isFalse);

      // beat 1.0 → step 2 D
      final d2 = s.actionsFor(song, 1.0);
      expect(d2.strumToken?.toUpperCase(), 'D');
      expect(d2.hasStrum, isTrue);

      // beat 1.5 → step 3 U
      final u = s.actionsFor(song, 1.5);
      expect(u.strumToken?.toUpperCase(), 'U');
      expect(u.hasStrum, isTrue);
      // U is reverse order of D notes
      final dNotes = d2.strumNotes;
      expect(u.strumNotes, dNotes.reversed.toList());
    });

    test('mute X', () {
      final song = _song(
        events: [
          {'beat': 0, 'durationBeats': 4, 'chord': 'C'},
        ],
        strum: {
          'unitBeats': 1,
          'steps': ['D', 'X'],
        },
      );
      final s = GuideScheduler();
      s.actionsFor(song, 0); // D
      final x = s.actionsFor(song, 1.0);
      expect(x.mute, isTrue);
      expect(x.strumNotes, isEmpty);
    });

    test('no strum pattern → no strum actions', () {
      final song = _song(events: [
        {'beat': 0, 'durationBeats': 4, 'chord': 'C'},
      ]);
      final s = GuideScheduler();
      final a = s.actionsFor(song, 0);
      expect(a.hasPad, isTrue);
      expect(a.hasStrum, isFalse);
    });
  });
}
