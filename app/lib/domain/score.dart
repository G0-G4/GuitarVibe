// Pure scoring math — no Flutter / mic imports.
// Live feedback: Good / Early / Late / Miss per chord event.

import 'chord_guess.dart';
import 'chord_recognizer.dart';
import 'chord_tones.dart';
import 'recognition_mode.dart';
import 'song.dart';

/// Outcome for one scorable chord event.
enum HitGrade {
  good,
  early,
  late,
  miss,
}

/// Hit-window constants in beats relative to event onset (ideal).
class HitWindows {
  const HitWindows({
    this.earlyStart = -0.50,
    this.goodStart = -0.15,
    this.goodEnd = 0.30,
    this.lateEnd = 0.75,
  });

  /// First beat where early hits are accepted (delta from ideal).
  final double earlyStart;

  /// Start of good window (inclusive).
  final double goodStart;

  /// End of good window (inclusive).
  final double goodEnd;

  /// End of late window (inclusive). Past this → miss if ungraded.
  final double lateEnd;

  static const standard = HitWindows();
}

/// Grade from beat delta (detectedBeat − idealBeat).
HitGrade? gradeForDelta(double delta, [HitWindows windows = HitWindows.standard]) {
  if (delta < windows.earlyStart || delta > windows.lateEnd) {
    return null; // outside open window
  }
  if (delta < windows.goodStart) return HitGrade.early;
  if (delta <= windows.goodEnd) return HitGrade.good;
  return HitGrade.late;
}

/// One graded (or pending) chord opportunity.
class EventScore {
  const EventScore({
    required this.eventIndex,
    required this.chord,
    required this.idealBeat,
    this.grade,
    this.hitBeat,
  });

  final int eventIndex;
  final String chord;
  final double idealBeat;
  final HitGrade? grade;
  final double? hitBeat;

  bool get isGraded => grade != null;

  EventScore copyWith({HitGrade? grade, double? hitBeat}) {
    return EventScore(
      eventIndex: eventIndex,
      chord: chord,
      idealBeat: idealBeat,
      grade: grade ?? this.grade,
      hitBeat: hitBeat ?? this.hitBeat,
    );
  }
}

/// Aggregate session result.
class SessionScore {
  const SessionScore({
    this.good = 0,
    this.early = 0,
    this.late = 0,
    this.miss = 0,
    this.maxStreak = 0,
    this.currentStreak = 0,
    this.scoringEnabled = true,
    this.events = const [],
  });

  final int good;
  final int early;
  final int late;
  final int miss;
  final int maxStreak;
  final int currentStreak;
  final bool scoringEnabled;
  final List<EventScore> events;

  int get hits => good + early + late;
  int get total => hits + miss;

  /// Hit rate 0–100 (good/early/late count as hits).
  double get accuracyPercent {
    if (total == 0) return 0;
    return 100.0 * hits / total;
  }

  /// True when at least one event was graded.
  bool get hasResults => total > 0;

  SessionScore copyWith({
    int? good,
    int? early,
    int? late,
    int? miss,
    int? maxStreak,
    int? currentStreak,
    bool? scoringEnabled,
    List<EventScore>? events,
  }) {
    return SessionScore(
      good: good ?? this.good,
      early: early ?? this.early,
      late: late ?? this.late,
      miss: miss ?? this.miss,
      maxStreak: maxStreak ?? this.maxStreak,
      currentStreak: currentStreak ?? this.currentStreak,
      scoringEnabled: scoringEnabled ?? this.scoringEnabled,
      events: events ?? this.events,
    );
  }
}

/// Tracks open chord windows and assigns grades from pitch + beat.
class ScoreEngine {
  ScoreEngine(
    List<ChordEvent> songEvents, {
    this.windows = HitWindows.standard,
    this.minPitchConfidence = 0.80,
    RecognitionMode mode = RecognitionMode.pitchClass,
    ChordRecognizer? recognizer,
  })  : _targets = _buildTargets(songEvents),
        _recognizer = recognizer ?? ChordRecognizer(mode: mode);

  final HitWindows windows;
  final double minPitchConfidence;
  final ChordRecognizer _recognizer;

  final List<EventScore> _targets;
  int _openIndex = 0;
  HitGrade? lastGrade;
  int _good = 0;
  int _early = 0;
  int _late = 0;
  int _miss = 0;
  int _currentStreak = 0;
  int _maxStreak = 0;

  set mode(RecognitionMode m) => _recognizer.mode = m;

  RecognitionMode get mode => _recognizer.mode;

  static List<EventScore> _buildTargets(List<ChordEvent> events) {
    final out = <EventScore>[];
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      if (isNoChord(e.chord)) continue;
      final tones = pitchClassesForChord(e.chord);
      if (tones.isEmpty) continue;
      out.add(EventScore(
        eventIndex: i,
        chord: e.chord,
        idealBeat: e.beat,
      ));
    }
    return out;
  }

  bool get isComplete => _openIndex >= _targets.length;

  SessionScore get summary => SessionScore(
        good: _good,
        early: _early,
        late: _late,
        miss: _miss,
        maxStreak: _maxStreak,
        currentStreak: _currentStreak,
        scoringEnabled: true,
        events: List.unmodifiable(_targets),
      );

  /// Close windows that have passed without a hit.
  void onBeat(double beat) {
    while (_openIndex < _targets.length) {
      final t = _targets[_openIndex];
      if (t.isGraded) {
        _openIndex++;
        continue;
      }
      final lateEdge = t.idealBeat + windows.lateEnd;
      if (beat > lateEdge) {
        _assign(_openIndex, HitGrade.miss, hitBeat: null);
        _openIndex++;
        continue;
      }
      break;
    }
  }

  /// Feed a YIN result (legacy / pitch modes). [confidence] 0–1.
  void onPitch({
    required double hz,
    required double beat,
    double confidence = 1.0,
  }) {
    onFeatures(
      AudioFeatures(
        rms: 0.1, // above silence for pure pitch path
        chroma: const [],
        yinHz: hz,
        yinConfidence: confidence,
      ),
      beat: beat,
    );
  }

  /// Feed full analysis features (preferred for chroma / hybrid).
  void onFeatures(
    AudioFeatures features, {
    required double beat,
    int nowMs = 0,
  }) {
    onBeat(beat);
    if (_openIndex >= _targets.length) return;

    final t = _targets[_openIndex];
    if (t.isGraded) return;

    final delta = beat - t.idealBeat;
    final grade = gradeForDelta(delta, windows);
    if (grade == null) return; // outside window

    // For pitch-only legacy calls with empty chroma, fall back to tone check
    // when mode is pitch* or chroma list empty.
    final matched = _matchTarget(t.chord, features, nowMs: nowMs);
    if (!matched) return;

    _assign(_openIndex, grade, hitBeat: beat);
    _openIndex++;
  }

  bool _matchTarget(String expected, AudioFeatures f, {required int nowMs}) {
    // Empty chroma + pitch modes: use recognizer.
    if (f.chroma.isEmpty &&
        (mode == RecognitionMode.chroma || mode == RecognitionMode.hybrid)) {
      // Chroma required — can't match without it.
      if (f.yinHz != null && (f.yinConfidence ?? 0) >= minPitchConfidence) {
        final pc = pitchClassFromHz(f.yinHz!);
        if (pc != null && pitchClassesForChord(expected).contains(pc)) {
          return true; // soft fallback
        }
      }
      return false;
    }
    return _recognizer.matchesExpected(expected, f, nowMs: nowMs);
  }

  void _assign(int index, HitGrade grade, {required double? hitBeat}) {
    final prev = _targets[index];
    if (prev.isGraded) return;

    _targets[index] = prev.copyWith(grade: grade, hitBeat: hitBeat);
    lastGrade = grade;

    switch (grade) {
      case HitGrade.good:
        _good++;
        _currentStreak++;
      case HitGrade.early:
        _early++;
        _currentStreak++;
      case HitGrade.late:
        _late++;
        _currentStreak++;
      case HitGrade.miss:
        _miss++;
        _currentStreak = 0;
    }
    if (_currentStreak > _maxStreak) {
      _maxStreak = _currentStreak;
    }
  }

  void reset() {
    for (var i = 0; i < _targets.length; i++) {
      final t = _targets[i];
      _targets[i] = EventScore(
        eventIndex: t.eventIndex,
        chord: t.chord,
        idealBeat: t.idealBeat,
      );
    }
    _openIndex = 0;
    lastGrade = null;
    _good = 0;
    _early = 0;
    _late = 0;
    _miss = 0;
    _currentStreak = 0;
    _maxStreak = 0;
    _recognizer.reset();
  }
}
