package im.nfc.ccid

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.*
import android.os.Build
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlin.collections.component1
import kotlin.collections.component2
import kotlin.collections.set

/** CcidPlugin */
class CcidPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var context: Context
    private lateinit var usbManager: UsbManager
    private var readers = mutableMapOf<String, Reader>()
    private var readerATR = mutableMapOf<Int, String>()
    


    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == ACTION_USB_PERMISSION) {
                val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                    device?.apply {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val reader = readers[intent.identifier]
                            if (reader == null) {
                                Log.e(TAG, "Reader not found")
                                return
                            }
                            if (reader.permissionOnly) {
                                readers[reader.name] = reader.copy(result = null, permissionOnly = false)
                                eventSink?.success(mapOf("type" to "permission_granted", "reader" to reader.name))
                                reader.result!!.success(null)
                                return
                            }
                            val _ccid = connectToInterface(device, reader.interfaceIdx)
                            if (_ccid != null) {
                                readers[reader.name] = reader.copy(ccid = _ccid.first, result = null)
                                eventSink?.success(mapOf("type" to "permission_granted", "reader" to reader.name))
                                reader.result!!.success(_ccid.second)
                            } else {
                                reader.result!!.error(
                                    "CCID_READER_CONNECT_ERROR",
                                    "Failed to connect [r]",
                                    null
                                )
                            }
                        } else {
                            val reader = readers.iterator().next().value
                            if (reader == null) {
                                Log.e(TAG, "Reader not found")
                                return
                            }
                            if (reader.permissionOnly) {
                                readers[reader.name] = reader.copy(result = null, permissionOnly = false)
                                eventSink?.success(mapOf("type" to "permission_granted", "reader" to reader.name))
                                reader.result!!.success(null)
                                return
                            }
                            val _ccid = connectToInterface(device, reader.interfaceIdx)
                            if (_ccid != null) {
                                readers[reader.name] = reader.copy(ccid = _ccid.first, result = null)
                                eventSink?.success(mapOf("type" to "permission_granted", "reader" to reader.name))
                                reader.result!!.success(_ccid.second)
                            } else {
                                reader.result!!.error(
                                    "CCID_READER_CONNECT_ERROR",
                                    "Failed to connect [r]",
                                    null
                                )
                            }
                        }
                    }
                } else {
                    Log.d(TAG, "permission denied for device $device")
                    val intentReaderName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) intent.identifier else null
                    val reader = if (intentReaderName != null) readers[intentReaderName] else readers.values.firstOrNull { it.result != null }
                    
                    if (reader != null && reader.result != null) {
                        reader.result.error("CCID_PERMISSION_DENIED", "USB permission denied", null)
                        readers[reader.name] = reader.copy(result = null, permissionOnly = false)
                    }
                }
            }
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ccid")
        channel.setMethodCallHandler(this)

        val eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "ccid/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(usbReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(usbReceiver, filter)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context.unregisterReceiver(usbReceiver)
    }

    @OptIn(ExperimentalStdlibApi::class)
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "listReaders" -> {
                result.success(listReaders())
            }

            "listReaderATRs" -> {
                result.success(listReadersWithATR())
            }

            "connect" -> {
                val name = call.arguments as String
                connect(name, result)
            }

            "requestPermission" -> {
                val name = call.arguments as String
                requestPermission(name, result)
            }

            "transceive" -> {
                val name = call.argument<String>("reader")!!
                val capdu = call.argument<String>("capdu")!!
                val reader = readers[name]
                if (reader == null) {
                    result.error("CCID_READER_NOT_FOUND", "Reader not found", null)
                    return
                }
                val ccid = reader.ccid
                if (ccid == null) {
                    result.error("CCID_READER_NOT_CONNECTED", "Reader not connected", null)
                    return
                }
                val resp = ccid.xfrBlock(capdu.hexToByteArray())
                result.success(resp.toHexString())
            }

            "powerCycle" -> {
                val name = call.arguments as String
                val reader = readers[name]
                if (reader == null) {
                    result.error("CCID_READER_NOT_FOUND", "Reader not found", null)
                    return
                }
                val ccid = reader.ccid
                if (ccid == null) {
                    result.error("CCID_READER_NOT_CONNECTED", "Reader not connected", null)
                    return
                }
                Log.d(TAG, "Powering off: $reader")
                ccid.iccPowerOff()
                Log.d(TAG, "Powering on: $reader")
                for (i in 0..10) {
                    try {

                        ccid.iccPowerOn()
                        break
                    } finally {
                        Log.d(TAG, "Powering on: $reader failed. retrying")
                        continue
                    }
                }
            }

            "disconnect" -> {
                val name = call.arguments as String
                val reader = readers[name]
                if (reader == null) {
                    result.error("CCID_READER_NOT_FOUND", "Reader not found", null)
                    return
                }
                readers[name] = reader.copy(ccid = null)
            }

            else -> {
                result.notImplemented()
            }
        }
    }



    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

    override fun onDetachedFromActivity() {}

    private fun listReaders(): List<String> {
        val readerTree = mutableMapOf<String, MutableList<Reader>>()

        usbManager.deviceList.values.forEach { device ->
            (0 until device.interfaceCount).forEach { i ->
                val usbInterface = device.getInterface(i)
                if (usbInterface.interfaceClass == UsbConstants.USB_CLASS_CSCID) {
                    val displayName = getDisplayName(device, usbInterface)
                    val reader = Reader(displayName, device.deviceName, i, null, null, false)
                    readerTree.getOrPut(displayName) { mutableListOf() }.add(reader)
                }
            }
        }

        readerTree.forEach { (name, list) ->
            if (!readers.contains(name))
                readers[name] = list[0]
        }

        return readers.keys.toList()
    }

    private fun listReadersWithATR(): Map<String, String> {
        val results = mutableMapOf<String, String>()
        val readerNames = listReaders()
        readerNames.forEach { readerName ->
            val device = usbManager.deviceList.filter { it.key == readers[readerName]!!.deviceName }.values.firstOrNull()
            if (device != null) {
                if (!usbManager.hasPermission(device)) {


                    val intent = Intent(ACTION_USB_PERMISSION)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        intent.identifier = readerName
                    }
                    val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
                    usbManager.requestPermission(device, pendingIntent)
                    results.put(readerName, "[NO_PERMISSION]");
                } else if (readerATR.contains(device.hashCode())){
                    results.put(readerName, readerATR[device.hashCode()]!!);
                } else {
                    val resp = connectToInterface(device, readers[readerName]!!.interfaceIdx)
                    results.put(readerName, resp?.second ?: "");
                    if (resp != null) {
                        readerATR[device.hashCode()] = resp.second
                    }
                }
            }
        }
        return results
    }

    private fun connect(name: String, result: Result) {
        val reader = readers[name]
        if (reader == null) {
            result.error("CCID_READER_NOT_FOUND", "Reader not found", null)
            return
        }
        val device =
            usbManager.deviceList.filter { it.key == reader.deviceName }.values.firstOrNull()
        if (device == null) {
            result.error("CCID_READER_NOT_FOUND", "Reader not found", null)
            return
        }

        if (reader.ccid != null) {
            readers[name] = reader.copy(ccid = null)
//            result.error("CCID_READER_ALREADY_CONNECTED", "Reader already connected", null)
//            return
        }

        if (!usbManager.hasPermission(device)) {
            readers[name] = reader.copy(result = result)
            val intent = Intent(ACTION_USB_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                intent.identifier = name
            }
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
            usbManager.requestPermission(device, pendingIntent)

            return
        } else {
            Log.e(TAG, "Permission OK. Connecting")
            try {
                val _ccid = connectToInterface(device, reader.interfaceIdx)
                if (_ccid != null) {
                    readers[name] = reader.copy(ccid = _ccid.first)
                    result.success(_ccid.second)
                } else {
                    result.error("CCID_READER_CONNECT_ERROR", "Failed to connect [c]", null)
                }
            } catch (c: CcidCardNotFoundException) {
                result.error("CCID_READER_CONNECT_ERROR", "No card in reader", null)
            }
        }
    }

    private fun requestPermission(name: String, result: Result) {
        val reader = readers[name]
        if (reader == null) {
            result.error("CCID_READER_NOT_FOUND", "Reader not found", null)
            return
        }
        val device =
            usbManager.deviceList.filter { it.key == reader.deviceName }.values.firstOrNull()
        if (device == null) {
            result.error("CCID_READER_NOT_FOUND", "Reader not found", null)
            return
        }

        if (usbManager.hasPermission(device)) {
            result.success(null)
        } else {
            readers[name] = reader.copy(result = result, permissionOnly = true)
            val intent = Intent(ACTION_USB_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                intent.identifier = name
            }
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
            usbManager.requestPermission(device, pendingIntent)
        }
    }

    @OptIn(ExperimentalStdlibApi::class)
    private fun connectToInterface(device: UsbDevice, interfaceIdx: Int): Pair<Ccid, String>? {
        val usbInterface = device.getInterface(interfaceIdx)
        val usbConnection = usbManager.openDevice(device)
        if (usbConnection == null) {
            Log.e(TAG, "Failed to open device")
            return null
        }
        val endpoints = getEndpoints(usbInterface)
        val ccid = Ccid(usbConnection, endpoints.first, endpoints.second)
        val descriptor = ccid.getDescriptor(interfaceIdx)
        if (descriptor?.supportsProtocol(Protocol.T0) != true) {
            Log.d(TAG, "Unsupported protocol")
            return null
        }
        if (!usbConnection.claimInterface(usbInterface, true)) {
            Log.e(TAG, "Failed to claim interface")
            return null
        }
        val atr = ccid.iccPowerOn()
        Log.d(TAG, "ATR: ${atr.toHexString()}")
        return Pair(ccid, atr.toHexString())
    }

    private fun getEndpoints(usbInterface: UsbInterface): Pair<UsbEndpoint, UsbEndpoint> {
        var bulkIn: UsbEndpoint? = null
        var bulkOut: UsbEndpoint? = null
        for (i in 0 until usbInterface.endpointCount) {
            val endpoint = usbInterface.getEndpoint(i)
            if (endpoint.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                if (endpoint.direction == UsbConstants.USB_DIR_IN) {
                    bulkIn = endpoint
                } else {
                    bulkOut = endpoint
                }
            }
        }
        if (bulkIn == null || bulkOut == null) {
            throw Exception("Bulk endpoints not found")
        }
        return Pair(bulkIn, bulkOut)
    }

    private fun getDisplayName(device: UsbDevice, usbInterface: UsbInterface): String {
        val nameParts = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            if (device.productName != null) {
                nameParts.add(device.productName!!)
            } else {
                nameParts.add("Unknown")
            }

            if (usbInterface.name != null) {
                nameParts.add(usbInterface.name!!)
            } else {
                nameParts.add("CCID")
            }
            return nameParts.joinToString(" ")
        }
        return "USB CCID Reader"
    }

    companion object {
        private val TAG = FlutterPlugin::class.java.name
        private const val ACTION_USB_PERMISSION = "im.nfc.ccid.USB_PERMISSION"
        private const val TIMEOUT = 1000
    }

    private data class Reader(
        val name: String,
        val deviceName: String,
        val interfaceIdx: Int,
        val ccid: Ccid?,
        val result: Result?,
        val permissionOnly: Boolean = false
    )
}
