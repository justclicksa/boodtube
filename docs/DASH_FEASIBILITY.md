# DASH on media_kit / libmpv — feasibility

**Verdict: DASH MPD demuxing is available on both Android and iOS** with the
libmpv that `media_kit` ships today. No extra plugin, no ExoPlayer bridge, no
custom libmpv build is needed to *play* a client-built manifest.

The caveat that shapes the design is not "can it parse an MPD" but "how much
of DASH does ffmpeg's demuxer implement" — see [What ffmpeg's DASH demuxer
does not do](#what-ffmpegs-dash-demuxer-does-not-do).

## Why it matters

The player currently opens a video-only URL and attaches the audio-only URL as
a separate mpv audio track, both relayed through `StreamProxy`. A manifest
replaces that pair with a single URL and lets ffmpeg own the muxing and the
a/v timeline — the same thing the native SmartTube app does with
`YouTubeMPDBuilder`.

## Evidence — Android

`media_kit_libs_android_video-1.3.8/android/build.gradle` downloads the
prebuilt libs from
`https://github.com/media-kit/libmpv-android-video-build/releases/download/v1.1.7/default-<abi>.jar`.
Those land in the APK as a single monolithic `lib/<abi>/libmpv.so` with ffmpeg
statically linked (there is no separate `libavformat.so`).

Extracted from `build/app/outputs/flutter-apk/app-debug.apk`,
`lib/arm64-v8a/libmpv.so` (12,369,680 bytes), the embedded
`FFMPEG_CONFIGURATION` string contains:

```
--target-os=android --enable-cross-compile ... --enable-small --enable-hwaccels
--enable-optimizations --enable-runtime-cpudetect --enable-mbedtls
--enable-libdav1d --enable-libxml2 --enable-avutil --enable-avcodec ...
--enable-demuxer=dash --enable-demuxer=webm_dash_manifest ...
--enable-protocol=http --enable-protocol=https --enable-protocol=tcp
--enable-protocol=tls --enable-network
```

Both halves of the requirement are there: `--enable-libxml2` (ffmpeg refuses to
build the `dash` demuxer without it) and `--enable-demuxer=dash`.

Corroborating strings in the same binary:

| String | Occurrences | Comes from |
| --- | --- | --- |
| `xmlReadMemory`, `xmlFirstElementChild`, ~1400 other `xml*` symbols | many | libxml2, statically linked |
| `dash:profile` | 5 | `dash_probe()` in `libavformat/dashdec.c` |
| `isoff-on-demand`, `isoff-live` | 1, 2 | `dash_probe()` |
| `<MPD` | 1 | `dash_probe()` |
| `DASH request for url `, `Unable to resolve template url ` | 1 each | `dashdec.c` log messages |
| `AdaptationSet`, `SegmentTemplate`, `SegmentList`, `BaseURL`, `mediaPresentationDuration`, `minimumUpdatePeriod`, `SegmentTimeline`, `presentationTimeOffset`, `startNumber`, `mediaRange`, `sourceURL` | 1+ each | `dashdec.c` MPD element/attribute names |

`Dynamic Adaptive Streaming over HTTP` is *absent*, which is consistent rather
than contradictory: the build uses `--enable-small`, and the demuxer's
`long_name` is wrapped in `NULL_IF_CONFIG_SMALL()`.

Reproduce:

```bash
unzip -o -q build/app/outputs/flutter-apk/app-debug.apk "lib/arm64-v8a/libmpv.so"
grep -aoE "[ -~]{100,9000}" lib/arm64-v8a/libmpv.so | grep -m1 -- "--enable-libxml2"
grep -aoF "dash:profile" lib/arm64-v8a/libmpv.so | wc -l
```

## Evidence — iOS

`media_kit_libs_ios_video-1.1.4/ios/Makefile` downloads
`libmpv-xcframeworks_v0.6.0_ios-universal-video-default.tar.gz` from
`media-kit/libmpv-darwin-build`. That archive ships **`Xml2.xcframework`**
alongside `Avformat.xcframework` — libxml2 is a first-class dependency of the
iOS build, not an accident.

The build recipe (`nix/packages/mk-pkg-ffmpeg/meson.build` in
`media-kit/libmpv-darwin-build`) says so explicitly:

```
'--enable-libxml2', # dash support
'--enable-demuxer=dash', # --enable-libxml2 required
```

Confirmed against the shipped binary — the configure string embedded in
`Avformat.xcframework/ios-arm64/Avformat.framework/Avformat` (v0.6.0) contains
`--enable-libxml2`, `--enable-demuxer=dash`, and
`--enable-protocol=http/https/tcp/tls`; and the same `dash_probe` /
`dashdec.c` strings appear (`dash:profile` ×5, `<MPD`, `AdaptationSet`,
`SegmentTemplate`, `SegmentList`, `mediaRange`, `DASH request for url `,
`xmlReadMemory`).

The repo also carries `patches/ffmpeg-fix-dash-base-url-escape.patch`, i.e.
upstream actively maintains the DASH path for these builds.

## What ffmpeg's DASH demuxer does *not* do

Read from `libavformat/dashdec.c`. This is the part that changes the design,
so it is worth being blunt about it.

1. **`<SegmentBase>` and `indexRange` are ignored.** `parse_manifest_representation()`
   looks for exactly three children of a `Representation`: `SegmentTemplate`,
   `BaseURL`, `SegmentList`. The strings `SegmentBase`, `indexRange` and
   `startWithSAP` do not appear anywhere in either shipped binary — confirming
   the source reading. ExoPlayer (what native SmartTube feeds) *does* honour
   them; ffmpeg does not.

2. **A `BaseURL`-only representation becomes one whole-file fragment.**

   ```c
   } else if (representation_baseurl_node && !representation_segmentlist_node) {
       seg = av_mallocz(sizeof(struct fragment));
       seg->url = get_content_url(baseurl_nodes, 4, ...);
       seg->size = -1;
   ```

   So a YouTube-shaped on-demand manifest still plays: ffmpeg opens the whole
   progressive file per representation and lets the nested `mov`/`matroska`
   demuxer read the `moov` and `sidx` itself.

3. **Seeking still works in that mode.** `dash_seek()` has a dedicated branch
   before the timeline logic:

   ```c
   // single fragment mode
   if (pls->n_fragments == 1) {
       pls->cur_timestamp = 0;
       pls->cur_seg_offset = 0;
       if (dry_run) return 0;
       ff_read_frame_flush(pls->ctx);
       return av_seek_frame(pls->ctx, -1, seek_pos_msec * 1000, flags);
   }
   ```

   The seek is delegated to the inner demuxer, which byte-seeks over HTTP.
   The `dash_seek missing timeline or fragment_duration` error only bites
   multi-fragment representations, which we do not emit.

4. **No ABR.** dashdec exposes every representation as its own AVStream and
   never switches between them on bandwidth. Listing all ~15 video renditions
   would cost one `avformat_open_input` + `find_stream_info` per rendition at
   header time and buy nothing, so the wiring emits only the selected
   video + audio pair. Quality selection stays where it already is
   (`StreamResolver` + the auto-quality ladder).

5. **Format detection is content-based, not extension- or MIME-based.**
   `ff_dash_demuxer` declares neither `.p.extensions` nor `.p.mime_type`;
   `dash_probe()` returns `AVPROBE_SCORE_MAX` only when the buffer contains
   `<MPD` **and** `dash:profile`. The generated manifest therefore must carry
   `profiles="urn:mpeg:dash:profile:isoff-on-demand:2011"` on the root element,
   where it lands inside the first few hundred bytes. A test asserts this.

6. **`allowed_extensions` is not a problem.** dashdec only applies that filter
   to the `file:` protocol; `http:` segment URLs skip it, so the extensionless
   loopback routes (`http://127.0.0.1:PORT/s0`) are accepted.

## mpv-side notes

`--demuxer-lavf-o`, `--demuxer-lavf-format`, `--stream-lavf-o`,
`--access-references` and `protocol_whitelist` all appear as strings in the
shipped `libmpv.so`, so the escape hatches exist if the default probe ever
picks the wrong demuxer (`--demuxer-lavf-format=dash` would force it).
`ytdl` is present as a string but the youtube-dl hook is irrelevant here — the
app resolves stream URLs itself through `youtube_explode_dart`.

## What was built

* `lib/data/youtube/mpd_builder.dart` — the Dart equivalent of
  `YouTubeMPDBuilder`: one `AdaptationSet` per mime type (per language for
  audio), video sets first, highest bandwidth first, `SegmentBase` +
  `Initialization` emitted when the format exposes `initRange`/`indexRange`,
  and every URL routed through a `String Function(Uri)` rewrite callback.
  `SegmentBase` is written even though ffmpeg ignores it: it costs nothing,
  it is what the manifest *means*, and it is what an ExoPlayer-backed player
  would need if one is added later.
* `StreamProxy.registerText()` — serves a generated manifest from the existing
  loopback server as `application/dash+xml`.
* `third_party/youtube_explode_dart` — `initRange`, `indexRange` and
  `audioSamplingRate` plumbed from InnerTube's `adaptiveFormats[]` through
  `StreamInfoProvider` to `VideoOnlyStreamInfo` / `AudioOnlyStreamInfo`
  (the upstream package dropped them).
* Setting `adaptiveStreaming` (default **off**), and `_openStreams()` opens
  the manifest through the proxy when it is on.

## Still unverified

The static evidence settles what the libraries *contain*. It does not prove
end-to-end playback on a device — that needs a run on real hardware
(the emulator was off-limits for this task). Worth watching for:

* whether mpv probes the loopback manifest as `dash` rather than falling
  through to another demuxer;
* whether ffmpeg's own HTTP client is content with the proxy's `200` (not
  `206`) response for the manifest, and with `Accept-Ranges: none`;
* start-up latency versus the progressive path — ffmpeg opens both
  representations before it reports a duration.

If any of those fail, the fallback ladder is: force the demuxer with
`--demuxer-lavf-format=dash`; then emit `SegmentList` with explicit
`mediaRange` segments (which needs a Dart `sidx` parser, since ffmpeg will not
read the index for us); and only then a native ExoPlayer-backed player plugin
for Android.
