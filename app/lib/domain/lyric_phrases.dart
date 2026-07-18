// Build display phrases from chord events for the lyrics scroller.
// Pure domain — no Flutter.

import 'song.dart';

/// A lyric line timed from its first chord through any following empty-lyric
/// chords (ChordPro-style: one line under D–A–Bm).
class LyricPhrase {
  const LyricPhrase({
    required this.beat,
    required this.durationBeats,
    required this.lyrics,
  });

  /// Start beat (same as the first chord that carries the line).
  final double beat;
  final double durationBeats;
  final String lyrics;

  double get endBeat => beat + durationBeats;
}

/// Groups [events] into lyric phrases.
///
/// Convention in `.song.json`: put the full line on the **first** chord of the
/// group; leave subsequent chords with `lyrics: ""` until the next line.
/// Those empty events still extend the phrase so the text stays visible for
/// the whole multi-chord line (e.g. D–A–Bm under one lyric).
///
/// Events with empty lyrics that are not preceded by a non-empty lyric in the
/// same continuous span (intros, interludes) produce no phrase.
List<LyricPhrase> buildLyricPhrases(List<ChordEvent> events) {
  if (events.isEmpty) return const [];

  final sorted = List<ChordEvent>.of(events)
    ..sort((a, b) => a.beat.compareTo(b.beat));

  final phrases = <LyricPhrase>[];
  for (var i = 0; i < sorted.length; i++) {
    final e = sorted[i];
    final text = e.lyrics.trim();
    if (text.isEmpty) continue;

    var end = e.endBeat;
    for (var j = i + 1; j < sorted.length; j++) {
      final next = sorted[j];
      if (next.lyrics.trim().isNotEmpty) break;
      // Continuous timeline only (small float slack).
      if (next.beat > end + 0.05) break;
      if (next.endBeat > end) end = next.endBeat;
    }

    phrases.add(
      LyricPhrase(
        beat: e.beat,
        durationBeats: end - e.beat,
        lyrics: e.lyrics,
      ),
    );
  }
  return phrases;
}
