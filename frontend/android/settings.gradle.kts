pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Pinned below the AGP 9 / Kotlin 2.3 defaults this template picked up:
    // AGP 9's built-in-Kotlin support silently drops the Kotlin compilation
    // output of plugins (file_picker, share_plus) that still apply their own
    // 'org.jetbrains.kotlin.android' plugin, so :app's Java compile can't
    // find their generated classes. AGP 8.7.x was too old for transitive
    // androidx deps (browser 1.9.0 / core-ktx 1.17.0 need AGP >= 8.9.1), so
    // this is pinned to the last pre-9.x line instead: AGP 8.11.x + Kotlin 2.2.x.
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
