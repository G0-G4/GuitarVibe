import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/calibration.dart';
import '../../domain/recognition_config.dart';
import '../../domain/recognition_mode.dart';

const _scoringEnabledKey = 'scoringEnabled';
const _recognitionModeKey = 'recognitionMode';
const _calibrationKey = 'calibration.v1';

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

/// Persisted room + guitar calibration.
class CalibrationNotifier extends Notifier<CalibrationBundle> {
  @override
  CalibrationBundle build() {
    Future.microtask(_load);
    return CalibrationBundle.empty;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_calibrationKey);
    if (raw == null || raw.isEmpty) {
      state = CalibrationBundle.empty;
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      state = CalibrationBundle.fromJson(map);
    } catch (_) {
      state = CalibrationBundle.empty;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (state.isEmpty) {
      await prefs.remove(_calibrationKey);
    } else {
      await prefs.setString(_calibrationKey, jsonEncode(state.toJson()));
    }
  }

  Future<void> setBundle(CalibrationBundle bundle) async {
    state = bundle;
    await _save();
  }

  Future<void> setNoise(NoiseProfile? noise) async {
    state = state.copyWith(noise: noise, clearNoise: noise == null);
    await _save();
  }

  Future<void> setGuitar(GuitarLevelProfile? guitar) async {
    state = state.copyWith(guitar: guitar, clearGuitar: guitar == null);
    await _save();
  }

  Future<void> reset() async {
    state = CalibrationBundle.empty;
    await _save();
  }
}

final calibrationProvider =
    NotifierProvider<CalibrationNotifier, CalibrationBundle>(
  CalibrationNotifier.new,
);

/// Thresholds derived from calibration (or balanced defaults).
final effectiveRecognitionConfigProvider = Provider<RecognitionConfig>((ref) {
  final cal = ref.watch(calibrationProvider);
  return configFromCalibration(cal);
});
