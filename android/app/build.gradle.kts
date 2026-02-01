// ===============================================
// Emie • Android App Gradle
// Pfad: android/app/build.gradle.kts
// ===============================================

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Plugin
    id("dev.flutter.flutter-gradle-plugin")
    // Google Services Plugin (für Google Login)
    id("com.google.gms.google-services")
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

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Firebase BOM – Versionen automatisch kompatibel halten
    implementation(platform("com.google.firebase:firebase-bom:34.6.0"))

    // Google Sign-In (Pflicht für Google Login)
    implementation("com.google.android.gms:play-services-auth:20.7.0")

    // (Optional) Firebase Analytics
    // implementation("com.google.firebase:firebase-analytics")
}

flutter {
    source = "../../"
}
