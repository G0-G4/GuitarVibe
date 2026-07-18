import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Raw microphone PCM16 stream (no analysis).
class MicCapture {
  MicCapture({
    this.sampleRate = 44100,
  });

  final int sampleRate;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  bool _running = false;

  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get pcm16 => _controller.stream;
  bool get isRunning => _running;

  Future<bool> ensurePermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (_running) return;

    final ok = await ensurePermission();
    if (!ok) {
      throw StateError('Microphone permission denied');
    }

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );

    _running = true;
    _sub = stream.listen(
      (chunk) {
        if (!_running || _controller.isClosed) return;
        _controller.add(chunk);
      },
      onError: (Object e, StackTrace st) {
        if (!_controller.isClosed) {
          _controller.addError(e, st);
        }
      },
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
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
