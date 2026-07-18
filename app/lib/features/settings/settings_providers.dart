import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _scoringEnabledKey = 'scoringEnabled';

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
