import 'dart:async';
import 'dart:typed_data';
import 'package:ble/ble.dart';
import 'package:logging/logging.dart';
import '../euicc_adapter.dart';
import '../../utils/hex_utils.dart';
import '../../utils/error_codes.dart';
import 'ble_transport_utils.dart';

class RedBle2Adapter extends BaseAdapter {
  static final Logger _log = Logger('RedBle2Adapter');

  RedBle2Adapter() : super(_log);
  BluetoothDevice? _device;
  BluetoothCharacteristic? _txChar;
  BluetoothCharacteristic? _rxChar;
  StreamSubscription? _rxSub;
  StreamSubscription? _connSub;
  String? _lastAtr;

  static final Guid _serviceUuid = Guid('4553');
  static final Guid _rxCharUuid = Guid('544b');
  static final Guid _txCharUuid = Guid('6d65');

  static const int _ccidHeaderLength = 10;
  static const int _pcToRdrIccPowerOn = 0x62;
  static const int _pcToRdrXfrBlock = 0x6F;

  final StreamController<EuiccPortState> _stateController =
      StreamController<EuiccPortState>.broadcast();

  @override
  Stream<EuiccPortState> get stateStream => _stateController.stream;

  @override
  bool get requiresRefresh => false;

  @override
  String? get lastAtr => _lastAtr;

  @override
  Future<List<Reader>> listReaders({bool force = false}) async {
    return connectedReader != null ? [connectedReader!] : [];
  }

  @override
  Future<void> connect(Reader reader) async {
    return await runExclusive(() async {
      updateConnectedReader(reader);
      final readerName = reader.id;
      final deviceId = readerName.split('|').last;
      _device = BluetoothDevice.fromId(deviceId);

      log.info("Connecting to RedBle2 device: $deviceId");
      try {
        await connectBleDevice(_device!, log);
        log.info("Connected to device: $deviceId");

        await _connSub?.cancel();
        _connSub = _device!.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            log.warning("RedBle2 disconnected unexpectedly");
            _txChar = null;
            _rxChar = null;
            _stateController.add(EuiccPortState.closed);
          }
        });

        final services = await _device!.discoverServices();
        final service = services.firstWhere(
          (s) => s.uuid == _serviceUuid,
          orElse: () => throw AppException(
            AppErrorCode.ERROR_BLUETOOTH_SERVICE_NOT_FOUND,
            message: "RED BLE 2 service not found",
          ),
        );

        _txChar = service.characteristics.firstWhere(
          (c) => c.uuid == _txCharUuid,
          orElse: () => throw AppException(
            AppErrorCode.ERROR_BLUETOOTH_CHARACTERISTIC_NOT_FOUND,
            message: "TX characteristic not found",
          ),
        );
        _rxChar = service.characteristics.firstWhere(
          (c) => c.uuid == _rxCharUuid,
          orElse: () => throw AppException(
            AppErrorCode.ERROR_BLUETOOTH_CHARACTERISTIC_NOT_FOUND,
            message: "RX characteristic not found",
          ),
        );
        log.info("Found characteristics - TX: $_txCharUuid, RX: $_rxCharUuid");

        await _rxChar!.setNotifyValue(true);

        log.info("Initializing port protocol...");
        await _claim();

        final atrBytes = await _powerOn();
        _lastAtr = HexUtils.bytesToHex(atrBytes);
        log.info("Port open. ATR: $_lastAtr");

        _stateController.add(EuiccPortState.open);
      } catch (e) {
        log.shout("Connection sequence failed: $e");
        await disconnect();
        if (e is AppException) rethrow;
        if (e is TimeoutException) {
          throw AppException(
            AppErrorCode.ERROR_BLUETOOTH_TIMEOUT,
            originalError: e,
          );
        }
        throw AppException(
          AppErrorCode.ERROR_BLUETOOTH_CONNECT_FAILED,
          originalError: e,
        );
      }
    });
  }

  @override
  Future<void> disconnect() async {
    return await runExclusive(() async {
      log.info("Disconnecting from RedBle2 device...");
      await _rxSub?.cancel();
      _rxSub = null;
      await _connSub?.cancel();
      _connSub = null;
      await _device?.disconnect();
      _device = null;
      _txChar = null;
      _rxChar = null;
      updateConnectedReader(null);
      _stateController.add(EuiccPortState.closed);
      log.info("Disconnected.");
    });
  }

  Future<void> _claim() async {
    // Red 2 negotiation / claim sequence
    try {
      final negotiation = Uint8List.fromList([
        0xFF,
        0xFF,
        0xFF,
        0x00,
        0x02,
        0x00,
        0x00,
      ]);
      final resp = await _transmitControl(negotiation);
      if (resp.isNotEmpty && resp[0] == 0x61) {
        final len = resp[1];
        await _transmitControl(
          Uint8List.fromList([0xFF, 0xFF, 0xFF, 0x01, len]),
        );
      }
    } catch (e) {
      log.warning("Protocol negotiation failed (non-critical): $e");
    }
  }

  Future<Uint8List> _powerOn() async {
    final resp = await _exchangeCcid(
      _pcToRdrIccPowerOn,
      Uint8List.fromList([0x01]),
    );
    return resp;
  }

  @override
  Future<Uint8List> sendRawApdu(Uint8List apdu) async {
    return await _exchangeCcid(_pcToRdrXfrBlock, apdu);
  }

  /// Low-level CCID exchange helper
  Future<Uint8List> _exchangeCcid(int msgType, Uint8List payload) async {
    final request = _packCcid(msgType, payload);
    final response = await _transmitRaw(request);

    if (response.length < _ccidHeaderLength) {
      throw Exception("Invalid CCID response length: ${response.length}");
    }

    final respLen = ByteData.sublistView(
      response,
      1,
      5,
    ).getUint32(0, Endian.little);

    if (response.length < _ccidHeaderLength + respLen) {
      throw AppException(
        AppErrorCode.ERROR_TRANSACTION_FAILED,
        message:
            "Truncated CCID response: expected ${_ccidHeaderLength + respLen}, got ${response.length}",
      );
    }

    // Basic status check for CCID
    final status = response[7];
    if ((status & 0x03) == 0x01) {
      log.warning(
        "CCID Status indicates command failed: status=$status error=${response[8]}",
      );
    }

    return response.sublist(_ccidHeaderLength, _ccidHeaderLength + respLen);
  }

  Uint8List _packCcid(int msgType, Uint8List data) {
    final bytes = Uint8List(_ccidHeaderLength + data.length);
    final bd = ByteData.sublistView(bytes);
    bd.setUint8(0, msgType);
    bd.setUint32(1, data.length, Endian.little);
    bd.setUint8(5, 0); // Slot
    bd.setUint8(6, 0); // Seq
    bd.setUint8(7, 0); // Status
    bd.setUint8(8, 0); // Error
    bd.setUint8(9, 0); // Specific
    bytes.setRange(_ccidHeaderLength, bytes.length, data);
    return bytes;
  }

  Future<Uint8List> _transmitControl(Uint8List request) async {
    return await _exchangeCcid(_pcToRdrXfrBlock, request);
  }

  Future<Uint8List> _transmitRaw(Uint8List request) async {
    if (_device == null || _txChar == null || _rxChar == null) {
      throw AppException(
        AppErrorCode.ERROR_BLUETOOTH_CONNECT_FAILED,
        message: "RED BLE 2 not connected",
      );
    }

    final completer = Completer<Uint8List>();
    final bytesReceived = <int>[];
    int expectedLength = -1;

    _rxSub = _rxChar!.onValueReceived.listen((data) {
      log.info("Received data: $data");
      if (data.length >= _ccidHeaderLength &&
          data[7] & 0x80 == 0x80 &&
          data[1] == 0 &&
          data[2] == 0 &&
          data[3] == 0 &&
          data[4] == 0) {
        log.info("Time extension required");
        return; // time extension required
      }
      bytesReceived.addAll(data);

      if (expectedLength == -1 && bytesReceived.length >= _ccidHeaderLength) {
        // CCID length is at offset 1-4 (little-endian)
        final payloadLen =
            bytesReceived[1] |
            (bytesReceived[2] << 8) |
            (bytesReceived[3] << 16) |
            (bytesReceived[4] << 24);
        expectedLength = _ccidHeaderLength + payloadLen;
      }
      if (expectedLength != -1 && bytesReceived.length >= expectedLength) {
        if (!completer.isCompleted) {
          completer.complete(
            Uint8List.fromList(bytesReceived.sublist(0, expectedLength)),
          );
        }
      }
    });

    try {
      await writeBleChunks(
        device: _device!,
        characteristic: _txChar!,
        data: request,
      );

      return await completer.future.timeout(const Duration(seconds: 15));
    } catch (e) {
      log.severe("BLE transmission error or timeout: $e");
      if (e is TimeoutException) {
        throw AppException(
          AppErrorCode.ERROR_BLUETOOTH_TIMEOUT,
          originalError: e,
        );
      }
      throw AppException(
        AppErrorCode.ERROR_TRANSACTION_FAILED,
        originalError: e,
      );
    } finally {
      await _rxSub?.cancel();
      _rxSub = null;
    }
  }

  @override
  Future<Channel> openChannel({List<String>? aids}) async {
    return await openLogicalChannel(aids: aids);
  }
}
