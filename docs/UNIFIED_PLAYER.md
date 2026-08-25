# Unified player: one playback engine for BoodTube and SmartTube

BoodTube used to decode video with `media_kit` (libmpv), resolving two separate
googlevideo URLs in Dart with a patched `youtube_explode_dart` and relaying both
through a loopback HTTP proxy. SmartTube decodes with a forked ExoPlayer 2.10.6
fed by MediaServiceCore. Two engines meant two sets of playback bugs, and only
one of them was the one people actually test.

On Android, BoodTube now plays through SmartTube's engine. mpv stays for iOS,
and as the Android fallback.

## Why this is more than swapping a decoder

The Dart path resolved a video into *a video URL and an audio URL*. The native
path resolves it into a **manifest**. That difference is most of the benefit:

| | Dart + mpv | Native + ExoPlayer |
|---|---|---|
| Resolution | `youtube_explode_dart` (patched fork) | MediaServiceCore `getFormatInfo` |
| Signature / n-sig | Dart reimplementation | the bundled V8 SmartTube ships |
| PoToken | none | `PoTokenGate` (WebView) |
| Transport | two URLs through a loopback proxy | DASH / SABR / HLS, direct |
| Quality switch | re-resolve, re-open, lose the buffer | a track selection in the open stream |
| Throttling / 403 ladder | per-URL probing and step-down | handled inside the format ladder |

The loopback proxy exists because mpv's bundled TLS cannot reach googlevideo
reliably. ExoPlayer uses the platform HTTP stack, so on the native engine there
is no proxy and no probing at all.

## What is wired in

`android/smarttube-modules.gradle` imports the playback core from the parent
SmartTube checkout as ordinary Gradle subprojects:

```
:sharedutils  :commons-io-2.8.0  :j2v8          (SharedModules)
:mediaserviceinterfaces  :youtubeapi           (MediaServiceCore)
:exoplayer-library-{core,dash,hls,smoothstreaming,sabr}
```

`:common` is deliberately **not** imported. It has no Leanback dependency — that
was the expected blocker and it is not real — but it does pull `:fragment-1.1.0`,
`:filepicker-lib`, `:leanbackassistant`, `:slidableactivity`, `:appupdatechecker2`,
Glide, WorkManager and Guava for the sake of a handful of playback classes. The
three that are genuinely reusable were ported instead (see below).

### The AGP 7 → 8 shims

The imported modules were written for AGP 7.4.2 / Gradle 7.5 / Kotlin 1.8.10.
This build is AGP 8.11.1 / Gradle 8.14 / Kotlin 2.2.20. Everything needed to
bridge that gap lives in `android/smarttube-modules.gradle`, applied from
`settings.gradle.kts`, so **nothing in the parent repo or its two git submodules
was modified**:

1. **`namespace` is mandatory in AGP 8.** None of the modules declare one. It is
   injected from the `package` their manifest already carried, so generated `R`
   and `BuildConfig` classes keep their existing names.
2. **`package=` in a source manifest is rejected in AGP 8.** A stripped copy is
   generated into `android/build/smarttube-manifests/` and the module's `main`
   source set is pointed at it.
3. **Version constants.** The modules read `minSdkVersion`, `compileSdkVersion`
   and the androidx pins from `SharedModules/constants.gradle`, which the
   SmartTube root build applies for them. This build has its own root, so the
   same file is applied per imported project.
4. **Java/Kotlin target mismatch.** The modules declare Java 8 and say nothing
   about Kotlin; Kotlin 2.x follows the JDK (17) and AGP refuses the mismatch.
   Java is raised to 17 in an `afterEvaluate` — registered before AGP's own, so
   it still wins, and applied after the module's script has set its 8.
5. **`BuildConfig`** generation is off by default in AGP 8; `sharedutils` reads
   `BuildConfig.DEBUG`, so it is turned back on.
6. **Dependency pins.** `sharedutils` calls `HttpUrl.parse`, which okhttp 4
   marks deprecated at ERROR level, so okhttp is pinned to SmartTube's 3.12.13
   for the imported projects. The Kotlin stdlib is deliberately *not* pinned —
   these sources are compiled by this build's Kotlin 2.x.
7. **`youtubeapi` requests a coroutines version that does not exist** (1.8.10 —
   it uses `kotlinVersion` where it meant `kotlinxVersion`). Forced inside the
   module, and rewritten in `:app` where the project dependency republishes it.
8. **Flavours.** `:youtubeapi`, `:exoplayer-library-dash` and
   `:exoplayer-library-sabr` are split into `stbeta` / `ststable` / `stfdroid`.
   `:app` has no flavours, so it declares `missingDimensionStrategy("default",
   "stbeta")`. This is not cosmetic: `stbeta` is what links the `:j2v8` module
   (and therefore the native V8 that runs the signature decipher) rather than
   the maven AAR.

### Ported from `common`

Three classes were copied into `com.smarttube.smarttube_poc.player.exo`, with
only the package line changed and a header saying where they came from:

- `LiveDashManifestParser` — YouTube-specific live DASH handling stock ExoPlayer
  2.10.6 does not have. Stateful; a fresh instance per live source.
- `DashDefaultLoadErrorHandlingPolicy` — blacklist a track on 404/410 instead of
  failing playback.
- `SabrDefaultLoadErrorHandlingPolicy` — adds SABR's "Wait 5 sec" retry.

`SmartTubeMediaSourceFactory` is a trimmed `ExoMediaSourceFactory`: same DASH /
SABR / HLS / progressive construction, minus the OkHttp and Cronet data sources
(SmartTube needs them for ancient TV HTTP stacks; this app is API 24+ on phones,
and each would add an ExoPlayer extension plus Cronet's native blob) and minus
the TV-only preference gates.

### The format ladder

`SmartTubeMediaSourceFactory.fromFormatInfo` reproduces
`VideoLoaderController.processFormatInfo`:

```
containsDashFormats()  -> DASH        (+ merged with extended HLS on request)
containsSabrFormats()  -> SABR
isLive() && containsDashUrl() -> live DASH by URL
isLive() && containsHlsUrl()  -> live HLS
containsUrlFormats()   -> progressive (always low quality)
```

guarded by the one gate that is not a user preference: a live stream whose start
time YouTube did not report cannot be turned into a correct sideloaded manifest,
so it falls through to the URL-based live branches.

## The bridge

`SmartTubePlayerPlugin` exposes `NativePlayerController` over:

- MethodChannel `app.smarttube/native_player` — `create`, `open`, `play`,
  `pause`, `seek`, `setSpeed`, `setVolume`, `selectVideoTrack`,
  `selectAudioTrack`, `selectSubtitle`, `setVideoEnabled`, `setBufferPreset`,
  `dispose`.
- EventChannel `app.smarttube/native_player/events` — `state`, `tracks`,
  `format`, `error`.

Frames reach Flutter through a `TextureRegistry` texture, **not** a PlatformView.
A texture composites inside the Flutter scene, so the app's existing overlay,
gesture and mini-player layers keep working untouched; a PlatformView would
punch a native hole through all of them.

Height is applied as a `DefaultTrackSelector` size *constraint* rather than an
override, so ExoPlayer keeps adapting underneath the ceiling. Codec preference
has to be an override — ExoPlayer 2.10 gained no preferred-codec parameter until
2.13 — pinned to the track group carrying that codec, which keeps adaptation
within the group.

### One thing that only shows up on a device

`sharedutils` compiles against okhttp 3.12.x, but `okhttp-brotli` pulls okhttp
**4.1.0** into the app's runtime graph. 4.1.0 will not initialise on a modern
Android — `AndroidPlatform` throws `Expected Android API level 21+ but was 34` —
and because every MediaServiceCore call goes through `RetrofitOkHttpHelper`,
*every* stream resolution failed with `ExceptionInInitializerError` while the
build itself was perfectly green.

SmartTube never hits this because its root build pins okhttp for all projects.
The pin therefore has to reach `:app` too, not only the imported modules; it is
in `android/app/build.gradle.kts`. No Flutter plugin in this app uses okhttp, so
one version across the build is safe.

The lesson worth keeping: a green Gradle build says nothing about whether these
modules work at runtime. Resolution was verified on the emulator against
`dQw4w9WgXcQ`, `jNQXAC9IVRw` and `9bZkp7q19f0` before any playback code was
trusted.

## What was verified on the emulator

API 34 x86_64 (`fitness` AVD), debug build. Screenshots were read back to
confirm frames, not just that the app had not crashed.

| | result |
|---|---|
| `dQw4w9WgXcQ` | plays, `source=dash`, 1080p AV1 |
| `LXb3EKWsInQ` (4K 60fps) | plays, `source=dash`, 720p→1080p H.264 |
| `9bZkp7q19f0` | plays, `source=dash`, 720p H.264 |
| Quality menu | full ladder from the platform `tracks` event: Auto/2160p/1440p/1080p/720p/480p/360p/240p/144p |
| Quality switch mid-play | `selectVideoTrack: height=1080` with **no second `open`** — an in-place track change; `format now: 720p avc` → `1080p avc` |
| Background → foreground | process survives, video track dropped and restored, picture comes back |
| Engine setting | flipping it to `mpv` stops the native engine being used at all; mpv plays the same videos |

The AV1 case is worth keeping: this emulator has only a *software* AV1
decoder, and ExoPlayer handled that correctly — it excluded 4K AV1
(`MediaCodecInfo: NoSupport [sizeAndRate.support, 3840x2160x25.0]
[c2.android.av1.decoder]`) and picked a rendition the device can actually
decode, rather than going black. That failure mode — a codec the hardware
cannot take, silently producing sound and no picture — is one of the
reasons for moving off `vo=mediacodec_embed`.

## Known gaps

- **Live streams do not play, on either engine.** On the native engine
  MediaServiceCore's `getFormatInfo` returns `null` for every live id
  tried (`jfKfPfyJRdk`, `21X5lGlDOfg`), so the format ladder is never
  reached: `open jfKfPfyJRdk failed: resolve_failed: No format info for
  this video`. On mpv the same ids reach the error screen too, so this is
  **not** a regression from the engine work — but it does mean the live
  path is unverified end to end. The next thing to look at is
  `YouTubeMediaItemService.getFormatInfo`, which returns null when
  `getVideoInfoService().getVideoInfo()` does; SmartTube itself may be
  passing the `clickTrackingParams` overload, or relying on
  initialisation this integration does not perform.
- **Subtitles are unverified on the native engine.** The caption list in
  the picker comes from the Dart metadata, while selection goes to
  ExoPlayer's text renderer as a group override. None of the videos used
  for verification carried captions, so the two halves have not been seen
  working together.
- **Picture-in-picture is unverified on the native engine.** It is
  untouched by this change and the surface is a Flutter texture either
  way, but it was not exercised.
- **The caption presets do not reach the native engine.** `SubtitleStyle`
  maps onto media_kit's `SubtitleViewConfiguration`; ExoPlayer draws its
  own captions on the platform side and ignores it.
- **The engine stats panel is mpv-only.** `playerEngineStatsProvider`
  reads mpv properties (`demuxer-cache-duration`, `hwdec-current`,
  `frame-drop-count`) straight off `mediaPlayerProvider`, so it reports
  nothing on the native engine. The EventChannel's `format` event already
  carries codec, bitrate, resolution and the ladder rung; wiring the panel
  to that is the fix.
- **Audio delay and pitch correction are mpv-only.** Both are mpv
  properties with no ExoPlayer 2.10 equivalent; `NativeEngine.applyTuning`
  forwards only the buffer preset and drops them.

- **`TrackErrorFixer` is not wired in.** It repairs a track selection after a
  mid-stream load error and needs `TrackSelectorManager`, which was not ported.
  The load-error policies already blacklist a failing track, which is the part
  that keeps playback alive.
- **Buffer preset changes take effect on the next video.** ExoPlayer's
  `LoadControl` is fixed at construction; rebuilding the player mid-video would
  cost the user their position for a setting that matters from the next one on.
- **`openMerged` (DASH + extended HLS)** is implemented but not exposed as a
  setting; `preferHighBitrate` is currently always false.
- **iOS is unchanged** and still uses mpv, along with the Dart resolver and the
  loopback proxy.
- **`SmartTubeAudioHandler` is still bound to the media_kit `Player`**
  (`lib/services/audio_player_handler.dart`, constructed in `main.dart`). On the
  native engine the lock-screen and notification controls therefore talk to a
  player that is not the one playing. Making the handler take a `PlayerEngine`
  instead of a `Player` is the fix; it was left out of this change to keep the
  diff to the engine seam.
- **okhttp-profiler logs whole HTTP bodies** at verbose level in debug builds,
  because `sharedutils` bundles `com.localebro:okhttpprofiler` and gates it on
  `BuildConfig.DEBUG`. Harmless in release, noisy in `adb logcat`.
