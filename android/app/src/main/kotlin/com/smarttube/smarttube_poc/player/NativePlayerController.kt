package com.smarttube.smarttube_poc.player

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import com.google.android.exoplayer2.C
import com.google.android.exoplayer2.DefaultLoadControl
import com.google.android.exoplayer2.DefaultRenderersFactory
import com.google.android.exoplayer2.ExoPlaybackException
import com.google.android.exoplayer2.ExoPlayerFactory
import com.google.android.exoplayer2.Format
import com.google.android.exoplayer2.PlaybackParameters
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.SimpleExoPlayer
import com.google.android.exoplayer2.audio.AudioAttributes
import com.google.android.exoplayer2.source.TrackGroupArray
import com.google.android.exoplayer2.trackselection.AdaptiveTrackSelection
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector
import com.google.android.exoplayer2.trackselection.MappingTrackSelector
import com.google.android.exoplayer2.trackselection.TrackSelectionArray
import com.google.android.exoplayer2.video.VideoListener
import com.liskovsoft.mediaserviceinterfaces.data.MediaItemFormatInfo
import com.liskovsoft.sharedutils.prefs.GlobalPreferences
import com.liskovsoft.youtubeapi.service.YouTubeServiceManager
import com.smarttube.smarttube_poc.player.exo.SmartTubeMediaSourceFactory
import java.util.concurrent.Executors

/**
 * Plays YouTube video with the same engine the SmartTube TV app uses: the
 * forked ExoPlayer 2.10.6 (SABR module and DashManifestParser2 included) fed by
 * MediaServiceCore's stream resolution.
 *
 * The point of resolving natively rather than in Dart is that MediaServiceCore
 * hands back a *manifest*, not a pair of URLs. Every rendition of the video is
 * described in one object, so switching quality is a track selection inside a
 * stream that is already open — no re-resolve, no re-open, no lost buffer. It
 * also means the signature / n-sig decipher and PoToken handling run in the
 * same battle-tested code the TV app ships, instead of a second implementation.
 *
 * Everything here is driven from the main thread except the one call that must
 * not be: [MediaItemService.getFormatInfo] does network I/O synchronously.
 */
class NativePlayerController(
    private val context: Context,
    private val events: (Map<String, Any?>) -> Unit,
) {
    private companion object {
        const val TAG = "SmartTubePlayer"
    }

    private val main = Handler(Looper.getMainLooper())

    // A single thread, not a pool: resolutions for one player are inherently
    // sequential, and serialising them means a quality change that arrives
    // while a video is still resolving cannot overtake it.
    private val resolver = Executors.newSingleThreadExecutor()

    private var player: SimpleExoPlayer? = null
    private var trackSelector: DefaultTrackSelector? = null
    private var sourceFactory: SmartTubeMediaSourceFactory? = null
    private var surface: Surface? = null

    /** Bumped on every open so a resolution that lost the race is discarded. */
    private var openGeneration = 0

    private var bufferPreset = BufferPreset.MEDIUM
    private var lastReportedFormat: Format? = null
    private var currentSourceKind: String? = null

    /**
     * Height ceiling for video selection, or null for "let ExoPlayer adapt".
     * Kept because it has to be re-applied to every newly opened video.
     */
    private var preferredHeight: Int? = null

    private var released = false

    enum class BufferPreset(val wireName: String, val minMs: Int, val maxMs: Int) {
        // Mirrors SmartTube's ExoPlayerInitializer presets. LOW exists for live
        // streams, where a deep buffer means being minutes behind the edge.
        LOW("low", 5_000, 5_000),
        MEDIUM("medium", 30_000, 30_000),
        HIGH("high", 50_000, 50_000),
        HIGHEST("highest", 50_000, 100_000);

        companion object {
            fun from(name: String?): BufferPreset =
                values().firstOrNull { it.wireName == name } ?: MEDIUM
        }
    }

    // ---------------------------------------------------------------- setup

    fun attachSurface(surface: Surface) {
        this.surface = surface
        player?.setVideoSurface(surface)
    }

    private fun ensurePlayer(): SimpleExoPlayer {
        player?.let { return it }

        val selector = DefaultTrackSelector(AdaptiveTrackSelection.Factory())
        val renderers = DefaultRenderersFactory(context)
            // The forked ExoPlayer can ship software decoders as extension
            // renderers. PREFER would use them ahead of MediaCodec; ON keeps
            // hardware first and falls back only when the device genuinely
            // cannot decode a format — which is the case this exists for.
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON)

        val created = ExoPlayerFactory.newSimpleInstance(
            context, renderers, selector, buildLoadControl(bufferPreset),
        )
        created.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.CONTENT_TYPE_MOVIE)
                .build(),
            /* handleAudioFocus= */ true,
        )
        created.addListener(playerListener)
        created.addVideoListener(videoListener)
        surface?.let(created::setVideoSurface)

        player = created
        trackSelector = selector
        sourceFactory = SmartTubeMediaSourceFactory(context)
        return created
    }

    private fun buildLoadControl(preset: BufferPreset): DefaultLoadControl {
        val builder = DefaultLoadControl.Builder()
        if (preset == BufferPreset.HIGHEST) {
            // Only the top preset takes the memory: SmartTube sizes this from
            // device RAM, and keeping a back buffer is what makes a short
            // rewind instant instead of a re-download.
            builder.setTargetBufferBytes(maxBufferBytes())
            builder.setBackBuffer(50_000, /* retainBackBufferFromKeyframe= */ true)
        } else if (preset == BufferPreset.HIGH) {
            builder.setBackBuffer(50_000, true)
        }
        return builder
            .setBufferDurationsMs(
                preset.minMs,
                preset.maxMs,
                /* bufferForPlaybackMs= */ 2_500,
                /* bufferForPlaybackAfterRebufferMs= */ 5_000,
            )
            .createDefaultLoadControl()
    }

    private fun maxBufferBytes(): Int {
        val runtime = Runtime.getRuntime()
        // SmartTube divides total device RAM by 18. maxMemory() is the heap
        // ceiling rather than device RAM, so the divisor is smaller; the point
        // is the same — never let one video's buffer own the whole heap.
        val fromHeap = (runtime.maxMemory() / 4).toInt()
        return fromHeap.coerceIn(24_000_000, 196_000_000)
    }

    // ----------------------------------------------------------- public API

    fun setBufferPreset(name: String?) {
        val next = BufferPreset.from(name)
        if (next == bufferPreset) return
        bufferPreset = next
        // The LoadControl is fixed at construction, so the preset only takes
        // effect on the next player. Rebuilding it here would cost the user
        // their position for a setting that matters from the next video on.
    }

    /**
     * Resolves [videoId] through MediaServiceCore and opens the best rendition
     * family for it. [onError] receives a stable code so Dart can tell an
     * unplayable video from a transport failure.
     */
    fun open(
        videoId: String,
        preferredHeight: Int?,
        onError: (code: String, message: String) -> Unit,
    ) {
        this.preferredHeight = preferredHeight
        val generation = ++openGeneration
        currentSourceKind = null
        lastReportedFormat = null

        resolver.execute {
            if (released) return@execute
            val resolved = try {
                // GlobalPreferences backs the auth token store, the locale and
                // the player-JS cache. Every MediaServiceCore entry point
                // reaches for it, so it has to exist before the first call —
                // and it touches disk, which is why this is not on the main
                // thread.
                GlobalPreferences.instance(context)
                val service = YouTubeServiceManager.instance()
                service.mediaItemService.getFormatInfo(videoId)
            } catch (e: Throwable) {
                main.post {
                    if (generation == openGeneration && !released) {
                        fail(
                            videoId, onError, "resolve_failed",
                            "${e.javaClass.simpleName}: ${e.message}",
                        )
                    }
                }
                return@execute
            }

            main.post {
                if (generation != openGeneration || released) return@post
                openResolved(videoId, resolved, onError)
            }
        }
    }

    private fun openResolved(
        videoId: String,
        formatInfo: MediaItemFormatInfo?,
        onError: (code: String, message: String) -> Unit,
    ) {
        if (formatInfo == null) {
            fail(videoId, onError, "resolve_failed", "No format info for this video")
            return
        }
        if (formatInfo.isUnplayable) {
            fail(
                videoId, onError, "unplayable",
                formatInfo.playabilityReason ?: "Video is unplayable",
            )
            return
        }

        val exo = ensurePlayer()
        val factory = sourceFactory ?: return
        val built = try {
            factory.fromFormatInfo(formatInfo, /* preferHighBitrate= */ false)
        } catch (e: Throwable) {
            fail(videoId, onError, "source_failed", e.message ?: e.javaClass.simpleName)
            return
        }
        if (built == null) {
            // Reached for a scheduled premiere or a stream that has not begun:
            // YouTube answers with metadata but no playable rendition at all.
            fail(
                videoId, onError, "no_streams",
                // Which gate rejected it matters: a live stream with no
                // start time is refused the sideloaded manifests on
                // purpose, and then has nothing left to fall back to.
                "No playable rendition (live=${formatInfo.isLive} " +
                    "startMs=${formatInfo.startTimeMs} " +
                    "dash=${formatInfo.containsDashFormats()} " +
                    "sabr=${formatInfo.containsSabrFormats()} " +
                    "dashUrl=${formatInfo.containsDashUrl()} " +
                    "hlsUrl=${formatInfo.containsHlsUrl()} " +
                    "url=${formatInfo.containsUrlFormats()})",
            )
            return
        }

        currentSourceKind = built.kind.wireName
        // The single most useful line in a playback bug report: which rung
        // of the format ladder this video actually landed on.
        Log.i(
            TAG,
            "open $videoId: source=${built.kind.wireName} " +
                "live=${formatInfo.isLive} heightCap=$preferredHeight",
        )
        applyHeightLimit(preferredHeight)
        exo.prepare(built.mediaSource)
        exo.playWhenReady = true
    }

    /// Reports a refusal to Dart and to logcat at once: an error that only
    /// reaches the UI is invisible in a bug report.
    private fun fail(
        videoId: String,
        onError: (code: String, message: String) -> Unit,
        code: String,
        message: String,
    ) {
        Log.w(TAG, "open $videoId failed: $code: $message")
        onError(code, message)
    }

    fun play() {
        player?.playWhenReady = true
    }

    fun pause() {
        player?.playWhenReady = false
    }

    fun seek(positionMs: Long) {
        player?.seekTo(positionMs)
    }

    fun setSpeed(speed: Float) {
        player?.playbackParameters = PlaybackParameters(speed)
    }

    fun setVolume(volume: Float) {
        player?.volume = volume.coerceIn(0f, 1f)
    }

    /**
     * Caps video selection at [height], or restores adaptive selection when it
     * is null. With DASH every rendition is already described by the open
     * manifest, so this takes effect on the next segment rather than needing a
     * re-resolve — which is the whole reason for playing through a manifest.
     */
    fun selectVideoTrack(height: Int?, codec: String?) {
        preferredHeight = height
        Log.i(TAG, "selectVideoTrack: height=${height ?: "auto"} codec=${codec ?: "any"}")
        applyHeightLimit(height, codec)
    }

    private fun applyHeightLimit(height: Int?, codec: String? = null) {
        val selector = trackSelector ?: return
        val rendererIndex = rendererIndexFor(C.TRACK_TYPE_VIDEO)
        val builder = selector.buildUponParameters()

        // A height cap is expressed as a constraint rather than an override so
        // ExoPlayer keeps adapting underneath it — dropping to a lower
        // rendition on a slow network instead of stalling at the ceiling.
        if (height == null) {
            builder.clearVideoSizeConstraints()
        } else {
            // Width is left unconstrained: YouTube renditions are named by
            // height, and a fixed width would exclude anything not 16:9.
            builder.setMaxVideoSize(Int.MAX_VALUE, height)
        }

        // Codec is a different matter. ExoPlayer 2.10 has no preferred-codec
        // parameter (that arrived in 2.13), so the only way to insist on one is
        // to pin the renderer to the group that carries it. Adaptation survives
        // *within* the group, which is where the renditions of one codec live.
        if (rendererIndex != null) {
            val groups = mappedTrackInfo()?.getTrackGroups(rendererIndex)
            val groupIndex = if (codec == null || groups == null) {
                null
            } else {
                findCodecGroup(groups, codec, height)
            }
            if (groups != null && groupIndex != null) {
                val group = groups.get(groupIndex)
                val tracks = (0 until group.length)
                    .filter { height == null || group.getFormat(it).height <= height }
                    .toIntArray()
                if (tracks.isNotEmpty()) {
                    builder.setSelectionOverride(
                        rendererIndex,
                        groups,
                        DefaultTrackSelector.SelectionOverride(groupIndex, *tracks),
                    )
                } else {
                    builder.clearSelectionOverrides(rendererIndex)
                }
            } else {
                // Either no codec was asked for, or the video has no rendition
                // in it at this height. Plain adaptive selection plays
                // something, which beats pinning the renderer to nothing.
                builder.clearSelectionOverrides(rendererIndex)
            }
        }

        selector.setParameters(builder)
    }

    /** First group whose tracks are [codec] and fit under [height], if any. */
    private fun findCodecGroup(groups: TrackGroupArray, codec: String, height: Int?): Int? {
        val wanted = codec.lowercase()
        for (groupIndex in 0 until groups.length) {
            val group = groups.get(groupIndex)
            if (group.length == 0) continue
            if (shortCodec(group.getFormat(0)) != wanted) continue
            val fits = (0 until group.length).any {
                height == null || group.getFormat(it).height <= height
            }
            if (fits) return groupIndex
        }
        return null
    }

    fun selectAudioTrack(id: String) {
        overrideByGroupId(C.TRACK_TYPE_AUDIO, id)
    }

    fun selectSubtitle(code: String?) {
        val selector = trackSelector ?: return
        val rendererIndex = rendererIndexFor(C.TRACK_TYPE_TEXT) ?: return
        val builder = selector.buildUponParameters()
        if (code == null) {
            builder.setRendererDisabled(rendererIndex, true)
            selector.setParameters(builder)
            return
        }
        builder.setRendererDisabled(rendererIndex, false)
        selector.setParameters(builder)
        overrideByGroupId(C.TRACK_TYPE_TEXT, code)
    }

    /**
     * Dropping the video track keeps audio (and therefore the clock, and the
     * position) running while nothing is on screen. Decoding frames nobody can
     * see is pure battery cost.
     */
    fun setVideoEnabled(enabled: Boolean) {
        val selector = trackSelector ?: return
        val rendererIndex = rendererIndexFor(C.TRACK_TYPE_VIDEO) ?: return
        selector.setParameters(
            selector.buildUponParameters().setRendererDisabled(rendererIndex, !enabled),
        )
    }

    fun release() {
        released = true
        resolver.shutdownNow()
        player?.let {
            it.removeListener(playerListener)
            it.removeVideoListener(videoListener)
            it.release()
        }
        player = null
        trackSelector = null
        sourceFactory = null
        surface = null
    }

    // ------------------------------------------------------ track plumbing

    private fun mappedTrackInfo(): MappingTrackSelector.MappedTrackInfo? =
        trackSelector?.currentMappedTrackInfo

    private fun rendererIndexFor(trackType: Int): Int? {
        val info = mappedTrackInfo() ?: return null
        for (i in 0 until info.rendererCount) {
            if (info.getRendererType(i) == trackType &&
                info.getTrackGroups(i).length > 0
            ) {
                return i
            }
        }
        return null
    }

    /**
     * Pins a renderer to the group whose identity matches [id] — the language
     * for audio and subtitles. Groups are how YouTube separates dubbed audio
     * tracks, so this is a group override rather than a track override.
     */
    private fun overrideByGroupId(trackType: Int, id: String) {
        val selector = trackSelector ?: return
        val info = mappedTrackInfo() ?: return
        val rendererIndex = rendererIndexFor(trackType) ?: return
        val groups = info.getTrackGroups(rendererIndex)
        for (groupIndex in 0 until groups.length) {
            val group = groups.get(groupIndex)
            if (group.length == 0) continue
            if (trackIdentity(group.getFormat(0), groupIndex) != id) continue
            selector.setParameters(
                selector.buildUponParameters().setSelectionOverride(
                    rendererIndex,
                    groups,
                    DefaultTrackSelector.SelectionOverride(groupIndex, 0),
                ),
            )
            return
        }
    }

    /**
     * A stable id for an audio or subtitle group. The language is what the user
     * is really choosing, and it survives a re-open; the group index does not,
     * so it is only the fallback for a stream that reports no language.
     */
    private fun trackIdentity(format: Format, groupIndex: Int): String =
        format.language ?: format.id ?: "group-$groupIndex"

    private fun emitTracks() {
        val info = mappedTrackInfo() ?: return

        val video = mutableListOf<Map<String, Any?>>()
        val audio = mutableListOf<Map<String, Any?>>()
        val subtitle = mutableListOf<Map<String, Any?>>()

        for (rendererIndex in 0 until info.rendererCount) {
            val groups: TrackGroupArray = info.getTrackGroups(rendererIndex)
            for (groupIndex in 0 until groups.length) {
                val group = groups.get(groupIndex)
                for (trackIndex in 0 until group.length) {
                    val format = group.getFormat(trackIndex)
                    when (info.getRendererType(rendererIndex)) {
                        C.TRACK_TYPE_VIDEO -> video += videoTrackMap(format)
                        C.TRACK_TYPE_AUDIO ->
                            if (trackIndex == 0) audio += audioTrackMap(format, groupIndex)
                        C.TRACK_TYPE_TEXT ->
                            if (trackIndex == 0) subtitle += subtitleTrackMap(format, groupIndex)
                    }
                }
            }
        }

        // Heights repeat across codecs; the picker wants one row per rendition.
        val dedupedVideo = video
            .distinctBy { "${it["height"]}-${it["codec"]}-${it["fps"]}" }
            .sortedByDescending { it["height"] as? Int ?: 0 }

        events(
            mapOf(
                "event" to "tracks",
                "video" to dedupedVideo,
                "audio" to audio,
                "subtitle" to subtitle,
            ),
        )
    }

    private fun videoTrackMap(format: Format): Map<String, Any?> = mapOf(
        "height" to format.height.takeIf { it != Format.NO_VALUE },
        "codec" to shortCodec(format),
        "fps" to format.frameRate.takeIf { it != Format.NO_VALUE.toFloat() }?.toInt(),
        "bitrate" to format.bitrate.takeIf { it != Format.NO_VALUE },
        "hdr" to isHdr(format),
        "label" to buildString {
            append(format.height.takeIf { it != Format.NO_VALUE }?.let { "${it}p" } ?: "?")
            val fps = format.frameRate.takeIf { it != Format.NO_VALUE.toFloat() }?.toInt()
            if (fps != null && fps > 30) append(fps)
        },
    )

    private fun audioTrackMap(format: Format, groupIndex: Int): Map<String, Any?> = mapOf(
        "id" to trackIdentity(format, groupIndex),
        "label" to (format.language ?: "Original"),
        "bitrate" to format.bitrate.takeIf { it != Format.NO_VALUE },
        "codec" to shortCodec(format),
    )

    private fun subtitleTrackMap(format: Format, groupIndex: Int): Map<String, Any?> = mapOf(
        "code" to trackIdentity(format, groupIndex),
        "label" to (format.language ?: "Unknown"),
    )

    private fun shortCodec(format: Format): String {
        val codecs = format.codecs
        val mime = format.sampleMimeType
        return when {
            codecs?.startsWith("avc") == true -> "avc"
            codecs?.startsWith("vp9") == true || codecs?.startsWith("vp09") == true -> "vp9"
            codecs?.startsWith("av01") == true -> "av1"
            codecs?.startsWith("hev") == true || codecs?.startsWith("hvc") == true -> "hevc"
            codecs?.startsWith("mp4a") == true -> "mp4a"
            codecs?.startsWith("opus") == true -> "opus"
            mime != null -> mime.substringAfter('/')
            else -> "unknown"
        }
    }

    private fun isHdr(format: Format): Boolean {
        val colorInfo = format.colorInfo ?: return false
        return colorInfo.colorTransfer == C.COLOR_TRANSFER_ST2084 ||
            colorInfo.colorTransfer == C.COLOR_TRANSFER_HLG
    }

    private fun emitFormatIfChanged() {
        val exo = player ?: return
        val format = exo.videoFormat ?: return
        if (format == lastReportedFormat) return
        lastReportedFormat = format
        Log.i(
            TAG,
            "format now: ${format.height}p ${shortCodec(format)} " +
                "${format.bitrate}bps source=$currentSourceKind",
        )
        events(
            mapOf(
                "event" to "format",
                "label" to (videoTrackMap(format)["label"] as? String ?: ""),
                "codec" to shortCodec(format),
                "fps" to (format.frameRate.takeIf { it != Format.NO_VALUE.toFloat() }?.toInt() ?: 0),
                "bitrate" to (format.bitrate.takeIf { it != Format.NO_VALUE } ?: 0),
                "width" to (format.width.takeIf { it != Format.NO_VALUE } ?: 0),
                "height" to (format.height.takeIf { it != Format.NO_VALUE } ?: 0),
                "hdr" to isHdr(format),
                "source" to currentSourceKind,
            ),
        )
    }

    // -------------------------------------------------------------- events

    fun emitState(completed: Boolean = false) {
        val exo = player ?: return
        val duration = exo.duration
        events(
            mapOf(
                "event" to "state",
                "playing" to (exo.playWhenReady && exo.playbackState == Player.STATE_READY),
                "buffering" to (exo.playbackState == Player.STATE_BUFFERING),
                "completed" to completed,
                "positionMs" to exo.currentPosition.coerceAtLeast(0),
                // C.TIME_UNSET until the manifest is parsed, and permanently
                // for a live stream. Zero reads as "unknown" on the Dart side.
                "durationMs" to if (duration == C.TIME_UNSET) 0L else duration,
                "bufferedMs" to exo.bufferedPosition.coerceAtLeast(0),
            ),
        )
    }

    private val playerListener = object : Player.EventListener {
        override fun onPlayerStateChanged(playWhenReady: Boolean, playbackState: Int) {
            emitState(completed = playbackState == Player.STATE_ENDED)
            if (playbackState == Player.STATE_READY) {
                emitTracks()
                emitFormatIfChanged()
            }
        }

        override fun onTracksChanged(
            trackGroups: TrackGroupArray,
            trackSelections: TrackSelectionArray,
        ) {
            emitTracks()
            emitFormatIfChanged()
        }

        override fun onPlayerError(error: ExoPlaybackException) {
            val code = when (error.type) {
                ExoPlaybackException.TYPE_SOURCE -> "source_error"
                ExoPlaybackException.TYPE_RENDERER -> "renderer_error"
                else -> "player_error"
            }
            events(
                mapOf(
                    "event" to "error",
                    "code" to code,
                    "message" to (error.cause?.message ?: error.message ?: code),
                ),
            )
        }

        override fun onSeekProcessed() {
            emitState()
        }
    }

    private val videoListener = object : VideoListener {
        override fun onVideoSizeChanged(
            width: Int,
            height: Int,
            unappliedRotationDegrees: Int,
            pixelWidthHeightRatio: Float,
        ) {
            onVideoSize(width, height)
            emitFormatIfChanged()
        }

        override fun onRenderedFirstFrame() {
            emitState()
            emitFormatIfChanged()
        }
    }

    /** Set by the plugin so the SurfaceTexture can be resized to match. */
    var onVideoSize: (width: Int, height: Int) -> Unit = { _, _ -> }
}
