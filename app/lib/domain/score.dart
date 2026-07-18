// Pure scoring math — no Flutter / mic imports.
// Live feedback: Good / Early / Late / Miss per chord event.

import 'chord_guess.dart';
import 'chord_recognizer.dart';
import 'chord_tones.dart';
import 'recognition_config.dart';
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
///
/// Tuned for casual / non-pro play-along (chord changes, not drum-tight
/// rhythm games). At 90 BPM one beat ≈ 667 ms:
/// - Good ≈ −0.40…+0.55 beats (~−270…+370 ms) — slight slip is inaudible
///   enough on harmony changes and covers mic/analysis latency.
/// - Early / Late still grade outside Good; past [lateEnd] → Miss.
class HitWindows {
  const HitWindows({
    this.earlyStart = -0.70,
    this.goodStart = -0.40,
    this.goodEnd = 0.55,
    this.lateEnd = 1.05,
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
    RecognitionConfig config = RecognitionConfig.balanced,
    ChordRecognizer? recognizer,
  })  : _targets = _buildTargets(songEvents),
        _recognizer =
            recognizer ?? ChordRecognizer(mode: mode, config: config);

  final HitWindows windows;
  final double minPitchConfidence;
  final ChordRecognizer _recognizer;

  final List<EventScore> _targets;
  int _openIndex = 0;
  HitGrade? lastGrade;

  /// Increments on every grade assign so the UI can re-flash even late→late.
  int lastGradeEpoch = 0;

  int _good = 0;
  int _early = 0;
  int _late = 0;
  int _miss = 0;
  int _currentStreak = 0;
  int _maxStreak = 0;

  /// Beat at which [lastGrade] was assigned (for brief UI flash, then clear).
  double? _lastGradeAtBeat;

  /// Index in [_targets] that produced [lastGrade].
  int? _lastGradedTargetIndex;

  /// After a successful hit, block immediate re-triggers (see onFeatures).
  bool _awaitingMatchGap = false;

  /// Consecutive matching analysis frames for the open target.
  /// Single-frame noise / metronome bleed must not free-score as Good.
  int _matchStreak = 0;

  /// Beat of the first frame in the current match streak (timing source).
  /// Grading from the *last* frame pushed on-time hits into Late after
  /// multi-frame confirmation + analysis lag.
  double? _matchStartBeat;

  /// How long (in beats) to keep last feedback before returning to "Listen…".
  static const double lastGradeHoldBeats = 0.75;

  /// Min beats after a hit before another event may be graded.
  static const double minRetriggerBeats = 0.12;

  /// Frames that must match in a row before a hit is accepted.
  static const int requiredMatchFrames = 2;

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
        _assign(_openIndex, HitGrade.miss, hitBeat: null, atBeat: beat);
        _openIndex++;
        continue;
      }
      break;
    }
    _maybeClearStaleLastGrade(beat);
  }

  /// Drop sticky live feedback once the flash window ends or the next
  /// opportunity opens — otherwise UI keeps showing the previous Good forever.
  void _maybeClearStaleLastGrade(double beat) {
    if (lastGrade == null || _lastGradeAtBeat == null) return;

    if (beat - _lastGradeAtBeat! >= lastGradeHoldBeats) {
      lastGrade = null;
      return;
    }

    // Entering the early window of a later ungraded target → wait for new hit.
    if (_openIndex < _targets.length &&
        _lastGradedTargetIndex != null &&
        _openIndex > _lastGradedTargetIndex!) {
      final next = _targets[_openIndex];
      if (!next.isGraded && beat >= next.idealBeat + windows.earlyStart) {
        lastGrade = null;
      }
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

  void _resetMatchStreak() {
    _matchStreak = 0;
    _matchStartBeat = null;
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

    // After a hit: short debounce, then extra protection when the next target
    // is the *same* chord (ring-out would otherwise free-score as Good).
    // Different next chords re-arm after the debounce only — shared tones
    // (C→G both contain G) must not block forever.
    if (_awaitingMatchGap) {
      final sinceHit = beat - (_lastGradeAtBeat ?? beat);
      if (sinceHit < minRetriggerBeats) {
        _resetMatchStreak();
        return;
      }

      final prevIdx = _lastGradedTargetIndex;
      final sameAsPrev = prevIdx != null &&
          prevIdx < _targets.length &&
          _targets[prevIdx].chord == t.chord;
      if (sameAsPrev) {
        final stillMatching = _matchTarget(t.chord, features, nowMs: nowMs);
        if (stillMatching) {
          _resetMatchStreak();
          return; // need a gap in the sound
        }
      }
      _awaitingMatchGap = false;
      _resetMatchStreak();
    }

    final matched = _matchTarget(t.chord, features, nowMs: nowMs);
    if (!matched) {
      _resetMatchStreak();
      return;
    }

    // Start / continue streak only while the *onset* (first frame) is inside
    // an open timing window. Grade from that first beat, not the confirm frame.
    _matchStartBeat ??= beat;
    final hitBeat = _matchStartBeat!;
    final grade = gradeForDelta(hitBeat - t.idealBeat, windows);
    if (grade == null) {
      // First frame was outside the window — drop and wait for a real onset.
      _resetMatchStreak();
      return;
    }

    _matchStreak++;
    if (_matchStreak < requiredMatchFrames) return;

    _resetMatchStreak();
    _assign(_openIndex, grade, hitBeat: hitBeat, atBeat: beat);
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

  void _assign(
    int index,
    HitGrade grade, {
    required double? hitBeat,
    required double atBeat,
  }) {
    final prev = _targets[index];
    if (prev.isGraded) return;

    _targets[index] = prev.copyWith(grade: grade, hitBeat: hitBeat);
    lastGrade = grade;
    lastGradeEpoch++;
    _lastGradedTargetIndex = index;
    // Use assign-time beat so miss/late flash is not immediately cleared.
    _lastGradeAtBeat = atBeat;

    // Only successful hits leave residual audio that can false-trigger next.
    _awaitingMatchGap = grade != HitGrade.miss;

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
    lastGradeEpoch = 0;
    _lastGradeAtBeat = null;
    _lastGradedTargetIndex = null;
    _awaitingMatchGap = false;
    _resetMatchStreak();
    _good = 0;
    _early = 0;
    _late = 0;
    _miss = 0;
    _currentStreak = 0;
    _maxStreak = 0;
    _recognizer.reset();
  }

  /// Adjust open windows after a scrub seek to [beat].
  ///
  /// - Targets with [EventScore.idealBeat] ≥ [beat]: cleared (retry).
  /// - Earlier ungraded targets whose late window is fully past: miss.
  /// - Earlier graded targets: kept.
  /// Then rebuilds counters and [open] index.
  void reopenFromBeat(double beat) {
    for (var i = 0; i < _targets.length; i++) {
      final t = _targets[i];
      if (t.idealBeat >= beat) {
        // Retry zone from seek position onward.
        _targets[i] = EventScore(
          eventIndex: t.eventIndex,
          chord: t.chord,
          idealBeat: t.idealBeat,
        );
      } else if (!t.isGraded) {
        final lateEdge = t.idealBeat + windows.lateEnd;
        if (beat > lateEdge) {
          // Skipped past without a grade — count as miss.
          _targets[i] = t.copyWith(grade: HitGrade.miss);
        }
        // else: still inside / before late window while seek is after ideal —
        // leave ungraded so user can still hit (e.g. seeked into late zone).
      }
    }

    _recountFromTargets();
    _openIndex = 0;
    while (_openIndex < _targets.length && _targets[_openIndex].isGraded) {
      _openIndex++;
    }

    lastGrade = null;
    _lastGradeAtBeat = null;
    _lastGradedTargetIndex = null;
    _awaitingMatchGap = false;
    _resetMatchStreak();
    _recognizer.reset();
  }

  void _recountFromTargets() {
    _good = 0;
    _early = 0;
    _late = 0;
    _miss = 0;
    _currentStreak = 0;
    _maxStreak = 0;
    for (final t in _targets) {
      final g = t.grade;
      if (g == null) {
        _currentStreak = 0;
        continue;
      }
      switch (g) {
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
  }
}
