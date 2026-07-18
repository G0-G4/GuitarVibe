import 'package:chord_coach/domain/recognition_config.dart';
import 'package:chord_coach/domain/threshold_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThresholdPrefs', () {
    test('sensitive has lower min score than strict', () {
      const base = RecognitionConfig.balanced;
      final easy = const ThresholdPrefs(sensitivity: 0.0).applyTo(base);
      final hard = const ThresholdPrefs(sensitivity: 1.0).applyTo(base);
      expect(easy.chromaMinScore, lessThan(hard.chromaMinScore));
      expect(easy.chromaMargin, lessThan(hard.chromaMargin));
      expect(easy.chromaHoldMs, lessThan(hard.chromaHoldMs));
    });

    test('advanced overrides sensitivity', () {
      const base = RecognitionConfig.balanced;
      final prefs = const ThresholdPrefs(
        sensitivity: 1.0,
        useAdvanced: true,
        chromaMinScore: 0.40,
        chromaMargin: 0.01,
      );
      final c = prefs.applyTo(base);
      expect(c.chromaMinScore, closeTo(0.40, 1e-9));
      expect(c.chromaMargin, closeTo(0.01, 1e-9));
    });

    test('json round-trip', () {
      const original = ThresholdPrefs(
        sensitivity: 0.3,
        useAdvanced: true,
        chromaMinScore: 0.41,
        requireYinForHybrid: false,
      );
      final back = ThresholdPrefs.fromJson(original.toJson());
      expect(back.sensitivity, original.sensitivity);
      expect(back.useAdvanced, isTrue);
      expect(back.chromaMinScore, original.chromaMinScore);
      expect(back.requireYinForHybrid, isFalse);
    });
  });
}
