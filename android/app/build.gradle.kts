// ===============================================
// Emie • Android App Gradle
// Pfad: android/app/build.gradle.kts
// ===============================================

import java.util.Properties
import java.util.Base64
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") apply false
}

// Explicit local mode is carried by the same define used by Dart.
val localDefines = providers.gradleProperty("dart-defines").orNull
    ?.split(",")?.map { String(Base64.getDecoder().decode(it)) } ?: emptyList()
val localDebug = localDefines.contains("EMIE_LOCAL=true")
val localBackendPort = if (localDebug) {
    val value = localDefines.firstOrNull { it.startsWith("EMIE_LOCAL_PORT=") }
        ?.substringAfter("=") ?: "8000"
    check(value.toIntOrNull() in listOf(8000) + (8010..8019)) { "Unsupported local backend port" }
    value
} else "8000"
val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true) || it.contains("profile", ignoreCase = true)
}
check(!(localDebug && releaseRequested)) { "EMIE_LOCAL is only supported for debug builds." }
if (!localDebug) apply(plugin = "com.google.gms.google-services")

// ===============================================
// Release Key laden
// ===============================================

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (releaseRequested) {
    check(keystorePropertiesFile.exists()) { "Release requires real key.properties signing configuration." }
    keystoreProperties.load(
        FileInputStream(keystorePropertiesFile)
    )
}

android {
    namespace = "ai.emie.app"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        manifestPlaceholders["localBackendPort"] = localBackendPort
        applicationId = "ai.emie.app"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ===========================================
    // Release Signing
    // ===========================================

    signingConfigs {
        create("release") {
            if (releaseRequested) {
                for (key in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
                    check(!keystoreProperties.getProperty(key).isNullOrBlank()) { "Missing release signing field: $key" }
                }
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.getByName("release")
        }
    }
}

dependencies {

    implementation(
        platform("com.google.firebase:firebase-bom:34.6.0")
    )

    implementation(
        "com.google.android.gms:play-services-auth:20.7.0"
    )
}

flutter {
    source = "../../"
}
