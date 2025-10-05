// import java.io.FileInputStream
// import java.util.Properties
// import java.io.File


// pluginManagement {
//     val flutterSdkPath by settings.extra {
//         val properties = java.util.Properties()
//         val localPropertiesFile = File(rootDir, "local.properties")
//         if (localPropertiesFile.exists()) {
//            localPropertiesFile.inputStream().use { localProperties.load(it) }
//         }
//         val path = properties.getProperty("flutter.sdk")
//         require(path != null) { "flutter.sdk not set in local.properties" }
//         path
//     }

//     includeBuild(flutterSdkPath as String + "/packages/flutter_tools/gradle")

//     repositories {
//         google()
//         mavenCentral()
//         gradlePluginPortal()
//     }
// }

// plugins {
//     id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    
//     // Gunakan versi AGP 7.3.0 yang lebih toleran dan stabil
//     id("com.android.application") version "8.6.0" apply false
    
//     // Gunakan versi Kotlin 1.8.22 yang kompatibel
//     id("org.jetbrains.kotlin.android") version "1.8.22" apply false
    
//     // Versi Google Services yang stabil
//     id("com.google.gms.google-services") version "4.4.1" apply false
// }

// include(":app")

@file:Suppress("UnstableApiUsage")

import java.io.File
import org.gradle.api.GradleException

pluginManagement {
    // Langsung pakai nama lengkap java.util.Properties
    val localProperties = java.util.Properties()
    val localPropertiesFile = File(rootDir, "local.properties")

    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { localProperties.load(it) }
    }

    val flutterSdkPath = localProperties.getProperty("flutter.sdk")
        ?: throw GradleException("flutter.sdk not set in local.properties")

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.6.0" apply false
    id("com.android.library") version "8.6.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.0" apply false
    id("com.google.gms.google-services") version "4.4.1" apply false
}

include(":app")
