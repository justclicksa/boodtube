plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.smarttube.smarttube_poc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.smarttube.smarttube_poc"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // media_kit (libmpv) requires minSdk 24+ for arm64-v8a prebuilts.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Include x86 so the debug APK can run on the 32-bit API 25 emulator.
        ndk {
            abiFilters += listOf("x86", "x86_64", "arm64-v8a", "armeabi-v7a")
        }

        // Several imported SmartTube modules are split into the flavours the
        // TV app ships (stbeta / ststable / stfdroid). This app has no
        // flavours of its own, so it has to say which of theirs to link
        // against. "stbeta" is what SmartTube's own development builds use.
        missingDimensionStrategy("default", "stbeta")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// `youtubeapi` asks for kotlinx-coroutines at SmartTube's `kotlinVersion`
// instead of its `kotlinxVersion`, so it requests a coroutines 1.8.10 that
// has never existed. Inside that module the version is simply forced (see
// ../smarttube-modules.gradle), but a project dependency publishes what it
// declared, so the impossible coordinate resurfaces here and fails the whole
// resolution. Rewriting only that exact request leaves normal conflict
// resolution to pick the real version — currently 1.8.1, pulled in by
// androidx.core — instead of pinning the app to SmartTube's older one.
configurations.all {
    // SmartTube pins okhttp for every one of its projects, and the pin has to
    // reach the app too, not just the imported modules: `sharedutils` compiles
    // against 3.12.x, but `okhttp-brotli` drags okhttp 4.1.0 into the runtime
    // graph, and 4.1.0 refuses to initialise on a modern Android —
    // "Expected Android API level 21+ but was 34" out of AndroidPlatform,
    // which took down every MediaServiceCore call on API 34. No Flutter plugin
    // in this app uses okhttp, so one version for the whole build is safe.
    resolutionStrategy.force("com.squareup.okhttp3:okhttp:3.12.13")

    resolutionStrategy.eachDependency {
        if (requested.group == "org.jetbrains.kotlinx" &&
            requested.name == "kotlinx-coroutines-android" &&
            requested.version == "1.8.10"
        ) {
            useVersion("1.7.3")
            because("youtubeapi requests a kotlinx-coroutines version that does not exist")
        }
    }
}

dependencies {
    // The native playback engine, shared with the SmartTube TV app: the
    // forked ExoPlayer 2.10.6 (SABR module and DashManifestParser2 included)
    // fed by MediaServiceCore's stream resolution. Wired into this build by
    // ../smarttube-modules.gradle.
    //
    // `library-all` is deliberately not used — it drags in every extension
    // (cast, cronet, ffmpeg, IMA, leanback) for the sake of one artifact.
    implementation(project(":exoplayer-library-core"))
    implementation(project(":exoplayer-library-dash"))
    implementation(project(":exoplayer-library-hls"))
    implementation(project(":exoplayer-library-smoothstreaming"))
    implementation(project(":exoplayer-library-sabr"))

    // Stream resolution: video info, adaptive formats, DASH generation and
    // the signature / n-sig decipher (which runs in the V8 bundled in
    // SharedModules).
    implementation(project(":mediaserviceinterfaces"))
    implementation(project(":youtubeapi"))
    implementation(project(":sharedutils"))
}

flutter {
    source = "../.."
}
