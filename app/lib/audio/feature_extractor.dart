import 'dart:async';
import 'dart:typed_data';

import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitch_detector_dart/pitch_detector_result.dart';

import '../domain/chord_guess.dart';
import '../domain/chroma.dart';
import '../domain/noise_suppress.dart';

/// Builds [AudioFeatures] frames from a PCM16 byte stream.
class FeatureExtractor {
  FeatureExtractor({
    this.sampleRate = PitchDetector.DEFAULT_SAMPLE_RATE,
    this.bufferSize = PitchDetector.DEFAULT_BUFFER_SIZE,
    this.computeChroma = true,
    this.computeYin = true,
    this.applyHighPass = true,
    this.noiseChromaMean,
    this.noiseSubtractGain = 1.0,
  });

  final int sampleRate;
  final int bufferSize;
  final bool computeChroma;
  final bool computeYin;
  final bool applyHighPass;

  /// Raw noise chroma mean from room calibration (optional).
  List<double>? noiseChromaMean;
  double noiseSubtractGain;

  PitchDetector? _detector;
  final BytesBuilder _pending = BytesBuilder();
  bool _busy = false;
  bool _running = false;
  StreamSubscription<Uint8List>? _sub;

  final StreamController<AudioFeatures> _controller =
      StreamController<AudioFeatures>.broadcast();

  Stream<AudioFeatures> get features => _controller.stream;

  void attach(Stream<Uint8List> pcm16) {
    _detector = PitchDetector(
      audioSampleRate: sampleRate.toDouble(),
      bufferSize: bufferSize,
    );
    _pending.clear();
    _busy = false;
    _running = true;
    _sub = pcm16.listen(
      _onPcm,
      onError: (Object e, StackTrace st) {
        if (!_controller.isClosed) _controller.addError(e, st);
      },
    );
  }

  void _onPcm(Uint8List chunk) {
    if (!_running) return;
    _pending.add(chunk);

    final needBytes = bufferSize * 2;
    final maxBytes = needBytes * 2;
    if (_pending.length > maxBytes) {
      final all = _pending.takeBytes();
      final start = all.length - needBytes;
      _pending.add(Uint8List.sublistView(all, start));
    }
    _drain();
  }

  void _drain() {
    final needBytes = bufferSize * 2;
    if (_busy || !_running || _pending.length < needBytes) return;

    final all = _pending.takeBytes();
    final frame = Uint8List.fromList(all.sublist(0, needBytes));
    if (all.length > needBytes) {
      _pending.add(Uint8List.sublistView(all, needBytes));
    }
    unawaited(_processFrame(frame));
  }

  Future<void> _processFrame(Uint8List pcm16) async {
    if (_busy) return;
    _busy = true;
    try {
      var floats = pcm16ToFloat(pcm16);
      if (applyHighPass) {
        floats = highPassSamples(
          floats,
          sampleRate: sampleRate.toDouble(),
        );
      }
      final rms = computeRms(floats);

      List<double> chromaRaw = const [];
      List<double> chroma = const [];
      if (computeChroma) {
        chromaRaw = chromaRawFromSamples(
          floats,
          sampleRate: sampleRate.toDouble(),
        );
        final cleaned = subtractChromaNoise(
          chromaRaw,
          noiseMean: noiseChromaMean,
          gain: noiseSubtractGain,
        );
        chroma = l2Normalize(cleaned);
      }

      double? yinHz;
      double? yinConf;
      if (computeYin && _detector != null) {
        try {
          final PitchDetectorResult result =
              await _detector!.getPitchFromIntBuffer(pcm16);
          if (result.pitched && result.pitch > 0) {
            yinHz = result.pitch;
            yinConf = result.probability;
          }
        } catch (_) {}
      }

      if (!_running || _controller.isClosed) return;
      _controller.add(
        AudioFeatures(
          rms: rms,
          chroma: chroma,
          chromaRaw: chromaRaw,
          yinHz: yinHz,
          yinConfidence: yinConf,
        ),
      );
    } finally {
      _busy = false;
      if (_running) _drain();
    }
  }

  Future<void> detach() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    _pending.clear();
    _detector = null;
  }

  Future<void> dispose() async {
    await detach();
    await _controller.close();
  }
}
