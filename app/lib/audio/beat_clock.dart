import 'dart:async';

/// Monotonic beat clock driven by a stopwatch.
///
/// Maps wall time → song beat via [tempoBpm]. Beat may start negative
/// (count-in). When [masterPosition] is provided each tick (audio path),
/// that duration is used instead of the internal stopwatch.
class BeatClock {
  BeatClock({
    required this.tempoBpm,
    this.tickInterval = const Duration(milliseconds: 16),
  });

  double tempoBpm;
  final Duration tickInterval;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  void Function(double beat)? onTick;

  /// Song beat at the moment the clock was (re)started or seeked.
  double _originBeat = 0;

  /// Elapsed media time corresponding to [_originBeat] (stopwatch zero).
  Duration _originElapsed = Duration.zero;

  /// Optional external master (e.g. audio position). When set, ticks use this.
  Duration Function()? masterPosition;

  bool get isRunning => _stopwatch.isRunning || _timer != null;

  double get currentBeat {
    final elapsed = masterPosition?.call() ?? _stopwatch.elapsed;
    final deltaSec =
        (elapsed - _originElapsed).inMicroseconds / Duration.microsecondsPerSecond;
    final deltaBeats = deltaSec * tempoBpm / 60.0;
    return _originBeat + deltaBeats;
  }

  /// Start (or restart) from [startBeat], usually `-countInBeats`.
  void start({double startBeat = 0}) {
    stop();
    _originBeat = startBeat;
    _originElapsed = masterPosition?.call() ?? Duration.zero;
    _stopwatch
      ..reset()
      ..start();
    _timer = Timer.periodic(tickInterval, (_) {
      onTick?.call(currentBeat);
    });
    onTick?.call(currentBeat);
  }

  void pause() {
    if (!_stopwatch.isRunning && masterPosition == null) return;
    // Freeze origin at current beat so resume continues correctly.
    final beat = currentBeat;
    _originBeat = beat;
    _originElapsed = masterPosition?.call() ?? _stopwatch.elapsed;
    _stopwatch.stop();
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_timer != null) return;
    _originBeat = currentBeat;
    _originElapsed = masterPosition?.call() ?? _stopwatch.elapsed;
    if (masterPosition == null) {
      _stopwatch.start();
    } else {
      // Audio path: master keeps time; we only need the timer for UI ticks.
      _stopwatch
        ..reset()
        ..start();
    }
    _timer = Timer.periodic(tickInterval, (_) {
      onTick?.call(currentBeat);
    });
    onTick?.call(currentBeat);
  }

  void seekBeat(double beat) {
    _originBeat = beat;
    _originElapsed = masterPosition?.call() ?? _stopwatch.elapsed;
    onTick?.call(currentBeat);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    _stopwatch.reset();
    _originBeat = 0;
    _originElapsed = Duration.zero;
  }

  void dispose() {
    stop();
    onTick = null;
    masterPosition = null;
  }
}
