import 'package:flutter_test/flutter_test.dart';
import 'package:smarttube_poc/presentation/screens/player/video_transform.dart';

void main() {
  group('VideoAspect', () {
    test('maps every preset to PlayerConstants ASPECT_RATIO_*', () {
      // The rounded values are SmartTube's, not exact fractions: keeping
      // them identical is the whole point of the parity work.
      expect(VideoAspect.auto.ratio, isNull);
      expect(VideoAspect.r1_1.ratio, 1);
      expect(VideoAspect.r4_3.ratio, 1.33);
      expect(VideoAspect.r5_4.ratio, 1.25);
      expect(VideoAspect.r16_9.ratio, 1.77);
      expect(VideoAspect.r16_10.ratio, 1.6);
      expect(VideoAspect.r21_9.ratio, 2.33);
      expect(VideoAspect.r64_27.ratio, 2.37);
      expect(VideoAspect.r2_21.ratio, 2.21);
      expect(VideoAspect.r2_35.ratio, 2.35);
      expect(VideoAspect.r2_39.ratio, 2.39);
    });

    test('covers the native list exactly once', () {
      expect(VideoAspect.values, hasLength(11));
      final ratios = VideoAspect.values
          .where((aspect) => !aspect.isAuto)
          .map((aspect) => aspect.ratio)
          .toList();
      expect(ratios.toSet(), hasLength(ratios.length));
    });

    test('only auto has no typeset label', () {
      expect(VideoAspect.auto.shortLabel, isNull);
      expect(VideoAspect.r16_9.shortLabel, '16:9');
      expect(VideoAspect.r21_9.shortLabel, '21:9 (2.33:1)');
      for (final aspect in VideoAspect.values.where((a) => !a.isAuto)) {
        expect(aspect.shortLabel, isNotNull, reason: aspect.name);
      }
    });

    test('reads stored names back, falling back to auto', () {
      expect(videoAspectFromName('r16_9'), VideoAspect.r16_9);
      expect(videoAspectFromName('r2_39'), VideoAspect.r2_39);
      expect(videoAspectFromName(null), VideoAspect.auto);
      expect(videoAspectFromName('r3_2_from_a_newer_build'), VideoAspect.auto);
    });
  });

  group('rotation', () {
    test('offers the four native angles', () {
      expect(videoRotationAngles, [0, 90, 180, 270]);
    });

    test('snaps and wraps any angle', () {
      expect(normalizeRotation(0), 0);
      expect(normalizeRotation(90), 90);
      expect(normalizeRotation(360), 0);
      expect(normalizeRotation(450), 90);
      expect(normalizeRotation(-90), 270);
      expect(normalizeRotation(100), 90);
    });

    test('converts to quarter turns for RotatedBox', () {
      expect(quarterTurnsFor(0), 0);
      expect(quarterTurnsFor(90), 1);
      expect(quarterTurnsFor(180), 2);
      expect(quarterTurnsFor(270), 3);
      expect(quarterTurnsFor(-90), 3);
    });

    test('cycles back to zero', () {
      var angle = 0;
      final seen = <int>[];
      for (var i = 0; i < 5; i++) {
        seen.add(angle);
        angle = nextRotation(angle);
      }
      expect(seen, [0, 90, 180, 270, 0]);
    });
  });

  group('zoom', () {
    test('clamps to the 100-300% slider range', () {
      expect(normalizeZoomPercent(100), 100);
      expect(normalizeZoomPercent(150), 150);
      expect(normalizeZoomPercent(300), 300);
      expect(normalizeZoomPercent(50), 100);
      expect(normalizeZoomPercent(1000), 300);
      expect(normalizeZoomPercent(double.nan), 100);
    });

    test('converts percentage to a Transform.scale factor', () {
      expect(zoomScaleFor(100), 1);
      expect(zoomScaleFor(150), 1.5);
      expect(zoomScaleFor(300), 3);
      // Out of range values scale as their clamped counterpart.
      expect(zoomScaleFor(20), 1);
    });

    test('recognises the no-op case so the wrapper can be skipped', () {
      expect(isIdentityZoom(100), isTrue);
      expect(isIdentityZoom(99), isTrue, reason: 'clamped up to 100');
      expect(isIdentityZoom(100.005), isTrue);
      expect(isIdentityZoom(101), isFalse);
      expect(isIdentityZoom(300), isFalse);
    });
  });
}
