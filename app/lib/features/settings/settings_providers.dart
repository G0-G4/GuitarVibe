import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/recognition_mode.dart';

const _scoringEnabledKey = 'scoringEnabled';
const _recognitionModeKey = 'recognitionMode';

/// Whether mic scoring is enabled (persisted). Default: true.
class ScoringEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    Future.microtask(_load);
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_scoringEnabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scoringEnabledKey, value);
  }
}

final scoringEnabledProvider =
    NotifierProvider<ScoringEnabledNotifier, bool>(ScoringEnabledNotifier.new);

/// Selected recognition algorithm (persisted). Default: chroma.
class RecognitionModeNotifier extends Notifier<RecognitionMode> {
  @override
  RecognitionMode build() {
    Future.microtask(_load);
    return RecognitionMode.chroma;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = RecognitionModeX.fromId(prefs.getString(_recognitionModeKey));
  }

  Future<void> setMode(RecognitionMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recognitionModeKey, mode.id);
  }
}

final recognitionModeProvider =
    NotifierProvider<RecognitionModeNotifier, RecognitionMode>(
  RecognitionModeNotifier.new,
);
