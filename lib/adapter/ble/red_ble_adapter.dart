import 'dart:async';
import 'dart:typed_data';
import 'package:ble/ble.dart';
import 'package:logging/logging.dart';
import '../euicc_adapter.dart';
import '../../utils/hex_utils.dart';
import '../../utils/error_codes.dart';
import 'ble_transport_utils.dart';

class RedBleAdapter extends BaseAdapter {
  static final Logger _log = Logger('RedBleAdapter');

  RedBleAdapter() : super(_log);
  BluetoothDevice? _device;
  BluetoothCharacteristic? _txChar;
  BluetoothCharacteristic? _rxChar;
  StreamSubscription? _rxSub;
  StreamSubscription? _connSub;
  String? _lastAtr;

  final Guid serviceUuid = Guid('4553');
  final Guid rxCharUuid = Guid('544b');
  final Guid txCharUuid = Guid('6d65');

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
      // reader.id is expected to be "red_ble:UUID|UUID" or similar
      final parts = reader.id.split('|');
      final deviceId = parts.last;
      _device = BluetoothDevice.fromId(deviceId);

      log.info("Connecting to RedBle device: $deviceId");
      try {
        await connectBleDevice(_device!, log);
        log.info("Connected to device: $deviceId");

        await _connSub?.cancel();
        _connSub = _device!.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            log.warning("RedBle disconnected unexpectedly");
            _txChar = null;
            _rxChar = null;
            _stateController.add(EuiccPortState.closed);
          }
        });

        List<BluetoothService> services = await _device!.discoverServices();
        BluetoothService service = services.firstWhere(
          (s) => s.uuid == serviceUuid,
          orElse: () => throw AppException(
            AppErrorCode.ERROR_BLUETOOTH_SERVICE_NOT_FOUND,
            message: "RED BLE service not found",
          ),
        );
        log.info("Found RED BLE service: $serviceUuid");

        _txChar = service.characteristics.firstWhere(
          (c) => c.uuid == txCharUuid,
          orElse: () => throw AppException(
            AppErrorCode.ERROR_BLUETOOTH_CHARACTERISTIC_NOT_FOUND,
            message: "TX characteristic not found",
          ),
        );
        _rxChar = service.characteristics.firstWhere(
          (c) => c.uuid == rxCharUuid,
          orElse: () => throw AppException(
            AppErrorCode.ERROR_BLUETOOTH_CHARACTERISTIC_NOT_FOUND,
            message: "RX characteristic not found",
          ),
        );
        log.info("Found characteristics - TX: $txCharUuid, RX: $rxCharUuid");

        await _rxChar!.setNotifyValue(true);

        // Port protocol init: Claim and Power On
        log.info("Initializing port protocol (Claim and Power On)...");
        await _claim();
        final atrBytes = await _powerOn();
        _lastAtr = HexUtils.bytesToHex(atrBytes);
        log.info("Power On successful, ATR: $_lastAtr");

        _stateController.add(EuiccPortState.open);
      } catch (e) {
        log.shout("Connection failed: $e");
        await disconnect();
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
      log.info("Disconnecting from RedBle device...");
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
    // 02 | 06 00 | ESTKme
    await _transmit(
      0x02,
      Uint8List.fromList([0x45, 0x53, 0x54, 0x4B, 0x6D, 0x65]),
    );
  }

  Future<Uint8List> _powerOn() async {
    // 03 | 02 00 | 01 01 (PPS)
    return await _transmit(0x03, Uint8List.fromList([0x01, 0x01]));
  }

  @override
  Future<Uint8List> sendRawApdu(Uint8List apdu) async {
    // 04 | LEN | APDU
    final resp = await _transmit(0x04, apdu);
    // Response format: CMD | LEN | DATA
    if (resp.length < 3) {
      log.warning("APDU << Error: Invalid response length (${resp.length})");
      throw AppException(
        AppErrorCode.ERROR_TRANSACTION_FAILED,
        message: "Invalid response from RED BLE",
      );
    }
    return resp.sublist(3);
  }

  Future<Uint8List> _transmit(int cmd, Uint8List? payload) async {
    if (_device == null || _txChar == null || _rxChar == null) {
      throw AppException(
        AppErrorCode.ERROR_BLUETOOTH_CONNECT_FAILED,
        message: "RED BLE not connected",
      );
    }

    final payloadLen = payload?.length ?? 0;
    final header = Uint8List(3);
    header[0] = cmd;
    header[1] = payloadLen & 0xFF;
    header[2] = (payloadLen >> 8) & 0xFF;

    final request = Uint8List.fromList([...header, ...?payload]);

    final completer = Completer<Uint8List>();
    final buffer = <int>[];
    int expectedLength = -1;

    _rxSub = _rxChar!.onValueReceived.listen((data) {
      buffer.addAll(data);
      if (expectedLength == -1 && buffer.length >= 3) {
        expectedLength = buffer[1] + (buffer[2] << 8) + 3;
      }
      if (expectedLength != -1 && buffer.length >= expectedLength) {
        if (!completer.isCompleted) {
          completer.complete(Uint8List.fromList(buffer));
        }
      }
    });

    try {
      await writeBleChunks(
        device: _device!,
        characteristic: _txChar!,
        data: request,
      );

      final response = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw AppException(
          AppErrorCode.ERROR_BLUETOOTH_TIMEOUT,
          message: "RED BLE transmission timeout",
        ),
      );
      return response;
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
