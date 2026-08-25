package com.smarttube.smarttube_poc.player.exo;

// A trimmed port of SmartTube's ExoMediaSourceFactory
// (com.liskovsoft.smartyoutubetv2.common.exoplayer). The manifest parsing it
// relies on — DashManifestParser2 and SabrManifestParser — lives inside the
// forked ExoPlayer itself, so this class is only the wiring around it.
//
// What was dropped relative to the original: the OkHttp and Cronet data
// source variants. Those exist in SmartTube because it must reach TV devices
// whose platform HTTP stack is ancient or broken; this app targets phones on
// API 24+, where the default stack is fine, and each of those alternatives
// would drag another ExoPlayer extension plus Cronet's native blob into the
// APK. The selection prefs that chose between them went with them.
//
// SmartTube's TrackErrorFixer is also not wired in yet: it repairs a track
// selection after a mid-stream load error, which needs the TrackSelectorManager
// this module does not port. The load-error policies below already blacklist a
// failing track, which is the part that keeps playback alive.

import android.content.Context;
import android.net.Uri;
import android.text.TextUtils;

import androidx.annotation.NonNull;

import com.google.android.exoplayer2.C;
import com.google.android.exoplayer2.extractor.DefaultExtractorsFactory;
import com.google.android.exoplayer2.source.ExtractorMediaSource;
import com.google.android.exoplayer2.source.MediaSource;
import com.google.android.exoplayer2.source.MergingMediaSource;
import com.google.android.exoplayer2.source.dash.DashChunkSource;
import com.google.android.exoplayer2.source.dash.DashMediaSource;
import com.google.android.exoplayer2.source.dash.DefaultDashChunkSource;
import com.google.android.exoplayer2.source.dash.manifest.DashManifest;
import com.google.android.exoplayer2.source.dash.manifest.DashManifestParser2;
import com.google.android.exoplayer2.source.hls.HlsMediaSource;
import com.google.android.exoplayer2.source.sabr.DefaultSabrChunkSource;
import com.google.android.exoplayer2.source.sabr.SabrChunkSource;
import com.google.android.exoplayer2.source.sabr.SabrMediaSource;
import com.google.android.exoplayer2.source.sabr.manifest.SabrManifest;
import com.google.android.exoplayer2.source.sabr.manifest.SabrManifestParser;
import com.google.android.exoplayer2.source.smoothstreaming.DefaultSsChunkSource;
import com.google.android.exoplayer2.source.smoothstreaming.SsMediaSource;
import com.google.android.exoplayer2.upstream.DataSource;
import com.google.android.exoplayer2.upstream.DefaultDataSourceFactory;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSourceFactory;
import com.google.android.exoplayer2.upstream.HttpDataSource;
import com.google.android.exoplayer2.util.Util;
import com.liskovsoft.googlecommon.common.helpers.DefaultHeaders;
import com.liskovsoft.mediaserviceinterfaces.data.MediaItemFormatInfo;

import java.util.List;

public class SmartTubeMediaSourceFactory {
    /**
     * The rendition family a {@link MediaItemFormatInfo} was actually opened
     * with. Reported up to Flutter so the quality readout can say whether it
     * is on the fast path (DASH/SABR) or the degraded one (progressive).
     */
    public enum SourceKind {
        DASH("dash"),
        DASH_HLS("dash+hls"),
        SABR("sabr"),
        DASH_URL("dash-url"),
        HLS("hls"),
        PROGRESSIVE("progressive");

        public final String wireName;

        SourceKind(String wireName) {
            this.wireName = wireName;
        }
    }

    /** A built source together with which branch of the ladder produced it. */
    public static class Result {
        public final MediaSource mediaSource;
        public final SourceKind kind;

        Result(MediaSource mediaSource, SourceKind kind) {
            this.mediaSource = mediaSource;
            this.kind = kind;
        }
    }

    private static final String USER_AGENT = DefaultHeaders.APP_USER_AGENT;
    private static final String DASH_MANIFEST_EXTENSION = "mpd";
    private static final String HLS_PLAYLIST_EXTENSION = "m3u8";

    // SmartTube's value. One segment per load keeps the reaction to a quality
    // switch immediate: the next segment already uses the new representation
    // instead of finishing a multi-segment batch at the old one.
    private static final int MAX_SEGMENTS_PER_LOAD = 1;

    private static final int CONNECT_TIMEOUT_MS = 20_000;
    private static final int READ_TIMEOUT_MS = 20_000;

    private final Context context;
    private DataSource.Factory mediaDataSourceFactory;

    public SmartTubeMediaSourceFactory(Context context) {
        this.context = context.getApplicationContext();
    }

    /**
     * Chooses a rendition family for [formatInfo] and builds the matching
     * source. This is the ladder from SmartTube's
     * VideoLoaderController.processFormatInfo, minus the branches that only
     * exist to honour TV-side preferences (forced HLS, forced legacy codecs,
     * forced DASH-url), which this app does not expose.
     *
     * @param preferHighBitrate merge the DASH manifest with YouTube's extended
     *                          HLS playlist when the video offers one. That is
     *                          how the higher-bitrate renditions become
     *                          reachable; it costs a second manifest fetch.
     */
    public Result fromFormatInfo(@NonNull MediaItemFormatInfo formatInfo, boolean preferHighBitrate) {
        if (formatInfo.containsDashFormats() && acceptAdaptiveFormats(formatInfo)) {
            if (preferHighBitrate && formatInfo.hasExtendedHlsFormats()) {
                MediaSource merged = new MergingMediaSource(
                        buildDashMediaSource(formatInfo),
                        fromHlsPlaylist(formatInfo.getHlsManifestUrl()));
                return new Result(merged, SourceKind.DASH_HLS);
            }
            return new Result(buildDashMediaSource(formatInfo), SourceKind.DASH);
        }

        if (formatInfo.containsSabrFormats() && acceptAdaptiveFormats(formatInfo)) {
            return new Result(buildSabrMediaSource(formatInfo), SourceKind.SABR);
        }

        if (formatInfo.isLive() && formatInfo.containsDashUrl()) {
            return new Result(
                    fromDashManifestUrl(formatInfo.getDashManifestUrl()), SourceKind.DASH_URL);
        }

        if (formatInfo.isLive() && formatInfo.containsHlsUrl()) {
            return new Result(fromHlsPlaylist(formatInfo.getHlsManifestUrl()), SourceKind.HLS);
        }

        if (formatInfo.containsUrlFormats()) {
            // Always low quality: one muxed progressive rendition, no adaptation.
            return new Result(fromUrlList(formatInfo.createUrlList()), SourceKind.PROGRESSIVE);
        }

        return null;
    }

    /**
     * Whether the sideloaded (locally built) manifests can be trusted for this
     * video. SmartTube's gate, reduced to the one condition that is not a user
     * preference: a live stream whose start time YouTube did not report cannot
     * be turned into a correct manifest, so it has to fall through to the
     * URL-based live branches.
     */
    private boolean acceptAdaptiveFormats(@NonNull MediaItemFormatInfo formatInfo) {
        return !formatInfo.isLive() || formatInfo.getStartTimeMs() != 0;
    }

    private MediaSource buildDashMediaSource(MediaItemFormatInfo formatInfo) {
        DashManifest manifest = new DashManifestParser2().parse(formatInfo);
        return new DashMediaSource.Factory(getDashChunkSourceFactory(), null)
                .setLoadErrorHandlingPolicy(new DashDefaultLoadErrorHandlingPolicy())
                .createMediaSource(manifest);
    }

    private MediaSource buildSabrMediaSource(MediaItemFormatInfo formatInfo) {
        SabrManifest manifest = new SabrManifestParser().parse(formatInfo);
        // SabrMediaSource.createMediaSource(Uri) returns null by design — SABR
        // has no manifest to fetch, the parsed object is the whole thing.
        return new SabrMediaSource.Factory(getSabrChunkSourceFactory(), null)
                .setLoadErrorHandlingPolicy(new SabrDefaultLoadErrorHandlingPolicy())
                .createMediaSource(manifest);
    }

    public MediaSource fromDashManifestUrl(String dashManifestUrl) {
        return buildMediaSource(Uri.parse(dashManifestUrl), DASH_MANIFEST_EXTENSION);
    }

    public MediaSource fromHlsPlaylist(String hlsPlaylistUrl) {
        return buildMediaSource(Uri.parse(hlsPlaylistUrl), HLS_PLAYLIST_EXTENSION);
    }

    public MediaSource fromUrlList(List<String> urlList) {
        // The list is ordered best first, and these renditions are muxed, so
        // there is nothing to adapt between: take the top one.
        return buildMediaSource(Uri.parse(urlList.get(0)), null);
    }

    @SuppressWarnings("deprecation")
    private MediaSource buildMediaSource(Uri uri, String overrideExtension) {
        int type = TextUtils.isEmpty(overrideExtension)
                ? Util.inferContentType(uri)
                : Util.inferContentType("." + overrideExtension);
        switch (type) {
            case C.TYPE_SS:
                return new SsMediaSource.Factory(
                        new DefaultSsChunkSource.Factory(getMediaDataSourceFactory()),
                        getMediaDataSourceFactory())
                        .createMediaSource(uri);
            case C.TYPE_DASH:
                return new DashMediaSource.Factory(
                        getDashChunkSourceFactory(), getMediaDataSourceFactory())
                        // Deliberately a fresh instance per source: the parser
                        // keeps live-edge state that must not leak between videos.
                        .setManifestParser(new LiveDashManifestParser())
                        .setLoadErrorHandlingPolicy(new DashDefaultLoadErrorHandlingPolicy())
                        .createMediaSource(uri);
            case C.TYPE_HLS:
                return new HlsMediaSource.Factory(getMediaDataSourceFactory())
                        .createMediaSource(uri);
            case C.TYPE_OTHER:
                return new ExtractorMediaSource.Factory(getMediaDataSourceFactory())
                        .setExtractorsFactory(new DefaultExtractorsFactory())
                        .createMediaSource(uri);
            default:
                throw new IllegalStateException("Unsupported media source type: " + type);
        }
    }

    @NonNull
    private SabrChunkSource.Factory getSabrChunkSourceFactory() {
        return new DefaultSabrChunkSource.Factory(getMediaDataSourceFactory(), MAX_SEGMENTS_PER_LOAD);
    }

    @NonNull
    private DashChunkSource.Factory getDashChunkSourceFactory() {
        return new DefaultDashChunkSource.Factory(getMediaDataSourceFactory(), MAX_SEGMENTS_PER_LOAD);
    }

    private DataSource.Factory getMediaDataSourceFactory() {
        if (mediaDataSourceFactory == null) {
            // No bandwidth meter, matching SmartTube: the adaptive track
            // selection is driven by the explicit quality choice here, and a
            // shared meter would let one stalled stream drag the other down.
            HttpDataSource.Factory http = new DefaultHttpDataSourceFactory(
                    USER_AGENT, null, CONNECT_TIMEOUT_MS, READ_TIMEOUT_MS,
                    /* allowCrossProtocolRedirects= */ true);
            mediaDataSourceFactory = new DefaultDataSourceFactory(context, null, http);
        }
        return mediaDataSourceFactory;
    }
}
