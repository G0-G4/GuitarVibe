import 'package:guitar_vibe/domain/calibration.dart';
import 'package:guitar_vibe/domain/noise_suppress.dart';
import 'package:guitar_vibe/domain/recognition_config.dart';
import 'package:flutter_test/flutter_test.dart';

CalibrationFrame _frame(double rms, [double chroma = 0.1]) {
  return CalibrationFrame(
    rms: rms,
    chromaRaw: List<double>.filled(12, chroma),
  );
}

void main() {
  group('buildNoiseProfile', () {
    test('builds from quiet frames', () {
      final frames = <CalibrationFrame>[];
      for (var i = 0; i < 20; i++) {
        frames.add(_frame(0.01 + i * 0.0001, 0.1 + i * 0.001));
      }
      final p = buildNoiseProfile(frames);
      expect(p, isNotNull);
      expect(p!.rmsP95, greaterThan(0));
      expect(p.chromaMean.length, 12);
    });

    test('rejects too many loud outliers', () {
      final frames = <CalibrationFrame>[];
      for (var i = 0; i < 10; i++) {
        frames.add(_frame(0.01));
      }
      for (var i = 0; i < 15; i++) {
        frames.add(_frame(0.2));
      }
      expect(buildNoiseProfile(frames), isNull);
    });
  });

  group('buildGuitarLevelProfile', () {
    test('needs loud frames above noise floor', () {
      final noise = NoiseProfile(
        rmsMean: 0.01,
        rmsP95: 0.012,
        chromaMean: List<double>.filled(12, 0.1),
        calibratedAt: DateTime(2020),
      );
      final quiet = <CalibrationFrame>[];
      for (var i = 0; i < 10; i++) {
        quiet.add(_frame(0.015));
      }
      expect(buildGuitarLevelProfile(quiet, noise: noise), isNull);

      final loud = <CalibrationFrame>[];
      for (var i = 0; i < 10; i++) {
        loud.add(_frame(0.08));
      }
      final g = buildGuitarLevelProfile(loud, noise: noise);
      expect(g, isNotNull);
      expect(g!.rmsMedian, closeTo(0.08, 0.001));
    });
  });

  group('configFromCalibration', () {
    test('uncalibrated uses balanced defaults', () {
      final c = configFromCalibration(CalibrationBundle.empty);
      expect(c.rmsSilence, RecognitionConfig.balanced.rmsSilence);
    });

    test('noise-only raises gate above floor', () {
      final noise = NoiseProfile(
        rmsMean: 0.01,
        rmsP95: 0.02,
        chromaMean: List<double>.filled(12, 0.05),
        calibratedAt: DateTime(2020),
      );
      final c = configFromCalibration(CalibrationBundle(noise: noise));
      expect(c.rmsSilence, greaterThan(noise.rmsP95));
      expect(c.rmsSilence, lessThanOrEqualTo(0.08));
    });

    test('noise + guitar places gate between levels', () {
      final noise = NoiseProfile(
        rmsMean: 0.01,
        rmsP95: 0.02,
        chromaMean: List<double>.filled(12, 0.05),
        calibratedAt: DateTime(2020),
      );
      final guitar = GuitarLevelProfile(
        rmsMedian: 0.1,
        calibratedAt: DateTime(2020),
      );
      final c = configFromCalibration(
        CalibrationBundle(noise: noise, guitar: guitar),
      );
      expect(c.rmsSilence, greaterThan(noise.rmsP95));
      expect(c.rmsSilence, lessThan(guitar.rmsMedian));
    });
  });

  group('subtractChromaNoise', () {
    test('removes noise floor and keeps residual peaks', () {
      final raw = List<double>.filled(12, 0.2);
      raw[0] = 1.0;
      raw[4] = 0.9;
      final noise = List<double>.filled(12, 0.2);
      final cleaned = subtractChromaNoise(raw, noiseMean: noise, gain: 1.0);
      expect(cleaned[0], closeTo(0.8, 1e-9));
      expect(cleaned[1], closeTo(0.0, 1e-9));
    });
  });

  group('highPassSamples', () {
    test('same length', () {
      final s = List<double>.generate(100, (i) => i == 0 ? 1.0 : 0.0);
      final out = highPassSamples(s, sampleRate: 44100);
      expect(out.length, s.length);
    });
  });
}
