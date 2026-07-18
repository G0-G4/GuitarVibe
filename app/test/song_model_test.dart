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
}
