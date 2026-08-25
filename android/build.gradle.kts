// Where the SmartTube modules imported in settings.gradle.kts live, so
// the Flutter-specific subproject wiring below can skip them.
val smartTubeRoot: java.io.File = rootDir.parentFile.parentFile

allprojects {
    repositories {
        google()
        mavenCentral()
        // MediaServiceCore and the SmartTube ExoPlayer fork resolve a few
        // dependencies from source-built GitHub artifacts.
        maven { url = uri("https://jitpack.io") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    // The Flutter template makes every subproject wait for :app, which is
    // what lets the Flutter Gradle plugin push its config into the plugin
    // modules. The imported SmartTube modules are not Flutter plugins and
    // :app compiles against them, so making them wait for :app is both
    // pointless and a configuration-order trap.
    if (project.path != ":app" && !project.projectDir.startsWith(smartTubeRoot)) {
        project.evaluationDependsOn(":app")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
