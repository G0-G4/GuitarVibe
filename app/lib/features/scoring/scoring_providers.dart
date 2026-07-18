import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/score.dart';

/// Holds the score from the most recently finished play session.
///
/// Not autoDispose so the complete screen can read it after the session
/// provider is disposed.
class LastSessionScoreNotifier extends Notifier<SessionScore?> {
  @override
  SessionScore? build() => null;

  void setScore(SessionScore? score) => state = score;

  void clear() => state = null;
}

final lastSessionScoreProvider =
    NotifierProvider<LastSessionScoreNotifier, SessionScore?>(
  LastSessionScoreNotifier.new,
);
