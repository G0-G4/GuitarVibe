// Optional guitar strum pattern ("бой") for visual guidance.
// See docs/SONG_FORMAT.md.

/// Repeating right-hand strum cycle (down / up / rest / mute).
class StrumPattern {
  const StrumPattern({
    required this.unitBeats,
    required this.steps,
    this.name,
  });

  /// Display label (e.g. "Six-stroke", "Downstrums").
  final String? name;

  /// Length of one step in beats (`0.5` = eighths, `1` = quarters).
  final double unitBeats;

  /// Ordered step tokens: `D`, `U`, `.`, `X` (see [glyphFor]).
  final List<String> steps;

  /// Length of one full cycle in beats.
  double get cycleBeats =>
      steps.isEmpty ? 0 : unitBeats * steps.length;

  bool get isEmpty => steps.isEmpty;

  /// Compact string of step tokens (e.g. `D.DU.DU`).
  String get compact => steps.join();

  /// Index of the step active at [beat], looping. Returns `0` if empty or
  /// during count-in (`beat < 0`).
  int stepIndexAt(double beat) {
    if (steps.isEmpty || unitBeats <= 0) return 0;
    if (beat < 0) return 0;
    final raw = (beat / unitBeats).floor();
    return raw % steps.length;
  }

  /// Token at [beat], or `null` if empty.
  String? stepAt(double beat) {
    if (steps.isEmpty) return null;
    return steps[stepIndexAt(beat)];
  }

  /// Absolute beat where the current step started (0 when beat &lt; 0).
  double stepStartBeat(double beat) {
    if (steps.isEmpty || unitBeats <= 0) return 0;
    if (beat < 0) return 0;
    return (beat / unitBeats).floor() * unitBeats;
  }

  /// Display glyph for a step token.
  static String glyphFor(String token) {
    switch (token.toUpperCase()) {
      case 'D':
        return '↓';
      case 'U':
        return '↑';
      case 'X':
        return '×';
      case '.':
      case '-':
      case '_':
        return '·';
      default:
        return '·';
    }
  }

  /// Whether the token is a pick stroke (not rest).
  static bool isStroke(String token) {
    final t = token.toUpperCase();
    return t == 'D' || t == 'U' || t == 'X';
  }

  /// Parse from JSON: object `{name?, unitBeats, steps}` or compact string.
  ///
  /// Compact form uses [barBeats] (usually time-signature numerator) so that
  /// `unitBeats = barBeats / steps.length`.
  static StrumPattern? fromJson(
    dynamic raw, {
    double barBeats = 4,
  }) {
    if (raw == null) return null;

    if (raw is String) {
      final compact = raw.trim();
      if (compact.isEmpty) return null;
      final steps = compact.split('').where((c) => c.trim().isNotEmpty).toList();
      if (steps.isEmpty) return null;
      final bars = barBeats > 0 ? barBeats : 4.0;
      return StrumPattern(
        unitBeats: bars / steps.length,
        steps: steps,
      );
    }

    if (raw is Map<String, dynamic>) {
      final name = raw['name'] as String?;
      final stepsRaw = raw['steps'];
      List<String> steps;
      if (stepsRaw is List) {
        steps = stepsRaw.map((e) => e.toString()).toList();
      } else if (stepsRaw is String && stepsRaw.isNotEmpty) {
        steps = stepsRaw.split('');
      } else {
        return null;
      }
      if (steps.isEmpty) return null;

      final unit = (raw['unitBeats'] as num?)?.toDouble();
      final unitBeats = (unit != null && unit > 0)
          ? unit
          : (barBeats > 0 ? barBeats : 4.0) / steps.length;

      return StrumPattern(
        name: name,
        unitBeats: unitBeats,
        steps: steps,
      );
    }

    return null;
  }

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        'unitBeats': unitBeats,
        'steps': steps,
      };
}
