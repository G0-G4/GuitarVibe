// Pure play-session math (no Flutter UI).
// Single clock → beat position used by scroller, accompaniment, scoring.

import 'song.dart';

enum PlayStatus {
  idle,
  countdown,
  playing,
  paused,
  finished,
}

/// Converts wall-clock seconds to beats at a given tempo.
double secondsToBeats(double seconds, double tempoBpm) {
  if (tempoBpm <= 0) return 0;
  return seconds * tempoBpm / 60.0;
}

/// Converts beats to seconds at a given tempo.
double beatsToSeconds(double beats, double tempoBpm) {
  if (tempoBpm <= 0) return 0;
  return beats * 60.0 / tempoBpm;
}

/// Practice tempo limits (BPM).
const double minPracticeTempoBpm = 40;
const double maxPracticeTempoBpm = 240;

/// Clamp a practice tempo override into a safe range.
double clampTempoBpm(double bpm) =>
    bpm.clamp(minPracticeTempoBpm, maxPracticeTempoBpm).toDouble();

/// just_audio playback-rate limits for backing tracks.
const double minPlaybackRate = 0.25;
const double maxPlaybackRate = 2.0;

/// Playback rate from effective practice BPM vs authored song tempo.
double playbackRateFor({
  required double effectiveTempoBpm,
  required double songTempoBpm,
}) {
  if (songTempoBpm <= 0) return 1.0;
  final rate = effectiveTempoBpm / songTempoBpm;
  return rate.clamp(minPlaybackRate, maxPlaybackRate).toDouble();
}

/// Default count-in length: one bar in the song's time signature.
int countInBeatsFor(Song song) {
  if (song.timeSignature.isEmpty) return 4;
  final n = song.timeSignature[0];
  return n > 0 ? n : 4;
}

/// Index of the event active at [beat], or -1 if none.
///
/// Active when `event.beat <= beat < event.endBeat`.
/// If [beat] is before the first event, returns -1.
/// If [beat] is past all events, returns the last index when
/// `beat < total end`, else -1 after song end (caller uses totalBeats).
int eventIndexAt(List<ChordEvent> events, double beat) {
  if (events.isEmpty || beat < 0) return -1;
  for (var i = 0; i < events.length; i++) {
    final e = events[i];
    if (beat >= e.beat && beat < e.endBeat) return i;
  }
  return -1;
}

ChordEvent? eventAt(List<ChordEvent> events, double beat) {
  final i = eventIndexAt(events, beat);
  if (i < 0) return null;
  return events[i];
}

/// 1-based bar number for display (beat 0 → bar 1).
int barNumber(double beat, int beatsPerBar) {
  if (beatsPerBar <= 0) return 1;
  if (beat < 0) {
    // Count-in bars: show approaching bar 1.
    return 1;
  }
  return beat.floor() ~/ beatsPerBar + 1;
}

/// Beat within the bar, 1-based fractional (beat 0 → 1.0 in 4/4).
double beatInBar(double beat, int beatsPerBar) {
  if (beatsPerBar <= 0) return 1;
  if (beat < 0) {
    final rem = beat % beatsPerBar;
    // e.g. -3.2 in 4/4 → still count-in display
    final positive = rem < 0 ? rem + beatsPerBar : rem;
    return positive + 1;
  }
  return (beat % beatsPerBar) + 1;
}

/// Immutable view of play position for UI and accompaniment.
class PlaySessionSnapshot {
  const PlaySessionSnapshot({
    required this.status,
    required this.currentBeat,
    required this.countInBeats,
    this.lastIntegerBeat,
  });

  final PlayStatus status;

  /// Absolute song beat. Negative during count-in (e.g. -4..0).
  final double currentBeat;

  /// Total count-in length in beats (usually one bar).
  final int countInBeats;

  /// Last integer beat for which a metronome click was scheduled.
  final int? lastIntegerBeat;

  static const idle = PlaySessionSnapshot(
    status: PlayStatus.idle,
    currentBeat: 0,
    countInBeats: 4,
  );

  bool get isActive =>
      status == PlayStatus.countdown ||
      status == PlayStatus.playing ||
      status == PlayStatus.paused;

  bool get isRunning =>
      status == PlayStatus.countdown || status == PlayStatus.playing;

  /// Remaining whole count-in beats to display (4,3,2,1), or 0 when past count-in.
  int get countdownBeatsLeft {
    if (status != PlayStatus.countdown && status != PlayStatus.playing) {
      if (status == PlayStatus.idle) return countInBeats;
    }
    if (currentBeat >= 0) return 0;
    // currentBeat in [-countIn, 0): left = ceil(-currentBeat)
    return (-currentBeat).ceil().clamp(0, countInBeats);
  }

  bool isFinished(Song song) => currentBeat >= song.totalBeats;

  ChordEvent? currentEvent(Song song) {
    if (currentBeat < 0) return null;
    return eventAt(song.allEvents, currentBeat);
  }

  int currentEventIndex(Song song) {
    if (currentBeat < 0) return -1;
    return eventIndexAt(song.allEvents, currentBeat);
  }

  PlaySessionSnapshot copyWith({
    PlayStatus? status,
    double? currentBeat,
    int? countInBeats,
    int? lastIntegerBeat,
    bool clearLastIntegerBeat = false,
  }) {
    return PlaySessionSnapshot(
      status: status ?? this.status,
      currentBeat: currentBeat ?? this.currentBeat,
      countInBeats: countInBeats ?? this.countInBeats,
      lastIntegerBeat: clearLastIntegerBeat
          ? null
          : (lastIntegerBeat ?? this.lastIntegerBeat),
    );
  }
}
