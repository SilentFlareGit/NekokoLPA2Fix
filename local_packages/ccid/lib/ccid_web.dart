import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';

import 'ccid.dart';
import 'ccid_platform_interface.dart';
import 'web/js_smart_card.dart';

@JS('navigator.userAgent')
external String get _userAgent;

abstract class _WebCcidStrategy {
  Future<void> init();
  Future<List<String>> listReaders();
  Future<CcidCard> connect(String reader);
  Future<String?> transceive(String reader, String capdu);
  Future<void> disconnect(String reader);
}

class _WicgStrategy implements _WebCcidStrategy {
  final Map<String, SmartCardReader> _readersCache = {};
  final Map<String, SmartCardConnection> _connections = {};

  @override
  Future<void> init() async {
    debugPrint("[WICG] Initializing WICG strategy");
  }

  @override
  Future<List<String>> listReaders() async {
    debugPrint("[WICG] Listing readers...");
    final sc = smartCard;
    if (sc == null) {
      debugPrint("[WICG] navigator.smartCard is null");
      return [];
    }

    try {
      final readersJS = await sc.getReaders().toDart;
      final readersList = readersJS.toDart;

      _readersCache.clear();
      final names = <String>[];

      for (var i = 0; i < readersList.length; i++) {
        final reader = readersList[i];
        final name = reader.name;
        _readersCache[name] = reader;
        names.add(name);
      }
      debugPrint("[WICG] Found ${names.length} readers: $names");
      return names;
    } catch (e) {
      debugPrint("[WICG] listReaders error: $e");
      return [];
    }
  }

  @override
  Future<CcidCard> connect(String readerName) async {
    debugPrint("[WICG] Connecting to reader: $readerName");
    final reader = _readersCache[readerName];
    if (reader == null) {
      debugPrint("[WICG] Reader '$readerName' not found in cache");
      throw Exception("Reader not found");
    }
    try {
      final connection = await reader.connect("shared").toDart;
      _connections[readerName] = connection;
      debugPrint("[WICG] Connected successfully to $readerName");
      return CcidCard(readerName, "");
    } catch (e) {
      debugPrint("[WICG] Connection failed: $e");
      rethrow;
    }
  }

  @override
  Future<String?> transceive(String reader, String capdu) async {
    debugPrint("[WICG] Transceive to $reader, CAPDU: $capdu");
    final connection = _connections[reader];
    if (connection == null) {
      debugPrint("[WICG] No connection found for $reader");
      throw Exception('Card not connected');
    }

    try {
      final apduBytes = Uint8List.fromList(hex.decode(capdu));
      final jsData = apduBytes.toJS;

      final req = SmartCardAPDU(data: jsData);
      final response = await connection.transmit(req).toDart;

      final resDataBuf = response.data;
      final sw = response.sw;

      final resBytes = JSUint8Array(resDataBuf).toDart;

      final sw1 = (sw >> 8) & 0xFF;
      final sw2 = sw & 0xFF;

      final fullResponse = BytesBuilder();
      fullResponse.add(resBytes);
      fullResponse.addByte(sw1);
      fullResponse.addByte(sw2);

      final rapdu = hex.encode(fullResponse.toBytes());
      debugPrint("[WICG] RAPDU: $rapdu");
      return rapdu;
    } catch (e) {
      debugPrint("[WICG] Transceive error: $e");
      rethrow;
    }
  }

  @override
  Future<void> disconnect(String reader) async {
    debugPrint("[WICG] Disconnecting from $reader");
    final connection = _connections.remove(reader);
    if (connection != null) {
      try {
        await connection.disconnect().toDart;
        debugPrint("[WICG] Disconnected $reader");
      } catch (e) {
        debugPrint("[WICG] Disconnect error: $e");
      }
    }
  }
}

class _NoStrategy implements _WebCcidStrategy {
  @override
  Future<void> init() async {}
  @override
  Future<List<String>> listReaders() async => [];
  @override
  Future<CcidCard> connect(String reader) async =>
      throw Exception("No CCID strategy available");
  @override
  Future<String?> transceive(String reader, String capdu) async => null;
  @override
  Future<void> disconnect(String reader) async {}
}

class WebCcid extends CcidPlatform {
  _WebCcidStrategy? _strategy;

  Future<void> _ensureInit() async {
    if (_strategy != null) return;

    debugPrint("[WebCcid] Detecting strategy...");
    if (smartCard != null) {
      debugPrint("[WebCcid] Selected WICG strategy (ChromeOS native)");
      _strategy = _WicgStrategy();
    } else {
      debugPrint("[WebCcid] No native smartcard support found (WICG null)");
      _strategy = _NoStrategy();
    }
    await _strategy!.init();
  }

  @override
  Future<List<String>> listReaders() async {
    await _ensureInit();
    return _strategy!.listReaders();
  }

  @override
  Future<Map<String, String>> listReaderATRs() async {
    await _ensureInit();
    final names = await listReaders();
    return {for (var name in names) name: ""};
  }

  @override
  Future<CcidCard> connect(String reader) async {
    await _ensureInit();
    return _strategy!.connect(reader);
  }

  @override
  Future<String> powerCycle(String reader) async {
    debugPrint("[WebCcid] powerCycle called for $reader (stubbed)");
    return "";
  }

  @override
  Future<String?> transceive(String reader, String capdu) async {
    await _ensureInit();
    return _strategy!.transceive(reader, capdu);
  }

  @override
  Future<void> disconnect(String reader) async {
    await _ensureInit();
    return _strategy!.disconnect(reader);
  }
}
