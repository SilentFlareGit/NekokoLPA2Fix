library ble;

import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator(JSObject _) implements JSObject {
  @JS('bluetooth')
  external _Bluetooth? get bluetooth;
}

extension type _Bluetooth(JSObject _) implements JSObject {
  @JS('getAvailability')
  external JSPromise<JSBoolean> getAvailability();

  @JS('requestDevice')
  external JSPromise<_JSBluetoothDevice?> requestDevice(JSObject options);
}

extension type _JSBluetoothDevice(JSObject _) implements JSObject {
  @JS('id')
  external String get id;
  @JS('name')
  external String? get name;
  @JS('gatt')
  external _JSBluetoothRemoteGATTServer? get gatt;

  @JS('addEventListener')
  external void addEventListener(String type, JSFunction listener);
}

extension type _JSBluetoothRemoteGATTServer(JSObject _) implements JSObject {
  @JS('connect')
  external JSPromise<_JSBluetoothRemoteGATTServer> connect();
  @JS('disconnect')
  external void disconnect();
  @JS('connected')
  external bool get connected;
  @JS('getPrimaryService')
  external JSPromise<_JSBluetoothRemoteGATTService> getPrimaryService(
      String service);
  @JS('getPrimaryServices')
  external JSPromise<JSArray<_JSBluetoothRemoteGATTService>>
      getPrimaryServices();
}

extension type _JSBluetoothRemoteGATTService(JSObject _) implements JSObject {
  @JS('uuid')
  external String get uuid;
  @JS('isPrimary')
  external bool get isPrimary;
  @JS('getCharacteristic')
  external JSPromise<_JSBluetoothRemoteGATTCharacteristic> getCharacteristic(
      String characteristic);
  @JS('getCharacteristics')
  external JSPromise<JSArray<_JSBluetoothRemoteGATTCharacteristic>>
      getCharacteristics();
}

extension type _JSBluetoothRemoteGATTCharacteristic(JSObject _)
    implements JSObject {
  @JS('uuid')
  external String get uuid;
  @JS('value')
  external JSDataView? get value;
  @JS('readValue')
  external JSPromise<JSDataView> readValue();
  @JS('writeValueWithResponse')
  external JSPromise<JSAny?> writeValueWithResponse(JSAny value);
  @JS('writeValueWithoutResponse')
  external JSPromise<JSAny?> writeValueWithoutResponse(JSAny value);
  @JS('startNotifications')
  external JSPromise<_JSBluetoothRemoteGATTCharacteristic> startNotifications();
  @JS('stopNotifications')
  external JSPromise<_JSBluetoothRemoteGATTCharacteristic> stopNotifications();

  @JS('properties')
  external _JSBluetoothCharacteristicProperties get properties;

  @JS('addEventListener')
  external void addEventListener(String type, JSFunction listener);
}

extension type _JSBluetoothCharacteristicProperties(JSObject _)
    implements JSObject {
  @JS('broadcast')
  external bool get broadcast;
  @JS('read')
  external bool get read;
  @JS('writeWithoutResponse')
  external bool get writeWithoutResponse;
  @JS('write')
  external bool get write;
  @JS('notify')
  external bool get notify;
  @JS('indicate')
  external bool get indicate;
  @JS('authenticatedSignedWrites')
  external bool get authenticatedSignedWrites;
  @JS('reliableWrite')
  external bool get reliableWrite;
  @JS('writableAuxiliaries')
  external bool get writableAuxiliaries;
}

bool _jsHasBluetooth() {
  try {
    return _navigator.bluetooth != null;
  } catch (_) {
    return false;
  }
}

// Simplified web implementation backed by flutter_web_bluetooth.
// Only the surface area required by the app is implemented.

class Guid {
  final List<int> bytes;

  Guid(String input) : bytes = _toBytes(input);

  Guid.fromBytes(this.bytes);

  static List<int> _toBytes(String input) {
    if (input.isEmpty) return List.filled(16, 0);
    final normalized = input.replaceAll('-', '').toLowerCase();

    if (normalized.length == 4) {
      // 16-bit
      final out = List.filled(16, 0);
      out[2] = int.parse(normalized.substring(0, 2), radix: 16);
      out[3] = int.parse(normalized.substring(2, 4), radix: 16);
      // Base UUID: 0000XXXX-0000-1000-8000-00805f9b34fb
      out[4] = 0x00;
      out[5] = 0x00;
      out[6] = 0x10;
      out[7] = 0x00;
      out[8] = 0x80;
      out[9] = 0x00;
      out[10] = 0x00;
      out[11] = 0x80;
      out[12] = 0x5f;
      out[13] = 0x9b;
      out[14] = 0x34;
      out[15] = 0xfb;
      return out;
    }

    final out = <int>[];
    for (var i = 0; i < normalized.length; i += 2) {
      out.add(int.parse(normalized.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  String get str128 {
    if (bytes.length == 2) {
      return '0000${_hexEncode(bytes)}-0000-1000-8000-00805f9b34fb'
          .toLowerCase();
    }
    if (bytes.length == 4) {
      return '${_hexEncode(bytes)}-0000-1000-8000-00805f9b34fb'.toLowerCase();
    }
    if (bytes.length == 16) {
      final one = _hexEncode(bytes.sublist(0, 4));
      final two = _hexEncode(bytes.sublist(4, 6));
      final three = _hexEncode(bytes.sublist(6, 8));
      final four = _hexEncode(bytes.sublist(8, 10));
      final five = _hexEncode(bytes.sublist(10, 16));
      return "$one-$two-$three-$four-$five".toLowerCase();
    }
    return _hexEncode(bytes).toLowerCase();
  }

  String get str => str128;

  @override
  String toString() => str128;

  @override
  bool operator ==(Object other) =>
      (other is Guid && other.str128 == str128) ||
      (other is String &&
          other.replaceAll('-', '').toLowerCase() ==
              str128.replaceAll('-', ''));

  @override
  int get hashCode => str128.replaceAll('-', '').hashCode;

  static String _hexEncode(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

class DeviceIdentifier {
  final String str;
  DeviceIdentifier(this.str);

  @override
  bool operator ==(Object other) =>
      other is DeviceIdentifier && other.str == str;

  @override
  int get hashCode => str.hashCode;

  @override
  String toString() => str;
}

enum BluetoothAdapterState { unknown, off, on }

enum BluetoothConnectionState {
  connected,
  disconnected,
  connecting,
  disconnecting
}

class CharacteristicProperties {
  final bool read;
  final bool write;
  final bool writeWithoutResponse;
  final bool notify;
  final bool indicate;
  final bool authenticatedSignedWrites;
  final bool extendedProperties;
  final bool notifyEncryptionRequired;
  final bool indicateEncryptionRequired;

  const CharacteristicProperties({
    this.read = false,
    this.write = false,
    this.writeWithoutResponse = false,
    this.notify = false,
    this.indicate = false,
    this.authenticatedSignedWrites = false,
    this.extendedProperties = false,
    this.notifyEncryptionRequired = false,
    this.indicateEncryptionRequired = false,
  });
}

class AdvertisementData {
  final String advName;
  final int? txPowerLevel;
  final int? appearance;
  final bool connectable;
  final Map<int, List<int>> manufacturerData;
  final Map<Guid, List<int>> serviceData;
  final List<Guid> serviceUuids;

  const AdvertisementData({
    required this.advName,
    this.txPowerLevel,
    this.appearance,
    this.connectable = true,
    this.manufacturerData = const {},
    this.serviceData = const {},
    this.serviceUuids = const [],
  });
}

class ScanResult {
  final BluetoothDevice device;
  final AdvertisementData advertisementData;
  final int rssi;
  final DateTime timeStamp;

  ScanResult({
    required this.device,
    required this.advertisementData,
    required this.rssi,
    DateTime? timeStamp,
  }) : timeStamp = timeStamp ?? DateTime.now();
}

class BluetoothCharacteristic {
  final Guid uuid;
  final _JSBluetoothRemoteGATTCharacteristic _char;
  final StreamController<List<int>> _notifyController =
      StreamController.broadcast();

  BluetoothCharacteristic._(this._char) : uuid = Guid(_char.uuid) {
    _char.addEventListener(
        'characteristicvaluechanged',
        (JSObject event) {
          final val = _char.value;
          if (val != null) {
            _notifyController.add(val.toDart.buffer.asUint8List());
          }
        }.toJS);
  }

  CharacteristicProperties get properties {
    final p = _char.properties;
    return CharacteristicProperties(
      read: p.read,
      write: p.write,
      writeWithoutResponse: p.writeWithoutResponse,
      notify: p.notify,
      indicate: p.indicate,
      authenticatedSignedWrites: p.authenticatedSignedWrites,
    );
  }

  Stream<List<int>> get onValueReceived => _notifyController.stream;

  Future<void> setNotifyValue(bool notify) async {
    if (notify) {
      final JSPromise<_JSBluetoothRemoteGATTCharacteristic> promise =
          _char.startNotifications();
      await promise.toDart;
    } else {
      final JSPromise<_JSBluetoothRemoteGATTCharacteristic> promise =
          _char.stopNotifications();
      await promise.toDart;
    }
  }

  Future<void> write(List<int> value, {bool withoutResponse = false}) async {
    final data = Uint8List.fromList(value).toJS;
    if (withoutResponse) {
      final JSPromise<JSAny?> promise = _char.writeValueWithoutResponse(data);
      await promise.toDart;
    } else {
      final JSPromise<JSAny?> promise = _char.writeValueWithResponse(data);
      await promise.toDart;
    }
  }
}

class BluetoothService {
  final Guid uuid;
  final BluetoothDevice device;
  final List<BluetoothCharacteristic> characteristics;

  BluetoothService._(
      this.device, _JSBluetoothRemoteGATTService service, this.characteristics)
      : uuid = Guid(service.uuid);
}

class BluetoothDevice {
  final DeviceIdentifier remoteId;
  final _JSBluetoothDevice _device;

  BluetoothDevice._(this._device) : remoteId = DeviceIdentifier(_device.id);

  factory BluetoothDevice.fromId(String remoteId) {
    final device = Ble._knownDevices[remoteId];
    if (device == null) {
      throw StateError("Bluetooth device $remoteId not found in web cache");
    }
    return device;
  }

  String get platformName => _device.name ?? "";
  String get advName => _device.name ?? "";

  Stream<BluetoothConnectionState> get connectionState =>
      Stream.value(BluetoothConnectionState.connected);
  BluetoothConnectionState get prevConnectionState =>
      BluetoothConnectionState.connected;
  bool get isConnected => _device.gatt?.connected ?? false;

  // Web Bluetooth abstracts MTU, defaulting to a safe large size or standard 23.
  // We return 512 to allow higher layer chunking optimization if needed,
  // though browser usually handles fragmentation.
  int get mtuNow => 512;

  Future<void> connect(
      {Duration timeout = const Duration(seconds: 10),
      bool autoConnect = false}) async {
    final gatt = _device.gatt;
    if (gatt == null) throw "GATT not available on device";
    if (gatt.connected) return;

    final JSPromise<_JSBluetoothRemoteGATTServer> promise = gatt.connect();
    await promise.toDart;
  }

  Future<void> disconnect() async {
    _device.gatt?.disconnect();
  }

  Future<void> requestMtu(int mtu) async {
    // Web Bluetooth does not expose MTU negotiation; noop.
  }

  Future<List<BluetoothService>> discoverServices() async {
    final gatt = _device.gatt;
    if (gatt == null) throw "GATT not available";
    if (!gatt.connected) {
      final JSPromise<_JSBluetoothRemoteGATTServer> connectPromise =
          gatt.connect();
      await connectPromise.toDart;
    }
    final JSPromise<JSArray<_JSBluetoothRemoteGATTService>> servicesPromise =
        gatt.getPrimaryServices();
    final servicesJS = await servicesPromise.toDart;
    final servicesList = servicesJS.toDart;
    final result = <BluetoothService>[];
    for (final svc in servicesList) {
      final JSPromise<JSArray<_JSBluetoothRemoteGATTCharacteristic>>
          chrsPromise = svc.getCharacteristics();
      final chrsJS = await chrsPromise.toDart;
      final chrsList = chrsJS.toDart;
      final wrappedChars = <BluetoothCharacteristic>[];
      for (final chr in chrsList) {
        wrappedChars.add(BluetoothCharacteristic._(chr));
      }
      result.add(BluetoothService._(this, svc, wrappedChars));
    }
    return result;
  }
}

class Ble {
  static final _adapterStateController =
      StreamController<BluetoothAdapterState>.broadcast();
  static final _scanResultsController =
      StreamController<List<ScanResult>>.broadcast();
  static final List<ScanResult> _scanResults = [];
  static final Map<String, BluetoothDevice> _knownDevices = {};
  static bool _isScanning = false;
  static BluetoothAdapterState _lastAdapterState =
      BluetoothAdapterState.unknown;
  static final _isScanningController = StreamController<bool>.broadcast();
  static bool _initialized = false;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _initAdapterStateListener();
  }

  static Future<bool> get isSupported async {
    try {
      final bluetooth = _navigator.bluetooth;
      if (bluetooth == null) return false;
      final JSPromise<JSBoolean> promise = bluetooth.getAvailability();
      final available = await promise.toDart;
      return available.toDart;
    } catch (e) {
      print("[FBP-Web] Error checking bluetooth support: $e");
    }
    return false;
  }

  static bool _checkNativeBluetooth() {
    return _jsHasBluetooth();
  }

  static Stream<BluetoothAdapterState> get adapterState async* {
    _ensureInitialized();
    yield _lastAdapterState;
    yield* _adapterStateController.stream;
  }

  static void _initAdapterStateListener() {
    // On Web we don't have a direct adapter state listener easily,
    // but we can poll availability.
    _lastAdapterState = BluetoothAdapterState.on;
    _adapterStateController.add(_lastAdapterState);
  }

  static BluetoothAdapterState get adapterStateNow {
    _ensureInitialized();
    return _lastAdapterState;
  }

  static Stream<List<ScanResult>> get onScanResults =>
      _scanResultsController.stream;
  static Stream<List<ScanResult>> get scanResults =>
      _scanResultsController.stream;

  static Future<void> startScan({
    List<Guid> withServices = const [],
    List<String> withRemoteIds = const [],
    List<String> withNames = const [],
    List<String> withKeywords = const [],
    List<dynamic> withMsd = const [],
    List<dynamic> withServiceData = const [],
    Duration? timeout,
    Duration? removeIfGone,
    bool continuousUpdates = false,
    int continuousDivisor = 1,
    bool oneByOne = false,
    bool androidLegacy = false,
    dynamic androidScanMode,
    bool androidUsesFineLocation = false,
  }) async {
    if (_isScanning) return;
    _isScanning = true;
    _isScanningController.add(true);
    _scanResults.clear();
    _scanResultsController.add(List.of(_scanResults));

    try {
      final serviceIds = withServices.map((g) => g.str128).toList();
      final filters = <Map<String, dynamic>>[];

      for (final name in withNames) {
        filters.add({'name': name});
      }
      for (final keyword in withKeywords) {
        filters.add({'namePrefix': keyword});
      }

      // Only add service-based filters if no name-based filters are provided.
      // We still keep serviceIds in optionalServices below to ensure permissions.
      if (filters.isEmpty) {
        for (final serviceId in serviceIds) {
          filters.add({
            'services': [serviceId]
          });
        }
      }

      final Map<String, dynamic> options = {};
      if (filters.isNotEmpty) {
        options['filters'] = filters;
        options['optionalServices'] = serviceIds;
      } else {
        options['acceptAllDevices'] = true;
        if (serviceIds.isNotEmpty) {
          options['optionalServices'] = serviceIds;
        }
      }

      print(
          "[FBP-Web] Requesting device via JS interop with options: $options");

      final jsOptions = _jsToMap(options);
      final bt = _navigator.bluetooth;
      if (bt == null) throw "navigator.bluetooth not available";

      // Explicitly type the promise to help dart2wasm inference
      final JSPromise<_JSBluetoothDevice?> promise =
          bt.requestDevice(jsOptions);
      final deviceJS = await promise.toDart;
      if (deviceJS == null) throw "No device selected";

      final wrapped = BluetoothDevice._(deviceJS);
      _knownDevices[wrapped.remoteId.str] = wrapped;

      final adv = AdvertisementData(
        advName: deviceJS.name ?? "",
        txPowerLevel: null,
        appearance: null,
        connectable: true,
        manufacturerData: const {},
        serviceData: const {},
        serviceUuids: serviceIds.map((s) => Guid(s)).toList(),
      );

      _scanResults
          .add(ScanResult(device: wrapped, advertisementData: adv, rssi: 0));
      _scanResultsController.add(List.of(_scanResults));
    } catch (e) {
      print("[FBP-Web] requestDevice failed: $e");
      rethrow;
    } finally {
      _isScanning = false;
      _isScanningController.add(false);
    }
  }

  // Helper to convert Dart map to JS object safely for Wasm
  static JSObject _jsToMap(Map<String, dynamic> map) {
    final jsObj = JSObject();
    map.forEach((key, value) {
      if (value is String) {
        jsObj.setProperty(key.toJS, value.toJS);
      } else if (value is bool) {
        jsObj.setProperty(key.toJS, value.toJS);
      } else if (value is List) {
        final jsList = JSArray();
        for (final item in value) {
          if (item is String) {
            jsList.callMethod('push'.toJS, item.toJS);
          } else if (item is Map<String, dynamic>) {
            jsList.callMethod('push'.toJS, _jsToMap(item));
          }
        }
        jsObj.setProperty(key.toJS, jsList);
      } else if (value is Map<String, dynamic>) {
        jsObj.setProperty(key.toJS, _jsToMap(value));
      }
    });
    return jsObj;
  }

  static Future<void> stopScan() async {
    _isScanning = false;
    _isScanningController.add(false);
  }

  static Stream<bool> get isScanning {
    final controller = StreamController<bool>();
    controller.add(_isScanning);
    controller.addStream(_isScanningController.stream);
    return controller.stream;
  }
}
