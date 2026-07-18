// User practice chord set — limits free recognition vocabulary.

import 'chord_tones.dart';

/// Chords the user practices; free recognition ranks only within this set when enabled.
class ChordVocabulary {
  const ChordVocabulary({
    this.enabled = false,
    this.symbols = beginner,
  });

  /// When true, free chroma/hybrid ranking uses only [symbols].
  final bool enabled;

  /// Normalized symbols e.g. `C`, `Am`, `G7`.
  final Set<String> symbols;

  static const beginner = {'C', 'G', 'Am', 'F'};

  static const openChords = {
    'C',
    'G',
    'Am',
    'F',
    'D',
    'Em',
    'A',
    'E',
    'Dm',
    'Bm',
  };

  /// All major + minor triads (sharps).
  static final Set<String> majorMinor = {
    for (final r in pitchClassNames) r,
    for (final r in pitchClassNames) '${r}m',
  };

  /// Chips offered in the picker UI (common guitar set).
  static const selectable = [
    'C',
    'G',
    'Am',
    'F',
    'D',
    'Em',
    'A',
    'E',
    'Dm',
    'Bm',
    'B',
    'F#m',
    'C#m',
    'G7',
    'C7',
    'D7',
    'E7',
    'A7',
    'B7',
    'Cmaj7',
    'Am7',
    'Em7',
    'Dsus4',
    'Asus4',
  ];

  static const empty = ChordVocabulary();

  bool get isEmpty => symbols.isEmpty;

  List<String> get sorted {
    final list = symbols.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Allowed set for the recognizer, or null if unrestricted.
  Set<String>? get allowedSymbolsOrNull {
    if (!enabled || symbols.isEmpty) return null;
    return {
      for (final s in symbols) normalizeChordSymbol(s),
    }..removeWhere((s) => s.isEmpty);
  }

  bool allows(String symbol) {
    final allowed = allowedSymbolsOrNull;
    if (allowed == null) return true;
    return allowed.contains(normalizeChordSymbol(symbol));
  }

  ChordVocabulary copyWith({
    bool? enabled,
    Set<String>? symbols,
  }) {
    return ChordVocabulary(
      enabled: enabled ?? this.enabled,
      symbols: symbols ?? this.symbols,
    );
  }

  ChordVocabulary withToggled(String symbol) {
    final n = normalizeChordSymbol(symbol);
    if (n.isEmpty) return this;
    final next = Set<String>.from(symbols);
    if (next.contains(n)) {
      next.remove(n);
    } else {
      next.add(n);
    }
    return copyWith(symbols: next);
  }

  ChordVocabulary applyPreset(Set<String> preset, {bool enable = true}) {
    return ChordVocabulary(
      enabled: enable,
      symbols: {
        for (final s in preset) normalizeChordSymbol(s),
      }..removeWhere((s) => s.isEmpty),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'symbols': sorted,
      };

  factory ChordVocabulary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return empty;
    final raw = json['symbols'] as List<dynamic>? ?? const [];
    final symbols = <String>{
      for (final s in raw) normalizeChordSymbol(s as String),
    }..removeWhere((s) => s.isEmpty);
    return ChordVocabulary(
      enabled: json['enabled'] as bool? ?? false,
      symbols: symbols.isEmpty ? beginner : symbols,
    );
  }
}
