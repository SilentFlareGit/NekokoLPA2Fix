import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:logging/logging.dart';
import '../../utils/hex_utils.dart';
import '../euicc_adapter.dart';

const int _vendorId = 0x04d9;

// --- JS Interop Definitions for WebUSB APDU SDK ---
@JS('WebUsbApduDevice')
extension type WebUsbApduDevice._(JSObject _) implements JSObject {
  external factory WebUsbApduDevice(USBDevice device);
  external static JSPromise<USBDevice> requestDevice();
  external JSPromise<JSAny?> open([JSObject? options]);
  external JSPromise<JSAny?> close();
  external JSPromise<JSUint8Array> sendApdu(
    JSUint8Array apduBytes, [
    JSObject? options,
  ]);
  external JSPromise<WebUsbStatusResult> getStatus([JSObject? options]);
  external JSObject? getInfo();
}

@JS()
@anonymous
extension type WebUsbStatusResult._(JSObject _) implements JSObject {
  external bool get ok;
  external int? get sw1;
  external int? get sw2;
  external int? get cardState;
  external int? get owner;
  external JSUint8Array? get atr;
}

@JS('USB')
extension type USB._(JSObject _) implements JSObject {
  external JSPromise<JSArray<USBDevice>> getDevices();
}

@JS('USBDevice')
extension type USBDevice._(JSObject _) implements JSObject {
  external int get vendorId;
  external int get productId;
  external String? get serialNumber;
  external String? get productName;
}

extension NavigatorUSB on web.Navigator {
  external USB get usb;
}
// ------------------------------------------------
// ------------------------------------------------

class ScrpAdapter extends BaseAdapter {
  static final Logger _log = Logger('ScrpAdapter');

  WebUsbApduDevice? _apduDevice;

  final StreamController<EuiccPortState> _stateController =
      StreamController<EuiccPortState>.broadcast();

  ScrpAdapter() : super(_log);

  @override
  Stream<EuiccPortState> get stateStream => _stateController.stream;

  @override
  bool get requiresRefresh => false;

  @override
  String? get lastAtr => _lastAtr;
  String? _lastAtr;

  @override
  Future<List<Reader>> listReaders({bool force = false}) async {
    _log.info("listReaders() called (package:web)");
    final readers = <Reader>[];

    final navigator = web.window.navigator as JSObject;
    if (!navigator.has('usb')) {
      _log.warning("WebUSB not supported in this browser");
      return [];
    }

    try {
      _log.info("Requesting getDevices()...");
      // Force cast to our local USB type via JSObject access
      final usb = (navigator['usb'] as JSObject) as USB;
      final devicesJS = await usb.getDevices().toDart;
      final devices = devicesJS.toDart; // JSArray to List

      _log.info("Found ${devices.length} USB devices");

      for (final device in devices) {
        _log.info(
          "Checking device: ${device.productName} (VID: ${device.vendorId}, PID: ${device.productId}, SN: ${device.serialNumber})",
        );
        if (device.vendorId == _vendorId) {
          readers.add(
            Reader(
              id: "scrp:${device.serialNumber ?? 'unknown'}_${device.productId}",
              name: "SCRP (${device.productName ?? 'Device'})",
              source: this,
              context: device,
            ),
          );
        }
      }
    } catch (e) {
      _log.warning("Error listing WebUSB devices: $e");
    }

    _log.info("Returning ${readers.length} readers");
    return readers;
  }

  Future<Reader?> scanScrp() async {
    _log.info("scanScrp() called - triggering browser picker (SDK)");
    try {
      final device = await WebUsbApduDevice.requestDevice().toDart;

      _log.info(
        "User selected device: ${device.productName} (SN: ${device.serialNumber})",
      );

      return Reader(
        id: "scrp:${device.serialNumber ?? 'unknown'}_${device.productId}",
        name: "SCRP (${device.productName ?? 'Device'})",
        source: this,
        context: device,
      );
    } catch (e) {
      _log.info("Pairing cancelled or failed: $e");
      return null;
    }
  }

  @override
  Future<void> connect(Reader reader) async {
    _log.info("connect() called for reader: ${reader.id}");
    return await runExclusive(() async {
      _apduDevice = null;
      _lastAtr = null;

      USBDevice? device;

      // Use existing device instance if passed in context, otherwise find it
      if (reader.context != null) {
        _log.info("Using cached USBDevice from Reader context");
        device = reader.context as USBDevice;
      } else {
        _log.info("No cached device, searching getDevices()...");
        final navigator = web.window.navigator as JSObject;
        final usb = (navigator['usb'] as JSObject) as USB;
        final devicesJS = await usb.getDevices().toDart;
        final devices = devicesJS.toDart;

        for (final d in devices) {
          final id = "scrp:${d.serialNumber ?? 'unknown'}_${d.productId}";
          if (id == reader.id) {
            device = d;
            break;
          }
        }
      }

      if (device == null) {
        _log.severe("Device not found for ID: ${reader.id}");
        throw Exception("Device not found");
      }

      _log.info("Opening device via SDK: ${device.productName}");
      _apduDevice = WebUsbApduDevice(device);
      await _apduDevice!.open().toDart;

      // Check Status and Claim Ownership
      try {
        _log.info("Checking SCRP status via SDK...");
        await _checkStatus();
      } catch (e) {
        _log.warning("Status check failed: $e");
        await disconnect();
        rethrow;
      }

      _log.info("Updating connected reader");
      updateConnectedReader(reader);

      _stateController.add(EuiccPortState.open);
      _log.info("Connection successful.");
    });
  }

  @override
  Future<void> disconnect() async {
    return await runExclusive(() async {
      try {
        if (_apduDevice != null) {
          await _apduDevice!.close().toDart;
        }
      } catch (e) {
        _log.warning("Disconnect error: $e");
      } finally {
        _apduDevice = null;
        updateConnectedReader(null);
        _stateController.add(EuiccPortState.closed);
      }
    });
  }

  @override
  Future<void> reconnect() async {
    if (_apduDevice != null) {
      await disconnect();
    }
  }

  // Missing implementations
  @override
  Future<Channel> openChannel({List<String>? aids}) async {
    return await openLogicalChannel(aids: aids);
  }

  @override
  Future<Uint8List> sendRawApdu(
    Uint8List apdu, {
    bool isInternal = false,
  }) async {
    if (_apduDevice == null) {
      throw Exception("Not connected");
    }

    _log.info(">> APDU (Internal: $isInternal): ${HexUtils.bytesToHex(apdu)}");

    try {
      final responseJS = await _apduDevice!.sendApdu(apdu.toJS).toDart;
      final response = responseJS.toDart;

      _log.info(
        "<< RAPDU (${response.length} bytes): ${HexUtils.bytesToHex(response)}",
      );

      // Check for 6985 (Busy/CCID owned) if not internal status check
      if (!isInternal &&
          response.length >= 2 &&
          response[response.length - 2] == 0x69 &&
          response[response.length - 1] == 0x85) {
        _log.severe("Card returned 6985 (CCID Busy)");
        throw Exception("Card is currently owned by CCID interface (Busy)");
      }

      return response;
    } catch (e) {
      _log.severe("WebUSB SDK Transfer Error: $e");
      rethrow;
    }
  }

  Future<void> _checkStatus() async {
    if (_apduDevice == null) return;
    _log.info("Requesting SDK getStatus()...");
    try {
      final result = await _apduDevice!.getStatus().toDart;
      if (result.ok) {
        final atrBytes = result.atr?.toDart;
        if (atrBytes != null && atrBytes.isNotEmpty) {
          _lastAtr = HexUtils.bytesToHex(atrBytes);
          _log.info("ATR found via SDK: $_lastAtr");
        }
        _log.info("Card State: ${result.cardState}, Owner: ${result.owner}");
      } else {
        _log.warning(
          "SDK getStatus returned not ok: SW=${result.sw1?.toRadixString(16)}${result.sw2?.toRadixString(16)}",
        );
      }
    } catch (e) {
      _log.warning("SDK getStatus error: $e");
    }
  }
}
