// Pure scheduling decisions for guitar guide (pad + strum).
// UI/audio layers consume these; no I/O here.

import 'guide_voicing.dart';
import 'play_session.dart';
import 'song.dart';

/// One-shot actions for a clock tick (pad chord change and/or strum stroke).
class GuideActions {
  const GuideActions({
    this.padNotes = const [],
    this.strumNotes = const [],
    this.voicingNotes = const [],
    this.strumToken,
    this.mute = false,
    this.muteUp = false,
  });

  /// Soft pad / chord-change notes (empty = no pad event this tick).
  final List<int> padNotes;

  /// Strum stroke notes (empty unless a new stroke step started).
  final List<int> strumNotes;

  /// Current chord voicing (for mute ghosts even mid-hold).
  final List<int> voicingNotes;

  /// Raw step token when a new step started (`D`/`U`/`X`/`.`), else null.
  final String? strumToken;

  /// True when this step is a mute/chuck (`X`).
  final bool mute;

  /// Prefer thinner upstroke chuck sample (after an up pick).
  final bool muteUp;

  bool get hasPad => padNotes.isNotEmpty;
  bool get hasStrum => strumNotes.isNotEmpty || mute;

  static const none = GuideActions();
}

/// Tracks last pad chord + strum step so we only fire on changes.
class GuideScheduler {
  GuideScheduler();

  String? _lastPadChord;
  int? _lastStrumStepIndex;
  bool _armed = false;

  /// Call after seek / restart so the next tick re-fires current chord/step.
  void reset() {
    _lastPadChord = null;
    _lastStrumStepIndex = null;
    _armed = false;
  }

  /// Decide pad/strum actions for [beat] given [song].
  ///
  /// Silent during count-in (`beat < 0`) and for N.C. events.
  GuideActions actionsFor(Song song, double beat) {
    if (beat < 0) {
      // Leaving song body into count-in (seek): clear tracking.
      if (_armed) reset();
      return GuideActions.none;
    }

    final event = eventAt(song.allEvents, beat);
    if (event == null) {
      return GuideActions.none;
    }

    final chord = event.chord;
    final notes = midiNotesForChord(chord);
    final isNc = notes.isEmpty;

    List<int> padNotes = const [];
    // Pad fires on chord change (including first beat of song body).
    if (!isNc && chord != _lastPadChord) {
      _lastPadChord = chord;
      padNotes = notes;
    } else if (isNc) {
      _lastPadChord = chord;
    }

    List<int> strumNotes = const [];
    String? token;
    var mute = false;
    var muteUp = false;

    final strum = song.strum;
    if (strum != null && !strum.isEmpty) {
      final stepIdx = strum.stepIndexAt(beat);
      if (_lastStrumStepIndex == null || stepIdx != _lastStrumStepIndex) {
        _lastStrumStepIndex = stepIdx;
        token = strum.steps[stepIdx];
        final t = token.toUpperCase();
        if (t == 'X') {
          mute = true;
          // Chuck after upstroke tends to be thinner / higher strings.
          final prevIdx = (stepIdx - 1) % strum.steps.length;
          final prev = strum.steps[prevIdx].toUpperCase();
          muteUp = prev == 'U';
        } else if (StrumPattern.isStroke(token) && !isNc) {
          // D = low→high order (already sorted); U = reverse.
          strumNotes =
              t == 'U' ? notes.reversed.toList() : List<int>.from(notes);
        }
      }
    } else {
      _lastStrumStepIndex = null;
    }

    _armed = true;
    return GuideActions(
      padNotes: padNotes,
      strumNotes: strumNotes,
      voicingNotes: isNc ? const [] : notes,
      strumToken: token,
      mute: mute,
      muteUp: muteUp,
    );
  }
}
