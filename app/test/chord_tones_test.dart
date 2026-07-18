import 'package:chord_coach/domain/chord_tones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isNoChord', () {
    test('common markers', () {
      expect(isNoChord('N.C.'), isTrue);
      expect(isNoChord('NC'), isTrue);
      expect(isNoChord('nc'), isTrue);
      expect(isNoChord(''), isTrue);
      expect(isNoChord('  '), isTrue);
      expect(isNoChord('C'), isFalse);
    });
  });

  group('pitchClassesForChord', () {
    test('major triad C', () {
      expect(pitchClassesForChord('C'), {0, 4, 7});
    });

    test('minor triad Am', () {
      expect(pitchClassesForChord('Am'), {9, 0, 4});
    });

    test('G major', () {
      expect(pitchClassesForChord('G'), {7, 11, 2});
    });

    test('F major', () {
      expect(pitchClassesForChord('F'), {5, 9, 0});
    });

    test('dominant 7', () {
      expect(pitchClassesForChord('G7'), {7, 11, 2, 5});
    });

    test('maj7', () {
      expect(pitchClassesForChord('Cmaj7'), {0, 4, 7, 11});
    });

    test('sus4', () {
      expect(pitchClassesForChord('Dsus4'), {2, 7, 9});
    });

    test('sharp root', () {
      expect(pitchClassesForChord('F#m'), {6, 9, 1});
    });

    test('slash chord uses upper only', () {
      expect(pitchClassesForChord('Am/G'), pitchClassesForChord('Am'));
    });

    test('NC empty', () {
      expect(pitchClassesForChord('N.C.'), isEmpty);
    });

    test('invalid empty-ish', () {
      expect(pitchClassesForChord('xyz'), isEmpty);
    });
  });

  group('pitchClassFromHz', () {
    test('A4 = 440 → 9', () {
      expect(pitchClassFromHz(440), 9);
    });

    test('C4 ≈ 261.63 → 0', () {
      expect(pitchClassFromHz(261.63), 0);
    });

    test('invalid', () {
      expect(pitchClassFromHz(0), isNull);
      expect(pitchClassFromHz(-1), isNull);
      expect(pitchClassFromHz(10), isNull);
    });
  });
}
