import 'dart:async';
import 'dart:typed_data';

import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitch_detector_dart/pitch_detector_result.dart';
import 'package:record/record.dart';

/// A single YIN pitch estimate from the mic.
class PitchSample {
  const PitchSample({
    required this.hz,
    required this.confidence,
  });

  final double hz;
  final double confidence;
}

/// Streams pitch estimates from the device microphone (PCM16 + YIN).
///
/// Pure I/O facade — scoring logic lives in [ScoreEngine].
class MicPitchSource {
  MicPitchSource({
    this.sampleRate = PitchDetector.DEFAULT_SAMPLE_RATE,
    this.bufferSize = PitchDetector.DEFAULT_BUFFER_SIZE,
  });

  final int sampleRate;
  final int bufferSize;

  final AudioRecorder _recorder = AudioRecorder();
  PitchDetector? _detector;
  StreamSubscription<Uint8List>? _sub;
  final BytesBuilder _pending = BytesBuilder();
  bool _busy = false;
  bool _running = false;

  final StreamController<PitchSample> _controller =
      StreamController<PitchSample>.broadcast();

  Stream<PitchSample> get pitches => _controller.stream;
  bool get isRunning => _running;

  /// Request mic permission (shows system prompt when needed).
  Future<bool> ensurePermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (_running) return;

    final ok = await ensurePermission();
    if (!ok) {
      throw StateError('Microphone permission denied');
    }

    _detector = PitchDetector(
      audioSampleRate: sampleRate.toDouble(),
      bufferSize: bufferSize,
    );
    _pending.clear();
    _busy = false;

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );

    _running = true;
    _sub = stream.listen(
      _onPcm,
      onError: (Object e, StackTrace st) {
        if (!_controller.isClosed) {
          _controller.addError(e, st);
        }
      },
      cancelOnError: false,
    );
  }

  void _onPcm(Uint8List chunk) {
    if (!_running || _detector == null) return;
    _pending.add(chunk);

    // Cap backlog: keep at most ~2 analysis frames (prefer low latency).
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
    _processFrame(frame);
  }

  Future<void> _processFrame(Uint8List pcm16) async {
    final detector = _detector;
    if (detector == null || _busy) return;
    _busy = true;
    try {
      final PitchDetectorResult result =
          await detector.getPitchFromIntBuffer(pcm16);
      if (!_running || _controller.isClosed) return;
      if (result.pitched && result.pitch > 0) {
        _controller.add(
          PitchSample(hz: result.pitch, confidence: result.probability),
        );
      }
    } catch (_) {
      // Drop bad frames (buffer size / transient errors).
    } finally {
      _busy = false;
      if (_running) _drain();
    }
  }

  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    _pending.clear();
    _detector = null;
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
    await _controller.close();
  }
}
