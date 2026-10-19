// Merge repeated chords for display in the chord scroller.
// Pure domain — no Flutter.

import 'song.dart';

/// Joins back-to-back events with the same chord into one span.
///
/// Songs split a held chord into several events when a new lyric line or
/// section starts mid-chord (e.g. `A` 2 beats + `A` 4 beats). Drawing those as
/// separate cards reads like a chord change, so the scroller shows one card.
/// Lyrics are dropped — the lyrics scroller works from the original events.
List<ChordEvent> mergeChordRuns(List<ChordEvent> events) {
  if (events.isEmpty) return const [];

  final sorted = List<ChordEvent>.of(events)
    ..sort((a, b) => a.beat.compareTo(b.beat));

  final runs = <ChordEvent>[];
  for (final e in sorted) {
    final last = runs.isEmpty ? null : runs.last;
    // Continuous timeline only (small float slack).
    if (last != null &&
        last.chord == e.chord &&
        (e.beat - last.endBeat).abs() <= 0.05) {
      runs[runs.length - 1] = ChordEvent(
        beat: last.beat,
        durationBeats: e.endBeat - last.beat,
        chord: last.chord,
      );
    } else {
      runs.add(
        ChordEvent(
          beat: e.beat,
          durationBeats: e.durationBeats,
          chord: e.chord,
        ),
      );
    }
  }
  return runs;
}
