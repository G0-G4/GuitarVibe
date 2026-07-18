/// How play-along accompaniment is produced.
enum AccompanimentMode {
  /// Metronome clicks + synthetic guitar guide (pad / strum samples).
  generated,

  /// Song backing audio file as master clock (when [Song.hasAudio]).
  audio,
}

extension AccompanimentModeX on AccompanimentMode {
  String get label {
    switch (this) {
      case AccompanimentMode.generated:
        return 'Guide';
      case AccompanimentMode.audio:
        return 'Recording';
    }
  }

  String get description {
    switch (this) {
      case AccompanimentMode.generated:
        return 'Metronome + guitar guide';
      case AccompanimentMode.audio:
        return 'Backing audio track';
    }
  }

  static AccompanimentMode? tryParse(String? raw) {
    if (raw == null) return null;
    for (final m in AccompanimentMode.values) {
      if (m.name == raw) return m;
    }
    return null;
  }
}
