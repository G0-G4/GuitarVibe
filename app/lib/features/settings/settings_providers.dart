import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/calibration.dart';
import '../../domain/chord_tones.dart';
import '../../domain/chord_vocabulary.dart';
import '../../domain/recognition_config.dart';
import '../../domain/recognition_mode.dart';
import '../../domain/threshold_prefs.dart';

const _scoringEnabledKey = 'scoringEnabled';
const _recognitionModeKey = 'recognitionMode';
const _calibrationKey = 'calibration.v1';
const _thresholdPrefsKey = 'thresholdPrefs.v1';
const _chordVocabularyKey = 'chordVocabulary.v1';
const _metronomeVolumeKey = 'metronomeVolume';
const _guideVolumeKey = 'guideVolume';

/// Default metronome gain (matches song accompaniment default).
const double defaultMetronomeVolume = 0.7;

/// Default guitar guide (pad + strum) gain.
const double defaultGuideVolume = 0.55;

/// Metronome click volume 0–1 (persisted). 0 = fully off.
class MetronomeVolumeNotifier extends Notifier<double> {
  /// Last non-zero volume for mute toggle restore.
  double _lastAudible = defaultMetronomeVolume;

  @override
  double build() {
    Future.microtask(_load);
    return defaultMetronomeVolume;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(_metronomeVolumeKey);
    if (v == null) {
      state = defaultMetronomeVolume;
      return;
    }
    state = v.clamp(0.0, 1.0);
    if (state > 0) _lastAudible = state;
  }

  Future<void> setVolume(double value) async {
    final v = value.clamp(0.0, 1.0);
    state = v;
    if (v > 0) _lastAudible = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_metronomeVolumeKey, v);
  }

  /// Toggle between 0 and the last audible level.
  Future<void> toggleMute() async {
    if (state > 0) {
      _lastAudible = state;
      await setVolume(0);
    } else {
      await setVolume(_lastAudible > 0 ? _lastAudible : defaultMetronomeVolume);
    }
  }
}

final metronomeVolumeProvider =
    NotifierProvider<MetronomeVolumeNotifier, double>(
  MetronomeVolumeNotifier.new,
);

/// Guitar guide (pad + strum samples) volume 0–1 (persisted). 0 = off.
class GuideVolumeNotifier extends Notifier<double> {
  double _lastAudible = defaultGuideVolume;

  @override
  double build() {
    Future.microtask(_load);
    return defaultGuideVolume;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(_guideVolumeKey);
    if (v == null) {
      state = defaultGuideVolume;
      return;
    }
    state = v.clamp(0.0, 1.0);
    if (state > 0) _lastAudible = state;
  }

  Future<void> setVolume(double value) async {
    final v = value.clamp(0.0, 1.0);
    state = v;
    if (v > 0) _lastAudible = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_guideVolumeKey, v);
  }

  Future<void> toggleMute() async {
    if (state > 0) {
      _lastAudible = state;
      await setVolume(0);
    } else {
      await setVolume(_lastAudible > 0 ? _lastAudible : defaultGuideVolume);
    }
  }
}

final guideVolumeProvider = NotifierProvider<GuideVolumeNotifier, double>(
  GuideVolumeNotifier.new,
);

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

/// User threshold sliders (sensitivity / advanced).
class ThresholdPrefsNotifier extends Notifier<ThresholdPrefs> {
  @override
  ThresholdPrefs build() {
    Future.microtask(_load);
    return ThresholdPrefs.defaults;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_thresholdPrefsKey);
    if (raw == null || raw.isEmpty) {
      state = ThresholdPrefs.defaults;
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      state = ThresholdPrefs.fromJson(map);
    } catch (_) {
      state = ThresholdPrefs.defaults;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_thresholdPrefsKey, jsonEncode(state.toJson()));
  }

  Future<void> setPrefs(ThresholdPrefs next) async {
    state = next;
    await _save();
  }

  Future<void> setSensitivity(double value) async {
    state = state.copyWith(sensitivity: value.clamp(0.0, 1.0), useAdvanced: false);
    await _save();
  }

  Future<void> setUseAdvanced(bool value) async {
    if (value && !state.useAdvanced) {
      // Seed advanced fields from current effective config.
      final cal = ref.read(calibrationProvider);
      final base = configFromCalibration(cal);
      final seeded = state.configFromSensitivity(base);
      state = state.copyWith(
        useAdvanced: true,
        chromaMinScore: seeded.chromaMinScore,
        chromaMargin: seeded.chromaMargin,
        chromaMinConcentration: seeded.chromaMinConcentration,
        chromaHoldMs: seeded.chromaHoldMs,
        rmsSilence: seeded.rmsSilence,
      );
    } else {
      state = state.copyWith(useAdvanced: value);
    }
    await _save();
  }

  Future<void> setRequireYinForHybrid(bool value) async {
    state = state.copyWith(requireYinForHybrid: value);
    await _save();
  }

  Future<void> setAdvanced({
    double? chromaMinScore,
    double? chromaMargin,
    double? chromaMinConcentration,
    int? chromaHoldMs,
    double? rmsSilence,
  }) async {
    state = state.copyWith(
      useAdvanced: true,
      chromaMinScore: chromaMinScore,
      chromaMargin: chromaMargin,
      chromaMinConcentration: chromaMinConcentration,
      chromaHoldMs: chromaHoldMs,
      rmsSilence: rmsSilence,
    );
    await _save();
  }

  Future<void> reset() async {
    state = ThresholdPrefs.defaults;
    await _save();
  }
}

final thresholdPrefsProvider =
    NotifierProvider<ThresholdPrefsNotifier, ThresholdPrefs>(
  ThresholdPrefsNotifier.new,
);

/// Thresholds: calibration base → user sensitivity / advanced overrides.
final effectiveRecognitionConfigProvider = Provider<RecognitionConfig>((ref) {
  final cal = ref.watch(calibrationProvider);
  final prefs = ref.watch(thresholdPrefsProvider);
  final base = configFromCalibration(cal);
  final applied = prefs.applyTo(base);
  return applied.copyWith(requireYinForHybrid: prefs.requireYinForHybrid);
});

/// User practice chord set for free recognition.
class ChordVocabularyNotifier extends Notifier<ChordVocabulary> {
  @override
  ChordVocabulary build() {
    Future.microtask(_load);
    return ChordVocabulary.empty;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chordVocabularyKey);
    if (raw == null || raw.isEmpty) {
      state = ChordVocabulary.empty;
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      state = ChordVocabulary.fromJson(map);
    } catch (_) {
      state = ChordVocabulary.empty;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chordVocabularyKey, jsonEncode(state.toJson()));
  }

  Future<void> setVocabulary(ChordVocabulary next) async {
    // Keep at least one chord when filter is on.
    if (next.enabled && next.symbols.isEmpty) {
      next = next.copyWith(symbols: ChordVocabulary.beginner);
    }
    state = next;
    await _save();
  }

  Future<void> setEnabled(bool enabled) async {
    await setVocabulary(state.copyWith(enabled: enabled));
  }

  Future<void> toggleSymbol(String symbol) async {
    var next = state.withToggled(symbol);
    if (next.enabled && next.symbols.isEmpty) {
      // Don't allow empty set while enabled — re-add.
      next = next.copyWith(symbols: {normalizeChordSymbol(symbol)});
    }
    await setVocabulary(next);
  }

  Future<void> applyPreset(Set<String> preset) async {
    await setVocabulary(state.applyPreset(preset, enable: true));
  }

  Future<void> reset() async {
    state = ChordVocabulary.empty;
    await _save();
  }
}

final chordVocabularyProvider =
    NotifierProvider<ChordVocabularyNotifier, ChordVocabulary>(
  ChordVocabularyNotifier.new,
);
