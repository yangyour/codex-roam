package app.codexroam

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import com.easytier.jni.EmbeddedEasyTier
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "app.codexroam/easytier"
        private const val EVENTS = "app.codexroam/easytier_events"
        private const val VPN_PERMISSION_REQUEST = 4107
    }

    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EmbeddedEasyTier.attach(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepare" -> prepareVpn(result)
                    "start" -> {
                        @Suppress("UNCHECKED_CAST")
                        val settings = call.arguments as? Map<String, Any?> ?: emptyMap()
                        result.success(EmbeddedEasyTier.start(settings))
                    }
                    "stop" -> result.success(EmbeddedEasyTier.stop())
                    "status" -> result.success(EmbeddedEasyTier.status())
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        EmbeddedEasyTier.setEventSink(events)
                    }

                    override fun onCancel(arguments: Any?) {
                        EmbeddedEasyTier.setEventSink(null)
                    }
                },
            )
    }

    private fun prepareVpn(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent == null) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error("permission_pending", "VPN permission request is already open", null)
            return
        }
        permissionResult = result
        startActivityForResult(intent, VPN_PERMISSION_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_PERMISSION_REQUEST) {
            permissionResult?.success(resultCode == Activity.RESULT_OK)
            permissionResult = null
        }
    }
}
