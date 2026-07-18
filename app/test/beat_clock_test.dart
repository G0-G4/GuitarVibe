import 'package:chord_coach/audio/beat_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BeatClock maps elapsed time to beats at tempo', () async {
    final clock = BeatClock(
      tempoBpm: 120, // 2 beats per second
      tickInterval: const Duration(milliseconds: 20),
    );

    final beats = <double>[];
    clock.onTick = beats.add;
    clock.start(startBeat: 0);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    clock.pause();

    // ~0.5 seconds → ~1 beat; allow slack for timer jitter
    expect(clock.currentBeat, greaterThan(0.3));
    expect(clock.currentBeat, lessThan(1.2));
    expect(beats, isNotEmpty);

    final pausedBeat = clock.currentBeat;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(clock.currentBeat, closeTo(pausedBeat, 0.01));

    clock.resume();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(clock.currentBeat, greaterThan(pausedBeat + 0.15));

    clock.dispose();
  });

  test('count-in startBeat is negative', () {
    final clock = BeatClock(tempoBpm: 60);
    clock.start(startBeat: -4);
    expect(clock.currentBeat, closeTo(-4, 0.05));
    clock.dispose();
  });

  test('seekBeat jumps position', () {
    final clock = BeatClock(tempoBpm: 90);
    clock.start(startBeat: 0);
    clock.seekBeat(8);
    expect(clock.currentBeat, closeTo(8, 0.05));
    clock.dispose();
  });

  test('setTempoBpm keeps beat stable then advances at new rate', () async {
    final clock = BeatClock(
      tempoBpm: 60, // 1 beat/sec
      tickInterval: const Duration(milliseconds: 20),
    );
    clock.start(startBeat: 0);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    clock.pause();

    final before = clock.currentBeat;
    expect(before, greaterThan(0.1));

    clock.setTempoBpm(120); // 2 beats/sec
    expect(clock.currentBeat, closeTo(before, 0.05));

    clock.resume();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // ~0.4 beats in 0.2s at 120 bpm
    expect(clock.currentBeat, greaterThan(before + 0.25));
    expect(clock.currentBeat, lessThan(before + 0.7));

    clock.dispose();
  });
}
