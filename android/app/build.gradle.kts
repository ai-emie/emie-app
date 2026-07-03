// ===============================================
// Emie • Android App Gradle
// Pfad: android/app/build.gradle.kts
// ===============================================

import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ===============================================
// Release Key laden
// ===============================================

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
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
            storeFile =
                file(keystoreProperties["storeFile"] as String)

            storePassword =
                keystoreProperties["storePassword"] as String

            keyAlias =
                keystoreProperties["keyAlias"] as String

            keyPassword =
                keystoreProperties["keyPassword"] as String
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