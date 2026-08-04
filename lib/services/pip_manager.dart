// ============================================================
// PiPManager - Picture-in-Picture support
// ============================================================
// Talks to the native side (MainActivity.kt on Android) over a
// MethodChannel. iOS PiP needs an AVPlayerLayer we do not own (mpv
// renders into a texture), so it reports unsupported there for now.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PiPManager {
  static const _channel = MethodChannel('app.smarttube/pip');

  /// Called by the native side when the window enters/leaves PiP.
  static ValueChanged<bool>? onModeChanged;

  /// Called when the user presses Home/Recents while the app is visible.
  static VoidCallback? onUserLeaveHint;

  static bool _handlerInstalled = false;

  /// Whether this platform can host a PiP window at all, without asking
  /// the native side. Lets the UI hide the control rather than offer one
  /// that always fails.
  static bool get isAvailableOnThisPlatform =>
      defaultTargetPlatform == TargetPlatform.android;

  static void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPiPModeChanged':
          onModeChanged?.call(call.arguments as bool? ?? false);
        case 'onUserLeaveHint':
          onUserLeaveHint?.call();
      }
      return null;
    });
  }

  /// Whether this device can show a PiP window (Android 8+ with the
  /// feature enabled). Answered by the platform, not guessed.
  static Future<bool> isSupported() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException catch (e) {
      debugPrint('PiP isSupported failed: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Shrinks the app into a PiP window. [aspectRatio] is width/height.
  static Future<bool> enterPiP({double aspectRatio = 16 / 9}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    _ensureHandler();
    try {
      return await _channel.invokeMethod<bool>(
            'enterPiP',
            {'aspectRatio': aspectRatio},
          ) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('PiP enter failed: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> isPiPActive() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('isPiPActive') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Registers the native callbacks. Call once during app start.
  static void install({
    ValueChanged<bool>? onModeChanged,
    VoidCallback? onUserLeaveHint,
  }) {
    PiPManager.onModeChanged = onModeChanged;
    PiPManager.onUserLeaveHint = onUserLeaveHint;
    _ensureHandler();
  }
}
