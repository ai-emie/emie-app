package ai.emie.app

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var recovery: MethodChannel? = null
    private var pending: String? = null
    private var ready = false

    private fun takeRecovery(source: Intent?) {
        if (source?.action == Intent.ACTION_VIEW) {
            val uri = source.data
            if (uri?.path == "/reset-password") {
                val text = uri.toString()
                pending = if (text.length <= 4096) text else "/reset-password"
                // Only consumed recovery ingress is sanitized before super.
                // Other intents remain intact for the platform and plugins.
                source.data = null
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        takeRecovery(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        recovery = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai.emie.app/recovery")
        recovery?.setMethodCallHandler { call, result ->
            if (call.method == "takeInitial") {
                ready = true
                val value = pending
                pending = null
                result.success(value)
            } else result.notImplemented()
        }
    }

    override fun onNewIntent(intent: Intent) {
        takeRecovery(intent)
        super.onNewIntent(intent)
        setIntent(intent)
        if (ready && pending != null) {
            val value = pending
            pending = null
            recovery?.invokeMethod("resetLink", value)
        }
    }

    override fun onDestroy() {
        pending = null
        recovery?.setMethodCallHandler(null)
        recovery = null
        ready = false
        super.onDestroy()
    }
}
