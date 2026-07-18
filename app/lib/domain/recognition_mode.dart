/// How the app turns mic audio into a chord match / free guess.
enum RecognitionMode {
  /// YIN single pitch class ∈ chord tones (original Phase 3).
  pitchClass,

  /// Same as [pitchClass] with RMS gate + hold + median smooth.
  pitchClassHeld,

  /// FFT chroma vs chord templates (better for full strums).
  chroma,

  /// Chroma primary; YIN pitch class as supporting evidence.
  hybrid,
}

extension RecognitionModeX on RecognitionMode {
  String get id => name;

  String get label => switch (this) {
        RecognitionMode.pitchClass => 'Single pitch',
        RecognitionMode.pitchClassHeld => 'Held pitch',
        RecognitionMode.chroma => 'Chroma',
        RecognitionMode.hybrid => 'Hybrid',
      };

  String get description => switch (this) {
        RecognitionMode.pitchClass =>
          'Matches one detected note to chord tones. Light CPU.',
        RecognitionMode.pitchClassHeld =>
          'Single pitch with noise gate and short hold filter.',
        RecognitionMode.chroma =>
          'Matches the full spectrum to chord templates. Best for strums.',
        RecognitionMode.hybrid =>
          'Chroma match with single-pitch support for bass/root.',
      };

  static RecognitionMode fromId(String? id) {
    for (final m in RecognitionMode.values) {
      if (m.id == id) return m;
    }
    return RecognitionMode.chroma;
  }
}
