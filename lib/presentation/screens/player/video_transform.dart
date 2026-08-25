// ============================================================
// Video transform — aspect override, rotation, flip, zoom
// ============================================================
// SmartTube layers three transforms on top of the resize mode: a forced
// display aspect ratio, a rotation angle, and a zoom percentage. The
// tables here mirror PlayerConstants.ASPECT_RATIO_* one for one so the
// Flutter player lands on exactly the same numbers.
//
// Everything in this file is deliberately widget-free and side-effect
// free: the player screen turns these values into an `AspectRatio` /
// `RotatedBox` / `Transform` wrapper, and the unit tests can pin the
// mapping without booting a player.
// ============================================================

// The aspect names are read as ratios ("16:9"), not as identifiers, so
// the underscore spelling is the clearest thing they can be called.
// ignore_for_file: constant_identifier_names

/// Forced display aspect ratio — SmartTube's "Video aspect" list.
///
/// [auto] leaves the stream's own ratio alone; every other value
/// deforms the picture to that ratio the way ExoPlayer's
/// `AspectRatioFrameLayout` does when given an explicit ratio.
enum VideoAspect {
  auto,
  r1_1,
  r4_3,
  r5_4,
  r16_9,
  r16_10,
  r21_9,
  r64_27,
  r2_21,
  r2_35,
  r2_39,
}

extension VideoAspectX on VideoAspect {
  /// The ratio to force, or `null` for [VideoAspect.auto].
  ///
  /// The rounded constants come straight from PlayerConstants: SmartTube
  /// stores 1.77 rather than 16/9, and matching it keeps a video that
  /// looks right on the TV looking right here.
  double? get ratio => switch (this) {
        VideoAspect.auto => null,
        VideoAspect.r1_1 => 1,
        VideoAspect.r4_3 => 1.33,
        VideoAspect.r5_4 => 1.25,
        VideoAspect.r16_9 => 1.77,
        VideoAspect.r16_10 => 1.6,
        VideoAspect.r21_9 => 2.33,
        VideoAspect.r64_27 => 2.37,
        VideoAspect.r2_21 => 2.21,
        VideoAspect.r2_35 => 2.35,
        VideoAspect.r2_39 => 2.39,
      };

  bool get isAuto => this == VideoAspect.auto;

  /// The ratio the way the menu writes it. `null` for [VideoAspect.auto],
  /// whose label is translated rather than typeset.
  String? get shortLabel => switch (this) {
        VideoAspect.auto => null,
        VideoAspect.r1_1 => '1:1',
        VideoAspect.r4_3 => '4:3',
        VideoAspect.r5_4 => '5:4',
        VideoAspect.r16_9 => '16:9',
        VideoAspect.r16_10 => '16:10',
        VideoAspect.r21_9 => '21:9 (2.33:1)',
        VideoAspect.r64_27 => '64:27 (2.37:1)',
        VideoAspect.r2_21 => '2.21:1',
        VideoAspect.r2_35 => '2.35:1',
        VideoAspect.r2_39 => '2.39:1',
      };
}

/// Reads back a stored [VideoAspect], falling back to [VideoAspect.auto]
/// for anything an older or newer build wrote.
VideoAspect videoAspectFromName(String? name) => VideoAspect.values.firstWhere(
      (aspect) => aspect.name == name,
      orElse: () => VideoAspect.auto,
    );

// ============================================================
// Rotation
// ============================================================

/// The angles the menu offers, matching `createVideoRotateCategory`.
const videoRotationAngles = <int>[0, 90, 180, 270];

/// Snaps any angle onto one of [videoRotationAngles].
int normalizeRotation(int degrees) {
  final wrapped = degrees % 360;
  final positive = wrapped < 0 ? wrapped + 360 : wrapped;
  return (positive ~/ 90) * 90;
}

/// Quarter turns for a `RotatedBox`. Uses `RotatedBox` rather than
/// `Transform.rotate` so a 90°/270° turn re-lays-out the child against
/// the swapped constraints instead of painting a wide frame sideways
/// into a wide box and clipping most of it away.
int quarterTurnsFor(int degrees) => normalizeRotation(degrees) ~/ 90;

/// Next angle in the 0 → 90 → 180 → 270 → 0 cycle.
int nextRotation(int degrees) => normalizeRotation(degrees + 90);

// ============================================================
// Zoom
// ============================================================

/// SmartTube's zoom list runs well below 100% too, but zooming out of a
/// letterboxed surface only adds black, so the slider starts at 1:1.
const minZoomPercent = 100.0;
const maxZoomPercent = 300.0;

double normalizeZoomPercent(double percent) {
  if (percent.isNaN) return minZoomPercent;
  return percent.clamp(minZoomPercent, maxZoomPercent);
}

/// The `Transform.scale` factor for a zoom percentage.
double zoomScaleFor(double percent) => normalizeZoomPercent(percent) / 100;

/// True when no scaling is needed and the wrapper can be skipped.
bool isIdentityZoom(double percent) =>
    (normalizeZoomPercent(percent) - 100).abs() < 0.01;
