// Chord symbol → guitar-range MIDI notes for synthetic guide audio.
// Pure domain; no Flutter / audio I/O.

import 'chord_tones.dart';

/// Lowest bundled sample (E2, open 6th string).
const int guideMidiMin = 40;

/// Highest bundled sample (C5).
const int guideMidiMax = 72;

/// Preferred centre when falling back to close-position voicing.
const int guideMidiCenter = 57; // A3 — open-string region

/// Common open-position shapes (sounding MIDI) for beginner chords.
///
/// Notes outside [guideMidiMin, guideMidiMax] are dropped at use time.
const Map<String, List<int>> openGuitarVoicings = {
  // Open shapes (standard tuning).
  'E': [40, 47, 52, 56, 59, 64],
  'Em': [40, 47, 52, 55, 59, 64],
  'E7': [40, 47, 50, 56, 59, 64],
  'A': [45, 52, 57, 61, 64],
  'Am': [45, 52, 57, 60, 64],
  'A7': [45, 52, 55, 61, 64],
  'Am7': [45, 52, 55, 60, 64],
  'D': [50, 57, 62, 66],
  'Dm': [50, 57, 62, 65],
  'D7': [50, 57, 60, 66],
  'Dm7': [50, 57, 60, 65],
  'G': [43, 47, 50, 55, 59, 67],
  'G7': [43, 47, 50, 55, 59, 65],
  'C': [48, 52, 55, 60, 64],
  'C7': [48, 52, 58, 60, 64],
  'F': [53, 57, 60, 65], // partial / easy F (no full barre)
  'B7': [47, 51, 54, 59, 62],
};

/// Map [chord] to open-ish MIDI notes in the bundled sample range.
///
/// Prefers [openGuitarVoicings] when the symbol matches; otherwise builds a
/// close-position stack from chord tones near [guideMidiCenter].
List<int> midiNotesForChord(
  String chord, {
  int maxNotes = 6,
  int centerMidi = guideMidiCenter,
}) {
  if (isNoChord(chord)) return const [];

  final canonical = normalizeChordSymbol(chord.trim());
  final open = openGuitarVoicings[canonical];
  if (open != null) {
    final notes = open
        .where((m) => m >= guideMidiMin && m <= guideMidiMax)
        .toList();
    if (notes.isNotEmpty) {
      if (notes.length > maxNotes) {
        // Prefer outer strings + a middle for body when trimming.
        return _thinVoicing(notes, maxNotes);
      }
      return notes;
    }
  }

  final parsed = parseChord(chord.trim());
  if (parsed == null) return const [];

  final intervals = intervalsForQuality(parsed.quality);
  if (intervals.isEmpty) return const [];

  final take = intervals.length > maxNotes ? maxNotes : intervals.length;
  final used = intervals.sublist(0, take);

  final rootPc = parsed.root;
  var rootMidi = _nearestMidi(rootPc, centerMidi - 7);
  final span = used.last;
  if (rootMidi + span > guideMidiMax) {
    rootMidi -= 12;
  }
  if (rootMidi < guideMidiMin) {
    rootMidi += 12;
  }
  rootMidi = rootMidi.clamp(guideMidiMin, guideMidiMax);

  final notes = <int>[];
  for (final iv in used) {
    var m = rootMidi + iv;
    while (m > guideMidiMax) {
      m -= 12;
    }
    while (m < guideMidiMin) {
      m += 12;
    }
    m = m.clamp(guideMidiMin, guideMidiMax);
    if (!notes.contains(m)) {
      notes.add(m);
    }
  }
  notes.sort();
  return notes;
}

/// Keep bass + treble + evenly spaced middles (sounds fuller than first N).
List<int> _thinVoicing(List<int> sorted, int maxNotes) {
  if (sorted.length <= maxNotes) return sorted;
  if (maxNotes <= 1) return [sorted.first];
  if (maxNotes == 2) return [sorted.first, sorted.last];
  final out = <int>{sorted.first, sorted.last};
  final inner = maxNotes - 2;
  for (var k = 1; k <= inner; k++) {
    final t = k / (inner + 1);
    final idx = (t * (sorted.length - 1)).round().clamp(0, sorted.length - 1);
    out.add(sorted[idx]);
  }
  final list = out.toList()..sort();
  // If set collision left us short, fill from remaining.
  if (list.length < maxNotes) {
    for (final m in sorted) {
      if (!list.contains(m)) list.add(m);
      if (list.length >= maxNotes) break;
    }
    list.sort();
  }
  return list.take(maxNotes).toList();
}

/// MIDI note for pitch class closest to [targetMidi] (same PC).
int _nearestMidi(int pitchClass, int targetMidi) {
  final pc = ((pitchClass % 12) + 12) % 12;
  final targetPc = ((targetMidi % 12) + 12) % 12;
  var delta = pc - targetPc;
  if (delta > 6) delta -= 12;
  if (delta < -6) delta += 12;
  var m = targetMidi + delta;
  while (m < guideMidiMin) {
    m += 12;
  }
  while (m > guideMidiMax) {
    m -= 12;
  }
  return m;
}

/// Asset path for a bundled note sample, or null if out of bank.
String? guitarSampleAssetForMidi(int midi) {
  if (midi < guideMidiMin || midi > guideMidiMax) return null;
  return 'assets/audio/guitar/n$midi.wav';
}

/// Dead-stroke / palm-mute chuck (down-style).
const String guitarMuteAsset = 'assets/audio/guitar/mute.wav';

/// Thinner upstroke chuck.
const String guitarMuteUpAsset = 'assets/audio/guitar/mute_up.wav';
