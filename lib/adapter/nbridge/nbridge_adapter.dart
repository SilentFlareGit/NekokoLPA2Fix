import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../euicc_adapter.dart';
import '../../services/nbridge_service.dart';
import '../../settings/app_settings.dart';
import '../../utils/apdu_exception.dart';
import '../../utils/error_codes.dart';
import '../../utils/hex_utils.dart';

class NBridgeAdapter extends BaseAdapter {
  static final Logger _log = Logger('NBridgeAdapter');

  NBridgeAdapter() : super(_log);

  String? _slotId;
  int _nextChannelId = 1;
  final Map<int, _NBridgeConnection> _connections = {};
  final StreamController<EuiccPortState> _stateController =
      StreamController<EuiccPortState>.broadcast();

  List<Reader>? _lastReaders;
  DateTime? _lastListTime;

  @override
  Stream<EuiccPortState> get stateStream => _stateController.stream;

  @override
  bool get requiresRefresh => true;

  @override
  String? get lastAtr => null;

  @override
  bool get supportsRawApdu => true;

  Future<bool> isAvailable({bool forceRefresh = false}) {
    return NBridgeService.isAvailable(forceRefresh: forceRefresh);
  }

  @override
  Future<List<Reader>> listReaders({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastReaders != null &&
        _lastListTime != null &&
        now.difference(_lastListTime!) < const Duration(seconds: 2)) {
      return _lastReaders!;
    }

    if (!await isAvailable(forceRefresh: force)) {
      _lastReaders = const <Reader>[];
      _lastListTime = now;
      return _lastReaders!;
    }

    final slots = await NBridgeService.listSlots();
    final readers = slots.map((slot) {
      final slotId = slot['id'] as String? ?? '';

      String displayName = slot['displayName'] as String? ?? slotId;

      return Reader(id: slotId, name: displayName, source: this, context: slot);
    }).toList();

    _lastReaders = readers;
    _lastListTime = now;
    return readers;
  }

  @override
  Future<void> connect(Reader reader) async {
    return runExclusive(() async {
      await disconnect();
      _slotId = reader.id;
      updateConnectedReader(reader);
      _stateController.add(EuiccPortState.open);
    });
  }

  @override
  Future<void> disconnect() async {
    return runExclusive(() async {
      await _closeAllChannels();
      _slotId = null;
      updateConnectedReader(null);
      _stateController.add(EuiccPortState.closed);
    });
  }

  @override
  Future<void> reconnect() async {
    return runExclusive(() async {
      final reader = connectedReader;
      await disconnect();
      if (reader != null) {
        await connect(reader);
      }
    });
  }

  @override
  Future<void> cleanupChannels() => _closeAllChannels();

  @override
  Future<Uint8List> sendRawApdu(Uint8List apdu) async {
    final slotId = _slotId;
    if (slotId == null) {
      throw AppException(AppErrorCode.ERROR_UNKNOWN, message: 'Not connected');
    }

    final responseHex = await NBridgeService.transmitBasic(
      slotId: slotId,
      apdu: HexUtils.bytesToHex(apdu),
    );
    return HexUtils.hexToBytes(responseHex);
  }

  @override
  Future<Channel> openChannel({List<String>? aids}) async {
    return runExclusive(() async {
      final slotId = _slotId;
      if (slotId == null) {
        throw AppException(
          AppErrorCode.ERROR_UNKNOWN,
          message: 'Not connected',
        );
      }

      final targetAids = (aids == null || aids.isEmpty)
          ? AppSettings().aids
          : aids;
      if (targetAids.isEmpty) {
        throw AppException(
          AppErrorCode.ERROR_CHANNEL_OPEN_FAILED,
          message: 'No AIDs configured for NBridge channel open',
        );
      }

      if (AppSettings().ensureSingleChannel) {
        await _closeAllChannels();
      }

      final result = await NBridgeService.connectLogicalChannel(
        slotId: slotId,
        aids: targetAids,
      );

      final localChannelId = _allocateLocalChannelId();
      final connectionId = result['connectionId'] as String?;
      final selectedAid = result['selectedAid'] as String?;
      final providerChannelNumber = result['channelNumber'] as int?;
      if (connectionId == null || selectedAid == null) {
        throw AppException(
          AppErrorCode.ERROR_CHANNEL_OPEN_FAILED,
          message: 'NBridge returned an incomplete logical channel response',
        );
      }

      final exposedChannelNumber =
          providerChannelNumber != null && providerChannelNumber > 0
          ? providerChannelNumber
          : localChannelId;

      if (_connections.containsKey(exposedChannelNumber)) {
        throw CardBusyException(
          'NBridge channel number collision for $exposedChannelNumber',
        );
      }

      _connections[exposedChannelNumber] = _NBridgeConnection(
        connectionId: connectionId,
        slotId: slotId,
        aid: selectedAid,
      );
      return _NBridgeChannel(this, exposedChannelNumber, selectedAid);
    });
  }

  Future<Uint8List> transmitLogical(int channelNumber, Uint8List apdu) async {
    final connection = _connections[channelNumber];
    if (connection == null) {
      throw AppException(
        AppErrorCode.ERROR_CHANNEL_OPEN_FAILED,
        message: 'Unknown NBridge logical channel',
      );
    }

    final responseHex = await NBridgeService.transmitLogical(
      connectionId: connection.connectionId,
      apdu: HexUtils.bytesToHex(apdu),
    );
    return HexUtils.hexToBytes(responseHex);
  }

  Future<void> closeLogicalChannel(int channelNumber) async {
    final connection = _connections.remove(channelNumber);
    if (connection == null) {
      return;
    }
    await NBridgeService.closeLogicalChannel(
      connectionId: connection.connectionId,
    );
  }

  Future<void> _closeAllChannels() async {
    final channelIds = _connections.keys.toList();
    for (final channelId in channelIds) {
      try {
        await closeLogicalChannel(channelId);
      } catch (e) {
        _log.warning('Failed to close NBridge channel $channelId: $e');
      }
    }
  }

  int _allocateLocalChannelId() {
    for (var attempts = 0; attempts < 19; attempts++) {
      final candidate = _nextChannelId;
      _nextChannelId = (_nextChannelId % 19) + 1;
      if (!_connections.containsKey(candidate)) {
        return candidate;
      }
    }
    throw CardBusyException('All local NBridge channel slots are in use');
  }
}

class _NBridgeConnection {
  final String connectionId;
  final String slotId;
  final String aid;

  const _NBridgeConnection({
    required this.connectionId,
    required this.slotId,
    required this.aid,
  });
}

class _NBridgeChannel extends BaseChannel {
  final NBridgeAdapter _adapter;
  final String _aid;

  _NBridgeChannel(this._adapter, int localChannelNumber, this._aid)
    : super(_adapter, localChannelNumber);

  @override
  String? get aid => _aid;

  @override
  Future<void> close() async {
    await _adapter.closeLogicalChannel(channelNumber);
  }

  @override
  Future<Uint8List> sendRawApdu(Uint8List apdu) async {
    return _adapter.transmitLogical(channelNumber, apdu);
  }
}
