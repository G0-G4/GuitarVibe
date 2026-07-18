import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/mic_pitch_source.dart';
import '../../domain/chord_guess.dart';
import '../../domain/chord_recognizer.dart';
import '../../domain/recognition_mode.dart';
import '../settings/settings_providers.dart';

class MicLabState {
  const MicLabState({
    this.listening = false,
    this.error,
    this.guess = ChordGuess.silence,
    this.mode = RecognitionMode.chroma,
  });

  final bool listening;
  final String? error;
  final ChordGuess guess;
  final RecognitionMode mode;

  MicLabState copyWith({
    bool? listening,
    String? error,
    bool clearError = false,
    ChordGuess? guess,
    RecognitionMode? mode,
  }) {
    return MicLabState(
      listening: listening ?? this.listening,
      error: clearError ? null : (error ?? this.error),
      guess: guess ?? this.guess,
      mode: mode ?? this.mode,
    );
  }
}

class MicLabController extends Notifier<MicLabState> {
  MicAnalysisSource? _mic;
  StreamSubscription<AudioFeatures>? _sub;
  final ChordRecognizer _recognizer = ChordRecognizer();
  bool _disposed = false;

  @override
  MicLabState build() {
    _disposed = false;
    final mode = ref.read(recognitionModeProvider);
    _recognizer.mode = mode;

    ref.listen<RecognitionMode>(recognitionModeProvider, (prev, next) {
      if (_disposed) return;
      _recognizer.mode = next;
      _recognizer.reset();
      state = state.copyWith(mode: next);
    });

    ref.onDispose(() {
      _disposed = true;
      unawaited(_stop());
    });

    // Auto-start when screen mounts.
    Future.microtask(start);

    return MicLabState(mode: mode);
  }

  Future<void> start() async {
    if (_disposed) return;
    await _stop();
    if (_disposed) return;

    final mode = ref.read(recognitionModeProvider);
    _recognizer.mode = mode;
    _recognizer.reset();

    try {
      final mic = MicAnalysisSource();
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
    final mode = ref.read(recognitionModeProvider);
    if (_recognizer.mode != mode) {
      _recognizer.mode = mode;
      _recognizer.reset();
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final guess = _recognizer.recognize(f, nowMs: nowMs);
    state = state.copyWith(guess: guess, mode: mode, listening: true);
  }

  Future<void> setMode(RecognitionMode mode) async {
    await ref.read(recognitionModeProvider.notifier).setMode(mode);
    _recognizer.mode = mode;
    _recognizer.reset();
    state = state.copyWith(mode: mode);
  }

  Future<void> _stop() async {
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
