import 'package:flutter/services.dart';

import '../utils/error_codes.dart';

class NBridgeService {
  NBridgeService._();

  static const String authority = 'ee.nekoko.nbridge.provider';
  static const MethodChannel _channel = MethodChannel(
    'ee.nekoko.nbridge_plugin',
  );

  static bool? _availabilityCache;
  static bool? _rootedCache;

  static Future<bool> isAvailable({bool forceRefresh = false}) async {
    if (!forceRefresh && _availabilityCache != null) {
      return _availabilityCache!;
    }

    final available =
        await _channel.invokeMethod<bool>('isAvailable', <String, dynamic>{
          'authority': authority,
        }) ??
        false;
    _availabilityCache = available;
    return available;
  }

  static Future<bool> isRooted({bool forceRefresh = false}) async {
    if (!forceRefresh && _rootedCache != null) {
      return _rootedCache!;
    }

    final rooted = await _channel.invokeMethod<bool>('isRooted') ?? false;
    _rootedCache = rooted;
    return rooted;
  }

  static Future<List<Map<String, dynamic>>> listSlots() async {
    final result = await _invokeMapMethod('listSlots');
    final slots = (result['slots'] as List<dynamic>? ?? const <dynamic>[]);
    return slots
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (slot) => Map<String, dynamic>.from(
            slot.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  static Future<Map<String, dynamic>> connectLogicalChannel({
    required String slotId,
    required List<String> aids,
  }) {
    return _invokeMapMethod('connectLogicalChannel', <String, dynamic>{
      'slotId': slotId,
      'aids': aids,
    });
  }

  static Future<String> transmitLogical({
    required String connectionId,
    required String apdu,
  }) async {
    final result = await _invokeMapMethod('transmitLogical', <String, dynamic>{
      'connectionId': connectionId,
      'apdu': apdu,
    });
    return result['responseApdu'] as String;
  }

  static Future<String> transmitBasic({
    required String slotId,
    required String apdu,
  }) async {
    final result = await _invokeMapMethod('transmitBasic', <String, dynamic>{
      'slotId': slotId,
      'apdu': apdu,
    });
    return result['responseApdu'] as String;
  }

  static Future<void> closeLogicalChannel({
    required String connectionId,
  }) async {
    await _invokeMapMethod('closeLogicalChannel', <String, dynamic>{
      'connectionId': connectionId,
    });
  }

  static Future<Map<String, dynamic>> _invokeMapMethod(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    final raw = await _channel.invokeMethod<dynamic>(method, arguments);
    final result = Map<String, dynamic>.from(raw as Map);
    final ok = result['ok'] == true;
    if (!ok) {
      final errorCode = (result['errorCode'] as String?) ?? 'ERROR';
      final errorMessage =
          result['errorMessage'] as String? ?? 'Unknown NBridge error';
      final lower = errorMessage.toLowerCase();
      if (lower.contains('invocationtargetexception')) {
        throw AppException(
          AppErrorCode.ERROR_CHANNEL_OPEN_FAILED,
          message: 'NBridge $method failed transiently: $errorMessage',
          originalError: result,
        );
      }
      throw PlatformException(
        code: errorCode,
        message: errorMessage,
        details: result,
      );
    }
    return result;
  }
}
