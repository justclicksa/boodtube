package com.smarttube.smarttube_poc.player

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.view.Surface
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Bridges [NativePlayerController] to Dart.
 *
 * Frames go out through a [TextureRegistry] texture rather than a PlatformView
 * on purpose: a texture composites inside the Flutter scene, so the app's
 * existing overlay, gesture and mini-player layers keep working exactly as they
 * do over the mpv surface. A PlatformView would punch a native hole through
 * them and every one of those interactions would need rebuilding.
 */
class SmartTubePlayerPlugin(
    private val context: Context,
    private val messenger: BinaryMessenger,
    private val textures: TextureRegistry,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL).also {
        it.setMethodCallHandler(this)
    }
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL).also {
        it.setStreamHandler(this)
    }

    private val main = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var surface: Surface? = null
    private var controller: NativePlayerController? = null

    /**
     * Position and buffer level change continuously with nothing to fire an
     * event, so they are polled. 250 ms is what a progress bar needs to look
     * smooth without waking Dart four times as often as it can use.
     */
    private var ticking = false
    private val tick = object : Runnable {
        override fun run() {
            if (!ticking) return
            controller?.emitState()
            main.postDelayed(this, POSITION_POLL_MS)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> result.success(create())
            "open" -> {
                val videoId = call.argument<String>("videoId")
                if (videoId.isNullOrEmpty()) {
                    result.error("bad_args", "videoId is required", null)
                    return
                }
                ensureController().open(
                    videoId,
                    call.argument<Int>("preferredHeight"),
                ) { code, message ->
                    // The failure is reported on the event channel as well as
                    // here: by the time a resolve fails the Dart call has long
                    // since returned, and a later transport error has no call
                    // to fail at all.
                    emit(mapOf("event" to "error", "code" to code, "message" to message))
                }
                startTicking()
                result.success(null)
            }
            "play" -> {
                controller?.play()
                startTicking()
                result.success(null)
            }
            "pause" -> {
                controller?.pause()
                result.success(null)
            }
            "seek" -> {
                val positionMs = (call.argument<Number>("positionMs") ?: 0).toLong()
                controller?.seek(positionMs)
                result.success(null)
            }
            "setSpeed" -> {
                val speed = (call.argument<Number>("speed") ?: 1).toFloat()
                controller?.setSpeed(speed)
                result.success(null)
            }
            "setVolume" -> {
                val volume = (call.argument<Number>("volume") ?: 1).toFloat()
                controller?.setVolume(volume)
                result.success(null)
            }
            "selectVideoTrack" -> {
                controller?.selectVideoTrack(
                    call.argument<Int>("height"),
                    call.argument<String>("codec"),
                )
                result.success(null)
            }
            "selectAudioTrack" -> {
                val id = call.argument<String>("id")
                if (id != null) controller?.selectAudioTrack(id)
                result.success(null)
            }
            "selectSubtitle" -> {
                controller?.selectSubtitle(call.argument<String>("code"))
                result.success(null)
            }
            "setVideoEnabled" -> {
                controller?.setVideoEnabled(call.argument<Boolean>("enabled") ?: true)
                result.success(null)
            }
            "setBufferPreset" -> {
                ensureController().setBufferPreset(call.argument<String>("preset"))
                result.success(null)
            }
            "dispose" -> {
                disposePlayer()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun create(): Long {
        textureEntry?.let { return it.id() }

        val entry = textures.createSurfaceTexture()
        textureEntry = entry
        val nativeSurface = Surface(entry.surfaceTexture())
        surface = nativeSurface
        ensureController().attachSurface(nativeSurface)
        return entry.id()
    }

    private fun ensureController(): NativePlayerController {
        controller?.let { return it }
        val created = NativePlayerController(context) { event -> emit(event) }
        created.onVideoSize = { width, height ->
            // Without this the texture keeps its default size and the picture
            // is scaled from whatever the buffer happened to be, which shows up
            // as a soft image at high resolutions.
            if (width > 0 && height > 0) {
                textureEntry?.surfaceTexture()?.setDefaultBufferSize(width, height)
            }
        }
        surface?.let(created::attachSurface)
        controller = created
        return created
    }

    private fun startTicking() {
        if (ticking) return
        ticking = true
        main.post(tick)
    }

    private fun stopTicking() {
        ticking = false
        main.removeCallbacks(tick)
    }

    private fun emit(event: Map<String, Any?>) {
        // EventSink is main-thread only, and errors surface from the resolver
        // thread.
        if (Looper.myLooper() == Looper.getMainLooper()) {
            eventSink?.success(event)
        } else {
            main.post { eventSink?.success(event) }
        }
    }

    private fun disposePlayer() {
        stopTicking()
        controller?.release()
        controller = null
        surface?.release()
        surface = null
        textureEntry?.release()
        textureEntry = null
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    /** Called when the Flutter engine goes away; releases the codec session. */
    fun destroy() {
        disposePlayer()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    companion object {
        private const val METHOD_CHANNEL = "app.smarttube/native_player"
        private const val EVENT_CHANNEL = "app.smarttube/native_player/events"
        private const val POSITION_POLL_MS = 250L
    }
}
