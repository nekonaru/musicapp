import 'package:flutter_test/flutter_test.dart';
import 'package:swara/services/equalizer_service.dart';

void main() {
  group('resampleCurve', () {
    test('same size returns equal values', () {
      expect(
        resampleCurve([0, 1, 2, 3, 4], 5),
        [0, 1, 2, 3, 4],
      );
    });

    test('single band returns the average', () {
      expect(resampleCurve([0, 2, 4, 6, 8], 1), [4.0]);
    });

    test('upsampling interpolates linearly', () {
      final out = resampleCurve([0, 10], 3);
      expect(out.length, 3);
      expect(out[0], moreOrLessEquals(0));
      expect(out[1], moreOrLessEquals(5));
      expect(out[2], moreOrLessEquals(10));
    });

    test('downsampling keeps endpoints', () {
      final out = resampleCurve([0, 1, 2, 3, 4], 2);
      expect(out.length, 2);
      expect(out.first, moreOrLessEquals(0));
      expect(out.last, moreOrLessEquals(4));
    });

    test('empty curve and non-positive bands are safe', () {
      expect(resampleCurve([], 5), [0, 0, 0, 0, 0]);
      expect(resampleCurve([1, 2, 3, 4, 5], 0), isEmpty);
    });
  });

  group('kEqCurves', () {
    test('flat preset is all zeros', () {
      expect(kEqCurves['Flat'], [0, 0, 0, 0, 0]);
    });

    test('every preset has five bands', () {
      for (final entry in kEqCurves.entries) {
        expect(entry.value.length, 5, reason: entry.key);
      }
    });
  });
}
