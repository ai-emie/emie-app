// ===============================================
// Emie • Android Top-Level Gradle
// Pfad: android/build.gradle.kts
// ===============================================

plugins {
    // Google Services Gradle Plugin
    id("com.google.gms.google-services") version "4.4.1" apply false
}

// --------------------------------------------------
// Repositories (global verfügbar)
// --------------------------------------------------
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// --------------------------------------------------
// OFFIZIELLER Flutter Build-Ordner Fix
// --------------------------------------------------
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
    project.evaluationDependsOn(":app")
}

// --------------------------------------------------
// Clean Task
// --------------------------------------------------
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
