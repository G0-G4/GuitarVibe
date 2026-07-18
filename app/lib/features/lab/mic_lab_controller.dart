import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/mic_pitch_source.dart';
import '../../domain/calibration.dart';
import '../../domain/chord_guess.dart';
import '../../domain/chord_recognizer.dart';
import '../../domain/recognition_config.dart';
import '../../domain/recognition_mode.dart';
import '../settings/settings_providers.dart';

enum CalibrationPhase {
  idle,
  room,
  guitar,
}

class MicLabState {
  const MicLabState({
    this.listening = false,
    this.error,
    this.guess = ChordGuess.silence,
    this.mode = RecognitionMode.chroma,
    this.calibration = CalibrationBundle.empty,
    this.calPhase = CalibrationPhase.idle,
    this.calProgress = 0,
    this.calMessage,
    this.calError,
    this.config = RecognitionConfig.balanced,
  });

  final bool listening;
  final String? error;
  final ChordGuess guess;
  final RecognitionMode mode;
  final CalibrationBundle calibration;
  final CalibrationPhase calPhase;
  final double calProgress; // 0–1
  final String? calMessage;
  final String? calError;
  final RecognitionConfig config;

  bool get isCalibrating => calPhase != CalibrationPhase.idle;

  MicLabState copyWith({
    bool? listening,
    String? error,
    bool clearError = false,
    ChordGuess? guess,
    RecognitionMode? mode,
    CalibrationBundle? calibration,
    CalibrationPhase? calPhase,
    double? calProgress,
    String? calMessage,
    bool clearCalMessage = false,
    String? calError,
    bool clearCalError = false,
    RecognitionConfig? config,
  }) {
    return MicLabState(
      listening: listening ?? this.listening,
      error: clearError ? null : (error ?? this.error),
      guess: guess ?? this.guess,
      mode: mode ?? this.mode,
      calibration: calibration ?? this.calibration,
      calPhase: calPhase ?? this.calPhase,
      calProgress: calProgress ?? this.calProgress,
      calMessage: clearCalMessage ? null : (calMessage ?? this.calMessage),
      calError: clearCalError ? null : (calError ?? this.calError),
      config: config ?? this.config,
    );
  }
}

class MicLabController extends Notifier<MicLabState> {
  MicAnalysisSource? _mic;
  StreamSubscription<AudioFeatures>? _sub;
  late ChordRecognizer _recognizer;
  bool _disposed = false;

  final List<CalibrationFrame> _calFrames = [];
  DateTime? _calStartedAt;
  Duration _calDuration = Duration.zero;

  @override
  MicLabState build() {
    _disposed = false;
    final mode = ref.read(recognitionModeProvider);
    final cal = ref.read(calibrationProvider);
    final config = ref.read(effectiveRecognitionConfigProvider);
    _recognizer = ChordRecognizer(mode: mode, config: config);

    ref.listen<RecognitionMode>(recognitionModeProvider, (prev, next) {
      if (_disposed) return;
      _recognizer.mode = next;
      _recognizer.reset();
      state = state.copyWith(mode: next);
    });

    ref.listen<CalibrationBundle>(calibrationProvider, (prev, next) {
      if (_disposed) return;
      final cfg = ref.read(effectiveRecognitionConfigProvider);
      _recognizer.config = cfg;
      _recognizer.reset();
      _mic?.updateNoiseProfile(next.noise?.chromaMean);
      state = state.copyWith(calibration: next, config: cfg);
    });

    ref.listen(thresholdPrefsProvider, (prev, next) {
      if (_disposed) return;
      final cfg = ref.read(effectiveRecognitionConfigProvider);
      _recognizer.config = cfg;
      _recognizer.reset();
      state = state.copyWith(config: cfg);
    });

    ref.onDispose(() {
      _disposed = true;
      unawaited(_stop());
    });

    Future.microtask(start);

    return MicLabState(
      mode: mode,
      calibration: cal,
      config: config,
    );
  }

  Future<void> start() async {
    if (_disposed) return;
    await _stop();
    if (_disposed) return;

    final mode = ref.read(recognitionModeProvider);
    final cal = ref.read(calibrationProvider);
    final config = ref.read(effectiveRecognitionConfigProvider);
    _recognizer.mode = mode;
    _recognizer.config = config;
    _recognizer.reset();

    try {
      final mic = MicAnalysisSource(
        noiseChromaMean: cal.noise?.chromaMean,
      );
      await mic.start();
      if (_disposed) {
        await mic.dispose();
        return;
      }
      _mic = mic;
      _sub = mic.features.listen(_onFeatures, onError: (Object e) {
        if (_disposed) return;
        state = state.copyWith(error: '$e', listening: false);
      });
      state = state.copyWith(
        listening: true,
        clearError: true,
        mode: mode,
        calibration: cal,
        config: config,
        guess: ChordGuess.silence,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        listening: false,
        error: 'Mic unavailable: $e',
      );
    }
  }

  void _onFeatures(AudioFeatures f) {
    if (_disposed) return;

    if (state.isCalibrating) {
      _onCalFrame(f);
      return;
    }

    final mode = ref.read(recognitionModeProvider);
    final config = ref.read(effectiveRecognitionConfigProvider);
    if (_recognizer.mode != mode) {
      _recognizer.mode = mode;
      _recognizer.reset();
    }
    if (_recognizer.config.rmsSilence != config.rmsSilence ||
        _recognizer.config.chromaMinScore != config.chromaMinScore) {
      _recognizer.config = config;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final guess = _recognizer.recognize(f, nowMs: nowMs);
    state = state.copyWith(
      guess: guess,
      mode: mode,
      listening: true,
      config: config,
    );
  }

  void _onCalFrame(AudioFeatures f) {
    final started = _calStartedAt;
    if (started == null) return;

    final elapsed = DateTime.now().difference(started);
    final progress =
        (elapsed.inMilliseconds / _calDuration.inMilliseconds).clamp(0.0, 1.0);

    _calFrames.add(
      CalibrationFrame(rms: f.rms, chromaRaw: f.chromaRaw),
    );

    state = state.copyWith(
      calProgress: progress,
      guess: ChordGuess(
        rms: f.rms,
        chroma: f.chroma,
        isSilence: false,
      ),
    );

    if (elapsed >= _calDuration) {
      unawaited(_finishCalibration());
    }
  }

  Future<void> startRoomCalibration() async {
    if (_disposed || state.isCalibrating) return;
    if (_mic == null || !_mic!.isRunning) {
      await start();
    }
    _calFrames.clear();
    _calDuration = const Duration(seconds: 3);
    _calStartedAt = DateTime.now();
    // During room cal, do not subtract old noise profile.
    _mic?.updateNoiseProfile(null);
    state = state.copyWith(
      calPhase: CalibrationPhase.room,
      calProgress: 0,
      calMessage: 'Stay quiet… measuring room noise',
      clearCalError: true,
    );
  }

  Future<void> startGuitarCalibration() async {
    if (_disposed || state.isCalibrating) return;
    if (_mic == null || !_mic!.isRunning) {
      await start();
    }
    _calFrames.clear();
    _calDuration = const Duration(seconds: 2);
    _calStartedAt = DateTime.now();
    state = state.copyWith(
      calPhase: CalibrationPhase.guitar,
      calProgress: 0,
      calMessage: 'Play open chords… measuring level',
      clearCalError: true,
    );
  }

  Future<void> _finishCalibration() async {
    final phase = state.calPhase;
    final frames = List<CalibrationFrame>.from(_calFrames);
    _calStartedAt = null;
    _calFrames.clear();

    if (phase == CalibrationPhase.room) {
      final profile = buildNoiseProfile(frames);
      if (profile == null) {
        state = state.copyWith(
          calPhase: CalibrationPhase.idle,
          calProgress: 0,
          calError:
              'Too much noise during room calibration. Stay quiet and try again.',
          clearCalMessage: true,
        );
        // Restore previous noise subtract if any.
        final prev = ref.read(calibrationProvider).noise?.chromaMean;
        _mic?.updateNoiseProfile(prev);
        return;
      }
      await ref.read(calibrationProvider.notifier).setNoise(profile);
      _mic?.updateNoiseProfile(profile.chromaMean);
      state = state.copyWith(
        calPhase: CalibrationPhase.idle,
        calProgress: 1,
        calMessage: 'Room calibrated',
        clearCalError: true,
        calibration: ref.read(calibrationProvider),
        config: ref.read(effectiveRecognitionConfigProvider),
      );
      return;
    }

    if (phase == CalibrationPhase.guitar) {
      final noise = ref.read(calibrationProvider).noise;
      final profile = buildGuitarLevelProfile(frames, noise: noise);
      if (profile == null) {
        state = state.copyWith(
          calPhase: CalibrationPhase.idle,
          calProgress: 0,
          calError: 'Play louder / closer to the mic and try again.',
          clearCalMessage: true,
        );
        return;
      }
      await ref.read(calibrationProvider.notifier).setGuitar(profile);
      state = state.copyWith(
        calPhase: CalibrationPhase.idle,
        calProgress: 1,
        calMessage: 'Guitar level calibrated',
        clearCalError: true,
        calibration: ref.read(calibrationProvider),
        config: ref.read(effectiveRecognitionConfigProvider),
      );
    }
  }

  Future<void> resetCalibration() async {
    await ref.read(calibrationProvider.notifier).reset();
    _mic?.updateNoiseProfile(null);
    final config = ref.read(effectiveRecognitionConfigProvider);
    _recognizer.config = config;
    _recognizer.reset();
    state = state.copyWith(
      calibration: CalibrationBundle.empty,
      config: config,
      calPhase: CalibrationPhase.idle,
      calProgress: 0,
      calMessage: 'Calibration reset',
      clearCalError: true,
    );
  }

  Future<void> setMode(RecognitionMode mode) async {
    await ref.read(recognitionModeProvider.notifier).setMode(mode);
    _recognizer.mode = mode;
    _recognizer.reset();
    state = state.copyWith(mode: mode);
  }

  Future<void> _stop() async {
    _calStartedAt = null;
    _calFrames.clear();
    await _sub?.cancel();
    _sub = null;
    final mic = _mic;
    _mic = null;
    await mic?.dispose();
  }
}

final micLabProvider =
    NotifierProvider.autoDispose<MicLabController, MicLabState>(
  MicLabController.new,
);
