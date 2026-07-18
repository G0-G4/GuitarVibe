import 'package:chord_coach/domain/song.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Song.fromJson parses training song shape', () {
    final song = Song.fromJson({
      'schemaVersion': 1,
      'id': 'training-c-g-am-f',
      'title': 'Training: C–G–Am–F',
      'artist': 'ChordCoach',
      'key': 'C',
      'capo': 0,
      'tempoBpm': 90,
      'timeSignature': [4, 4],
      'tags': ['training'],
      'audio': null,
      'sections': [
        {
          'id': 'loop',
          'name': 'Progression',
          'events': [
            {'beat': 0, 'durationBeats': 4, 'chord': 'C', 'lyrics': 'x'},
            {'beat': 4, 'durationBeats': 4, 'chord': 'G', 'lyrics': 'y'},
          ],
        },
      ],
      'accompaniment': {'style': 'metronome_and_pad', 'volume': 0.7},
    });

    expect(song.id, 'training-c-g-am-f');
    expect(song.tempoBpm, 90);
    expect(song.timeSignature, [4, 4]);
    expect(song.hasAudio, isFalse);
    expect(song.hasStrum, isFalse);
    expect(song.strum, isNull);
    expect(song.allEvents.length, 2);
    expect(song.totalBeats, 8);
    expect(song.estimatedDuration.inSeconds, greaterThan(0));
    expect(song.accompaniment.style, 'metronome_and_pad');
  });

  test('SongAudio optional fields', () {
    final song = Song.fromJson({
      'schemaVersion': 1,
      'id': 'with-audio',
      'title': 'With Audio',
      'artist': 'X',
      'tempoBpm': 100,
      'timeSignature': [4, 4],
      'audio': {
        'file': 'audio/x.ogg',
        'offsetSec': 1.5,
        'durationSec': 10,
      },
      'sections': [],
    });

    expect(song.hasAudio, isTrue);
    expect(song.audio!.file, 'audio/x.ogg');
    expect(song.audio!.offsetSec, 1.5);
  });

  test('Song.strum object form', () {
    final song = Song.fromJson({
      'schemaVersion': 1,
      'id': 'with-strum',
      'title': 'With Strum',
      'artist': 'X',
      'tempoBpm': 90,
      'timeSignature': [4, 4],
      'strum': {
        'name': 'Six-stroke',
        'unitBeats': 0.5,
        'steps': ['D', '.', 'D', 'U', '.', 'D', 'U', '.'],
      },
      'sections': [],
    });

    expect(song.hasStrum, isTrue);
    expect(song.strum!.name, 'Six-stroke');
    expect(song.strum!.unitBeats, 0.5);
    expect(song.strum!.steps.length, 8);
    expect(song.strum!.cycleBeats, 4.0);
    expect(song.toJson()['strum'], isA<Map<String, dynamic>>());
  });

  test('Song.strum compact string expands with bar length', () {
    final song = Song.fromJson({
      'schemaVersion': 1,
      'id': 'compact-strum',
      'title': 'Compact',
      'artist': 'X',
      'tempoBpm': 100,
      'timeSignature': [4, 4],
      'strum': 'D.DU.DU.',
      'sections': [],
    });

    expect(song.hasStrum, isTrue);
    expect(song.strum!.steps, ['D', '.', 'D', 'U', '.', 'D', 'U', '.']);
    // 8 steps over a 4-beat bar → eighth notes
    expect(song.strum!.unitBeats, closeTo(0.5, 1e-9));
  });

  test('StrumPattern.stepIndexAt loops and handles count-in', () {
    const pattern = StrumPattern(
      unitBeats: 0.5,
      steps: ['D', '.', 'D', 'U', '.', 'D', 'U', '.'],
    );

    expect(pattern.stepIndexAt(-1), 0);
    expect(pattern.stepIndexAt(0), 0);
    expect(pattern.stepIndexAt(0.49), 0);
    expect(pattern.stepIndexAt(0.5), 1);
    expect(pattern.stepIndexAt(3.5), 7);
    expect(pattern.stepIndexAt(4.0), 0); // next bar
    expect(pattern.stepAt(0.5), '.');
    expect(pattern.stepStartBeat(1.2), 1.0);
  });

  test('StrumPattern glyphs and unknown tokens', () {
    expect(StrumPattern.glyphFor('D'), '↓');
    expect(StrumPattern.glyphFor('U'), '↑');
    expect(StrumPattern.glyphFor('X'), '×');
    expect(StrumPattern.glyphFor('.'), '·');
    expect(StrumPattern.glyphFor('Z'), '·');
    expect(StrumPattern.isStroke('D'), isTrue);
    expect(StrumPattern.isStroke('.'), isFalse);

    final pattern = StrumPattern.fromJson({
      'unitBeats': 1,
      'steps': ['D', 'Z', 'U'],
    });
    expect(pattern, isNotNull);
    expect(pattern!.steps, ['D', 'Z', 'U']);
    expect(StrumPattern.glyphFor(pattern.steps[1]), '·');
  });
}
