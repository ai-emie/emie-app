import java.util.Properties
import java.util.Base64
import java.net.URI
import java.security.KeyStore
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.transform.TransformerFactory
import javax.xml.transform.dom.DOMSource
import javax.xml.transform.stream.StreamResult
import com.android.build.api.artifact.SingleArtifact
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.provider.Property
import org.gradle.api.tasks.*

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") apply false
}

val defines = (providers.gradleProperty("dart-defines").orNull ?: "")
    .split(",").filter { it.isNotEmpty() }.map { String(Base64.getDecoder().decode(it)) }
    .map { it.substringBefore("=") to it.substringAfter("=", "") }
check(defines.map { it.first }.distinct().size == defines.size) { "Duplicate dart-defines are not supported" }
val defineMap = defines.toMap()
val localMode = defineMap["EMIE_LOCAL"] == "true"
check(defineMap["EMIE_LOCAL"] in listOf(null, "false", "true")) { "EMIE_LOCAL must be true or false" }
val localPort = defineMap["EMIE_LOCAL_PORT"] ?: "8010"
if (localMode) check(localPort.toIntOrNull() in 8010..8019) { "Local port must be 8010..8019" }
val recoveryOrigin = if (localMode) "" else defineMap["EMIE_RECOVERY_ORIGIN"] ?: ""
if (recoveryOrigin.isNotEmpty()) {
    val uri = URI(recoveryOrigin)
    check(uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.rawUserInfo == null &&
        uri.rawQuery == null && uri.rawFragment == null && uri.rawPath in listOf("", "/") &&
        (uri.port == -1 || uri.port in 1..65535) &&
        !uri.host.contains(":") && !uri.host.contains("*")) { "Recovery origin must be one exact HTTPS host and port" }
}
// Google Services stays mandatory outside explicitly local builds.
if (!localMode) apply(plugin = "com.google.gms.google-services")

val signingFile = rootProject.file("key.properties")
val signing = Properties()
if (!localMode && signingFile.isFile) signingFile.inputStream().use { signing.load(it) }
val signingFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val signingComplete = signingFields.all { !signing.getProperty(it).isNullOrBlank() }
val signingStore = if (signingComplete) file(signing.getProperty("storeFile")) else null

fun validateVariant(buildType: String) {
    check(!localMode || buildType == "debug") { "EMIE_LOCAL is only supported for the actual debug variant" }
    val missing = mutableListOf<String>()
    if (!localMode && !file("google-services.json").isFile) missing.add("android/app/google-services.json for ai.emie.app")
    if (buildType != "debug" && (!signingFile.isFile || !signingComplete || signingStore?.isFile != true)) {
        missing.add("complete real android/key.properties and its referenced keystore")
    }
    check(missing.isEmpty()) { "Missing build prerequisites: " + missing.joinToString("; ") }
    if (!localMode) {
        check(file("google-services.json").isFile) { "Non-local build requires android/app/google-services.json for ai.emie.app" }
        val google = groovy.json.JsonSlurper().parse(file("google-services.json")) as Map<*, *>
        val clients = google["client"] as? List<*> ?: emptyList<Any>()
        check(clients.any {
            val info = (it as? Map<*, *>)?.get("client_info") as? Map<*, *>
            val androidInfo = info?.get("android_client_info") as? Map<*, *>
            androidInfo?.get("package_name") == "ai.emie.app"
        }) { "Google configuration has no ai.emie.app client" }
    }
    if (buildType != "debug") {
        check(signingFile.isFile && signingComplete && signingStore?.isFile == true) {
            "Release/Profile requires complete real android/key.properties and its referenced keystore"
        }
        check(!signing.getProperty("keyAlias").equals("androiddebugkey", true) &&
            !signingStore!!.name.equals("debug.keystore", true)) { "Debug signing is forbidden for Release/Profile" }
        val store = KeyStore.getInstance(signingStore, signing.getProperty("storePassword").toCharArray())
        val cert = store.getCertificate(signing.getProperty("keyAlias")) as? java.security.cert.X509Certificate
        check(store.isKeyEntry(signing.getProperty("keyAlias")) && cert != null &&
            !cert.subjectX500Principal.name.contains("Android Debug", ignoreCase = true)) { "A non-debug signing identity is required" }
    }
}

android {
    namespace = "ai.emie.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_11.toString() }
    defaultConfig {
        applicationId = "ai.emie.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["localBackendPort"] = localPort
    }
    if (localMode) sourceSets.getByName("debug") {
        manifest.srcFile("src/local/AndroidManifest.xml")
        res.srcDir("src/local/res")
    }
    signingConfigs {
        create("release") {
            if (signingComplete) {
                storeFile = signingStore
                storePassword = signing.getProperty("storePassword")
                keyAlias = signing.getProperty("keyAlias")
                keyPassword = signing.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        getByName("release") { signingConfig = signingConfigs.getByName("release") }
        maybeCreate("profile").signingConfig = signingConfigs.getByName("release")
    }
}

// AGP wires this checked manifest into every packaged variant, also for
// aggregate, abbreviated and direct packaging tasks.
abstract class EmieManifestTask : DefaultTask() {
    @get:InputFile @get:PathSensitive(PathSensitivity.NONE)
    abstract val inputManifest: RegularFileProperty
    @get:OutputFile abstract val outputManifest: RegularFileProperty
    @get:Input abstract val local: Property<Boolean>
    @get:Input abstract val origin: Property<String>
    @TaskAction fun transform() {
        val factory = DocumentBuilderFactory.newInstance()
        factory.isNamespaceAware = true
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
        val document = factory.newDocumentBuilder().parse(inputManifest.get().asFile)
        val ns = "http://schemas.android.com/apk/res/android"
        val application = document.getElementsByTagName("application").item(0) as org.w3c.dom.Element
        if (!local.get()) {
            check(application.getAttributeNS(ns, "usesCleartextTraffic") == "false") { "Non-local manifest must forbid cleartext" }
            check(!application.hasAttributeNS(ns, "networkSecurityConfig")) { "Non-local manifest must not carry local network policy" }
        }
        check(document.getElementsByTagName("instrumentation").length == 0) { "Test instrumentation cannot ship in the app manifest" }
        if (origin.get().isNotEmpty()) {
            val uri = URI(origin.get())
            val activity = (0 until document.getElementsByTagName("activity").length)
                .map { document.getElementsByTagName("activity").item(it) as org.w3c.dom.Element }
                .single { it.getAttributeNS(ns, "name") == "ai.emie.app.MainActivity" }
            val filter = document.createElement("intent-filter")
            filter.setAttributeNS(ns, "android:autoVerify", "true")
            for ((tag, name) in listOf("action" to "android.intent.action.VIEW",
                "category" to "android.intent.category.DEFAULT", "category" to "android.intent.category.BROWSABLE")) {
                val child = document.createElement(tag)
                child.setAttributeNS(ns, "android:name", name); filter.appendChild(child)
            }
            val data = document.createElement("data")
            for ((key, value) in mapOf("scheme" to "https", "host" to uri.host, "path" to "/reset-password")) {
                data.setAttributeNS(ns, "android:$key", value)
            }
            if (uri.port != -1 && uri.port != 443) data.setAttributeNS(ns, "android:port", uri.port.toString())
            // Dart also enforces the exact effective port for default HTTPS.
            filter.appendChild(data); activity.appendChild(filter)
        }
        outputManifest.get().asFile.parentFile.mkdirs()
        TransformerFactory.newInstance().newTransformer().transform(DOMSource(document), StreamResult(outputManifest.get().asFile))
    }
}

androidComponents.onVariants { variant ->
    val guard = tasks.register<EmieManifestTask>("check${variant.name.replaceFirstChar { it.uppercase() }}EmieManifest") {
        local.set(localMode)
        origin.set(recoveryOrigin)
        outputs.upToDateWhen { false }
        doFirst { validateVariant(variant.buildType ?: error("Missing build type")) }
    }
    variant.artifacts.use(guard).wiredWithFiles(EmieManifestTask::inputManifest, EmieManifestTask::outputManifest)
        .toTransform(SingleArtifact.MERGED_MANIFEST)
    // Validate even when outputs are up-to-date; inspect actual variant tasks,
    // never the spelling of a CLI task. No configuration-cache bypass.
    gradle.taskGraph.whenReady {
        if (hasTask(guard.get())) validateVariant(variant.buildType ?: error("Missing build type"))
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.6.0"))
    implementation("com.google.android.gms:play-services-auth:20.7.0")
}
flutter { source = "../../" }
