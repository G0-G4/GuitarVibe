import 'package:chord_coach/domain/play_session.dart';
import 'package:chord_coach/domain/song.dart';
import 'package:flutter_test/flutter_test.dart';

Song _sampleSong({double totalBars = 2}) {
  final events = <Map<String, dynamic>>[];
  for (var i = 0; i < totalBars; i++) {
    events.add({
      'beat': i * 4,
      'durationBeats': 4,
      'chord': ['C', 'G', 'Am', 'F'][i % 4],
      'lyrics': 'line $i',
    });
  }
  return Song.fromJson({
    'schemaVersion': 1,
    'id': 'test',
    'title': 'Test',
    'artist': 'X',
    'tempoBpm': 120,
    'timeSignature': [4, 4],
    'sections': [
      {'id': 'a', 'name': 'A', 'events': events},
    ],
  });
}

void main() {
  group('secondsToBeats / beatsToSeconds', () {
    test('round-trip at 120 bpm', () {
      expect(secondsToBeats(1, 120), 2);
      expect(beatsToSeconds(2, 120), 1);
      expect(secondsToBeats(0.5, 60), 0.5);
    });

    test('zero tempo is safe', () {
      expect(secondsToBeats(10, 0), 0);
      expect(beatsToSeconds(10, 0), 0);
    });
  });

  group('clampTempoBpm / playbackRateFor', () {
    test('clamps to practice range', () {
      expect(clampTempoBpm(10), minPracticeTempoBpm);
      expect(clampTempoBpm(400), maxPracticeTempoBpm);
      expect(clampTempoBpm(90), 90);
    });

    test('playback rate is effective / song', () {
      expect(playbackRateFor(effectiveTempoBpm: 60, songTempoBpm: 120), 0.5);
      expect(playbackRateFor(effectiveTempoBpm: 120, songTempoBpm: 120), 1.0);
      expect(playbackRateFor(effectiveTempoBpm: 180, songTempoBpm: 90), 2.0);
    });

    test('playback rate clamps extremes', () {
      expect(
        playbackRateFor(effectiveTempoBpm: 40, songTempoBpm: 240),
        minPlaybackRate,
      );
    });
  });

  group('audio map: media time ↔ beat', () {
    test('higher map BPM packs more beats into the same media span', () {
      // 2 seconds after offset at 60 BPM → 2 beats; at 120 BPM → 4 beats.
      expect(secondsToBeats(2, 60), 2);
      expect(secondsToBeats(2, 120), 4);
      expect(beatsToSeconds(4, 120), 2);
      expect(beatsToSeconds(4, 60), 4);
    });

    test('offset shifts media time for beat 0 without changing beat spacing', () {
      const offset = 0.57;
      // Media position for beat 0 is just the offset.
      expect(offset + beatsToSeconds(0, 80), offset);
      // Beat 4 at 80 BPM is 3s of chart after offset.
      expect(offset + beatsToSeconds(4, 80), closeTo(offset + 3.0, 1e-9));
    });
  });

  group('eventIndexAt', () {
    final events = [
      const ChordEvent(beat: 0, durationBeats: 4, chord: 'C'),
      const ChordEvent(beat: 4, durationBeats: 4, chord: 'G'),
      const ChordEvent(beat: 8, durationBeats: 2, chord: 'Am'),
    ];

    test('before start', () {
      expect(eventIndexAt(events, -0.1), -1);
      expect(eventIndexAt(events, -4), -1);
    });

    test('first event inclusive start', () {
      expect(eventIndexAt(events, 0), 0);
      expect(eventIndexAt(events, 3.99), 0);
    });

    test('boundary is exclusive of end / inclusive of next', () {
      expect(eventIndexAt(events, 4), 1);
      expect(eventIndexAt(events, 7.9), 1);
      expect(eventIndexAt(events, 8), 2);
    });

    test('past last event', () {
      expect(eventIndexAt(events, 10), -1);
    });

    test('empty list', () {
      expect(eventIndexAt([], 0), -1);
    });
  });

  group('count-in and snapshot', () {
    test('countInBeatsFor uses time signature', () {
      final song = _sampleSong();
      expect(countInBeatsFor(song), 4);
    });

    test('countdownBeatsLeft during count-in', () {
      const snap = PlaySessionSnapshot(
        status: PlayStatus.countdown,
        currentBeat: -3.2,
        countInBeats: 4,
      );
      expect(snap.countdownBeatsLeft, 4); // ceil(3.2) = 4

      const almost = PlaySessionSnapshot(
        status: PlayStatus.countdown,
        currentBeat: -0.1,
        countInBeats: 4,
      );
      expect(almost.countdownBeatsLeft, 1);

      const playing = PlaySessionSnapshot(
        status: PlayStatus.playing,
        currentBeat: 0.5,
        countInBeats: 4,
      );
      expect(playing.countdownBeatsLeft, 0);
    });

    test('isFinished at totalBeats', () {
      final song = _sampleSong(totalBars: 2); // 8 beats
      expect(song.totalBeats, 8);

      final mid = PlaySessionSnapshot(
        status: PlayStatus.playing,
        currentBeat: 7.9,
        countInBeats: 4,
      );
      expect(mid.isFinished(song), isFalse);

      final end = PlaySessionSnapshot(
        status: PlayStatus.playing,
        currentBeat: 8,
        countInBeats: 4,
      );
      expect(end.isFinished(song), isTrue);
    });

    test('currentEvent during song', () {
      final song = _sampleSong(totalBars: 2);
      final snap = PlaySessionSnapshot(
        status: PlayStatus.playing,
        currentBeat: 4.5,
        countInBeats: 4,
      );
      expect(snap.currentEvent(song)?.chord, 'G');
      expect(snap.currentEventIndex(song), 1);
    });

    test('currentEvent null during count-in', () {
      final song = _sampleSong();
      const snap = PlaySessionSnapshot(
        status: PlayStatus.countdown,
        currentBeat: -2,
        countInBeats: 4,
      );
      expect(snap.currentEvent(song), isNull);
    });
  });

  group('bar helpers', () {
    test('barNumber and beatInBar', () {
      expect(barNumber(0, 4), 1);
      expect(barNumber(3.9, 4), 1);
      expect(barNumber(4, 4), 2);
      expect(beatInBar(0, 4), 1);
      expect(beatInBar(3, 4), 4);
      expect(beatInBar(4, 4), 1);
    });
  });
}
