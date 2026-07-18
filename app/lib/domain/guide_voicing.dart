// Chord symbol → guitar-range MIDI notes for synthetic guide audio.
// Pure domain; no Flutter / audio I/O.

import 'chord_tones.dart';

/// Lowest bundled sample (C3).
const int guideMidiMin = 48;

/// Highest bundled sample (C5).
const int guideMidiMax = 72;

/// Preferred open-voicing centre (around C4).
const int guideMidiCenter = 60;

/// Map [chord] to close-position MIDI notes in the bundled sample range.
///
/// Returns empty for N.C. / unparseable. Uses root + quality intervals from
/// [pitchClassesForChord] / [parseChord], voiced near [guideMidiCenter].
List<int> midiNotesForChord(
  String chord, {
  int maxNotes = 4,
  int centerMidi = guideMidiCenter,
}) {
  if (isNoChord(chord)) return const [];

  final parsed = parseChord(chord.trim());
  if (parsed == null) return const [];

  final intervals = intervalsForQuality(parsed.quality);
  if (intervals.isEmpty) return const [];

  // Take first N intervals (triad or tetrad).
  final take = intervals.length > maxNotes ? maxNotes : intervals.length;
  final used = intervals.sublist(0, take);

  // Place root near center, then stack intervals in one octave (close position).
  final rootPc = parsed.root;
  var rootMidi = _nearestMidi(rootPc, centerMidi - 5);
  // Keep root in sample range with room for top of voicing.
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
    // If above range, drop an octave (keep order as much as possible).
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

/// Dead-stroke / chuck sample.
const String guitarMuteAsset = 'assets/audio/guitar/mute.wav';
