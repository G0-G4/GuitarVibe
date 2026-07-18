import 'dart:async';

import '../domain/chord_guess.dart';
import 'feature_extractor.dart';
import 'mic_capture.dart';

/// Mic → analysis frames ([AudioFeatures]).
///
/// Used by play session scoring and Mic Lab.
class MicAnalysisSource {
  MicAnalysisSource({
    this.sampleRate = 44100,
    this.bufferSize = 2048,
    this.computeChroma = true,
    this.computeYin = true,
  }) : _capture = MicCapture(sampleRate: sampleRate);

  final int sampleRate;
  final int bufferSize;
  final bool computeChroma;
  final bool computeYin;

  final MicCapture _capture;
  FeatureExtractor? _extractor;
  bool _running = false;

  Stream<AudioFeatures> get features {
    final e = _extractor;
    if (e == null) return const Stream.empty();
    return e.features;
  }

  bool get isRunning => _running;

  Future<bool> ensurePermission() => _capture.ensurePermission();

  Future<void> start() async {
    if (_running) return;

    final extractor = FeatureExtractor(
      sampleRate: sampleRate,
      bufferSize: bufferSize,
      computeChroma: computeChroma,
      computeYin: computeYin,
    );
    _extractor = extractor;

    await _capture.start();
    extractor.attach(_capture.pcm16);
    _running = true;
  }

  Future<void> stop() async {
    _running = false;
    await _extractor?.detach();
    await _capture.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _extractor?.dispose();
    _extractor = null;
    await _capture.dispose();
  }
}
