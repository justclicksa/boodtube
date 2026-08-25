package com.smarttube.smarttube_poc

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import com.smarttube.smarttube_poc.player.SmartTubePlayerPlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// audio_service requires the host activity to extend AudioServiceActivity
// so the media session survives the app going to the background.
class MainActivity : AudioServiceActivity() {

    private var channel: MethodChannel? = null

    // The native playback engine (forked ExoPlayer + MediaServiceCore). It is
    // registered by hand rather than as a pubspec plugin because it lives in
    // this app module, next to the SmartTube modules it links against.
    private var playerPlugin: SmartTubePlayerPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        playerPlugin = SmartTubePlayerPlugin(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
            flutterEngine.renderer,
        )

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(isPipSupported())
                    "enterPiP" -> result.success(enterPip(call.argument("aspectRatio")))
                    "isPiPActive" -> result.success(isInPipMode())
                    // Leaving PiP is user-driven on Android: tapping the
                    // window restores the activity, so this just reports
                    // the current state instead of pretending to act.
                    "exitPiP" -> result.success(!isInPipMode())
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun isPipSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun isInPipMode(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInPictureInPictureMode

    private fun enterPip(aspectRatio: Double?): Boolean {
        if (!isPipSupported()) return false
        return try {
            // Android rejects ratios outside roughly 1:2.39 .. 2.39:1.
            val ratio = (aspectRatio ?: (16.0 / 9.0)).coerceIn(0.42, 2.39)
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational((ratio * 1000).toInt(), 1000))
                .build()
            enterPictureInPictureMode(params)
        } catch (e: IllegalStateException) {
            // Thrown when the activity is not resumed or PiP is disabled
            // for the user/device.
            false
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channel?.invokeMethod("onPiPModeChanged", isInPictureInPictureMode)
    }

    override fun onDestroy() {
        // Releases the MediaCodec session with the activity; leaving it open
        // keeps a decoder reserved for a player nothing can reach any more.
        playerPlugin?.destroy()
        playerPlugin = null
        super.onDestroy()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // The Dart side decides whether "press Home while playing" should
        // enter PiP, since it knows if a video is on screen.
        channel?.invokeMethod("onUserLeaveHint", null)
    }

    companion object {
        private const val CHANNEL = "app.smarttube/pip"
    }
}
