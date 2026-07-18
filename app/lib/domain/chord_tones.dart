// Chord symbol → pitch classes for monophonic scoring.
// Pitch class: 0 = C, 1 = C#/Db, … 11 = B.

import 'dart:math' as math;

/// Returns true for no-chord markers (skip scoring).
bool isNoChord(String chord) {
  final s = chord.trim().toUpperCase().replaceAll('.', '');
  return s.isEmpty || s == 'NC' || s == 'N/C' || s == 'NO CHORD' || s == '-';
}

/// Pitch classes (0–11) that belong to [chord], or empty if unparseable / NC.
Set<int> pitchClassesForChord(String chord) {
  if (isNoChord(chord)) return const {};

  final parsed = _parseChord(chord.trim());
  if (parsed == null) return const {};

  final root = parsed.root;
  final intervals = _intervalsForQuality(parsed.quality);
  return intervals.map((i) => (root + i) % 12).toSet();
}

/// Convert frequency in Hz to pitch class 0–11, or null if out of range.
int? pitchClassFromHz(double hz) {
  if (hz <= 0 || !hz.isFinite) return null;
  // Guitar-ish range roughly E2–E6; still accept wider for safety.
  if (hz < 40 || hz > 5000) return null;
  final midi = 69 + 12 * (math.log(hz / 440) / math.ln2);
  final rounded = midi.round();
  if (rounded < 0 || rounded > 127) return null;
  return rounded % 12;
}

class _ParsedChord {
  const _ParsedChord({required this.root, required this.quality});
  final int root;
  final String quality;
}

_ParsedChord? _parseChord(String raw) {
  // Strip bass note: Am/G → Am
  final slash = raw.indexOf('/');
  final head = slash >= 0 ? raw.substring(0, slash) : raw;
  if (head.isEmpty) return null;

  final rootMatch = RegExp(r'^([A-Ga-g])([#b]?)').firstMatch(head);
  if (rootMatch == null) return null;

  final letter = rootMatch.group(1)!.toUpperCase();
  final accidental = rootMatch.group(2) ?? '';
  final root = _rootPc(letter, accidental);
  if (root == null) return null;

  var quality = head.substring(rootMatch.end).trim();
  // Normalize common aliases
  quality = quality
      .replaceAll('min', 'm')
      .replaceAll('MIN', 'm')
      .replaceAll('Maj', 'maj')
      .replaceAll('MAJ', 'maj');

  return _ParsedChord(root: root, quality: quality);
}

int? _rootPc(String letter, String accidental) {
  const natural = {
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
    'A': 9,
    'B': 11,
  };
  final base = natural[letter];
  if (base == null) return null;
  if (accidental == '#') return (base + 1) % 12;
  if (accidental == 'b') return (base + 11) % 12;
  return base;
}

/// Intervals in semitones from root for a quality suffix.
List<int> _intervalsForQuality(String quality) {
  // Keep original for M vs m (case-sensitive major markers).
  final raw = quality.trim();
  final q = raw.toLowerCase();

  // Order matters: longer / more specific first.
  if (raw.isEmpty || q == 'maj' || raw == 'M') {
    return const [0, 4, 7];
  }
  if (q == 'm' || q == 'mi') {
    return const [0, 3, 7];
  }
  // maj7 before m7; M7 is major-7, m7 is minor-7.
  if (q == 'maj7' || raw == 'M7' || q == 'Δ' || q == 'Δ7') {
    return const [0, 4, 7, 11];
  }
  if (q == 'm7' || q == 'min7' || q == 'mi7') {
    return const [0, 3, 7, 10];
  }
  if (q == '7' || q == 'dom7') {
    return const [0, 4, 7, 10];
  }
  if (q == 'm7b5' || q == 'ø' || q == 'ø7') {
    return const [0, 3, 6, 10];
  }
  if (q == 'dim' || q == 'o' || q == '°') {
    return const [0, 3, 6];
  }
  if (q == 'dim7' || q == 'o7' || q == '°7') {
    return const [0, 3, 6, 9];
  }
  if (q == 'aug' || q == '+' || q == 'aug5') {
    return const [0, 4, 8];
  }
  if (q == 'sus2') {
    return const [0, 2, 7];
  }
  if (q == 'sus4' || q == 'sus') {
    return const [0, 5, 7];
  }
  if (q == '5' || q == 'no3') {
    return const [0, 7];
  }
  if (q == '6' || q == 'maj6') {
    return const [0, 4, 7, 9];
  }
  if (q == 'm6') {
    return const [0, 3, 7, 9];
  }
  if (q == 'add9') {
    return const [0, 4, 7, 2];
  }
  if (q == 'madd9' || q == 'm(add9)') {
    return const [0, 3, 7, 2];
  }
  if (q == '9') {
    return const [0, 4, 7, 10, 2];
  }
  if (q == 'm9') {
    return const [0, 3, 7, 10, 2];
  }

  // Fallback: minor if starts with m (not maj…); else major triad.
  if (q.startsWith('m') && !q.startsWith('maj')) {
    return const [0, 3, 7];
  }
  return const [0, 4, 7];
}
