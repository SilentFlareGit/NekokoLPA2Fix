package ee.nekoko.nlpa2

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Parcelable
import android.os.Build
import java.lang.reflect.InvocationTargetException
import java.io.File
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class NBridgePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var methodChannel: MethodChannel? = null
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null

    companion object {
        private const val CHANNEL_NAME = "ee.nekoko.nbridge_plugin"
        private const val DEFAULT_AUTHORITY = "ee.nekoko.nbridge.provider"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler(this)
        backgroundThread = HandlerThread("NBridgePlugin")
        backgroundThread?.start()
        backgroundHandler = Handler(backgroundThread!!.looper)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        backgroundThread?.quitSafely()
        backgroundThread = null
        backgroundHandler = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "isAvailable") {
            result.success(isProviderAvailable(call.argument("authority")))
            return
        }
        if (call.method == "isRooted") {
            result.success(isRooted())
            return
        }

        backgroundHandler?.post {
            try {
                val response =
                    when (call.method) {
                        "listSlots" -> callProvider("listSlots", null)
                        "connectLogicalChannel" ->
                            callProvider(
                                method = "connectLogicalChannel",
                                extras =
                                    Bundle().apply {
                                        putString("slotId", call.argument("slotId"))
                                        putStringArrayList(
                                            "aids",
                                            ArrayList(call.argument<List<String>>("aids") ?: emptyList()),
                                        )
                                    },
                            )
                        "transmitLogical" ->
                            callProvider(
                                method = "transmitLogical",
                                extras =
                                    Bundle().apply {
                                        putString("connectionId", call.argument("connectionId"))
                                        putString("apdu", call.argument("apdu"))
                                    },
                            )
                        "transmitBasic" ->
                            callProvider(
                                method = "transmitBasic",
                                extras =
                                    Bundle().apply {
                                        putString("slotId", call.argument("slotId"))
                                        putString("apdu", call.argument("apdu"))
                                    },
                            )
                        "closeLogicalChannel" ->
                            callProvider(
                                method = "closeLogicalChannel",
                                extras =
                                    Bundle().apply {
                                        putString("connectionId", call.argument("connectionId"))
                                    },
                            )
                        else -> throw IllegalArgumentException("Unknown method ${call.method}")
                    }

                Handler(context?.mainLooper ?: return@post).post { result.success(response) }
            } catch (t: Throwable) {
                Handler(context?.mainLooper ?: return@post).post {
                    val root = t.rootCause()
                    result.error("ERROR", root.readableMessage(), root.stackTraceToString())
                }
            }
        } ?: result.error("ERROR", "Background handler unavailable", null)
    }

    private fun isProviderAvailable(authority: String?): Boolean {
        val appContext = context ?: return false
        return appContext.packageManager.resolveContentProvider(
            authority ?: DEFAULT_AUTHORITY,
            0,
        ) != null
    }

    private fun isRooted(): Boolean {
        if (Build.TAGS?.contains("test-keys") == true) {
            return true
        }

        val suspiciousPaths = listOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/system_ext/bin/su",
            "/system/bin/.ext/su",
            "/system/usr/we-need-root/su",
            "/vendor/bin/su",
            "/data/adb/magisk",
            "/data/adb/ksu",
            "/data/adb/modules",
            "/cache/magisk.log",
        )
        if (suspiciousPaths.any { path -> File(path).exists() }) {
            return true
        }

        val pathEnv = System.getenv("PATH").orEmpty()
        if (pathEnv.isNotEmpty()) {
            val hasSu = pathEnv
                .split(':')
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .any { dir -> File(dir, "su").exists() }
            if (hasSu) {
                return true
            }
        }

        return false
    }

    private fun callProvider(method: String, extras: Bundle?): Map<String, Any?> {
        val appContext = context ?: throw IllegalStateException("Context unavailable")
        val authority = DEFAULT_AUTHORITY
        if (!isProviderAvailable(authority)) {
            throw IllegalStateException("NBridge provider is not installed")
        }

        val response =
            appContext.contentResolver.call(
                Uri.parse("content://$authority"),
                method,
                null,
                extras,
            ) ?: Bundle()
        return bundleToMap(response)
    }

    private fun bundleToMap(bundle: Bundle): Map<String, Any?> {
        val map = linkedMapOf<String, Any?>()
        for (key in bundle.keySet()) {
            map[key] = normalizeValue(bundle.get(key))
        }
        return map
    }

    @Suppress("DEPRECATION")
    private fun normalizeValue(value: Any?): Any? {
        return when (value) {
            is Bundle -> bundleToMap(value)
            is ArrayList<*> -> value.map { normalizeValue(it) }
            is List<*> -> value.map { normalizeValue(it) }
            is Parcelable -> {
                if (value is Bundle) bundleToMap(value) else value.toString()
            }
            else -> value
        }
    }

    private fun Throwable.rootCause(): Throwable {
        return if (this is InvocationTargetException && targetException != null) {
            targetException.rootCause()
        } else {
            cause?.takeIf { it !== this }?.rootCause() ?: this
        }
    }

    private fun Throwable.readableMessage(): String {
        val message = message
        return if (message.isNullOrBlank()) {
            this::class.java.name
        } else {
            "${this::class.java.name}: $message"
        }
    }
}
