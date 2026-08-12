import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../euicc_adapter.dart';
import '../../utils/hex_utils.dart';
import '../../utils/error_codes.dart';
import '../../utils/crypto_utils.dart';
import '../../settings/app_settings.dart';

class RemoCardInvalidPasswordException extends RemoCardException {
  final String? url;
  RemoCardInvalidPasswordException(super.message, {super.errorCode, this.url});

  @override
  String toString() =>
      'RemoCardInvalidPasswordException: $message${errorCode != null ? ' ($errorCode)' : ''}';
}

class RemoCardException implements Exception {
  final String message;
  final String? errorCode;

  RemoCardException(this.message, {this.errorCode});

  @override
  String toString() =>
      'RemoCardException: $message${errorCode != null ? ' (code: $errorCode)' : ''}';
}

class RemoCardConnectionException extends RemoCardException {
  RemoCardConnectionException(super.message, {super.errorCode});

  @override
  String toString() => 'RemoCardConnectionException: $message';
}

class RemoCardAdapter extends BaseAdapter {
  static final Logger _log = Logger('RemoCardAdapter');

  String? _baseUrl;
  String? _internalReaderName; // The name used in JSON requests, e.g. "Slot 1"
  String? _lastAtr;
  String? _password;
  String? get baseUrl => _baseUrl;
  String? get internalReaderName => _internalReaderName;

  final StreamController<EuiccPortState> _stateController =
      StreamController<EuiccPortState>.broadcast();

  RemoCardAdapter(this._baseUrl) : super(_log);

  @override
  Stream<EuiccPortState> get stateStream => _stateController.stream;

  @override
  bool get requiresRefresh => true;

  @override
  String? get lastAtr => _lastAtr;

  @override
  Future<List<Reader>> listReaders({bool force = false}) async {
    final cleanUrl = _getCleanUrlAndSetPassword();
    try {
      final response = await _get('/listSlots');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> slots = data['slots'] ?? [];
        return slots.map((slot) {
          final name = slot['name'] as String;
          final id = "remocard:$_baseUrl|$name";
          final eid = slot['eid'] as String?; // Extract EID if available
          return Reader(
            id: id,
            name: "$_baseUrl/$name",
            source: this,
            context: name,
            eid: eid, // Attach EID to reader
          );
        }).toList();
      } else {
        _throwIfError(response);
        return [];
      }
    } catch (e) {
      log.warning('Failed to list RemoCard readers at $cleanUrl: $e');
      if (e is AppException) rethrow;
      throw AppException(
        AppErrorCode.ERROR_REMOTE_CONNECTION_FAILED,
        originalError: e,
      );
    }
  }

  Future<http.Response> _get(String path) async {
    final cleanUrl = _getCleanUrlAndSetPassword();
    final url = cleanUrl.endsWith('/')
        ? '$cleanUrl${path.substring(1)}'
        : '$cleanUrl$path';

    final Map<String, String> headers = {
      'X-Remocard-Version': '2',
      'Content-Type': 'application/json',
    };
    if (_password != null && _password!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_password';
    }

    try {
      http.Response response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));

      // Decrypt response if needed
      if (_password != null &&
          _password!.isNotEmpty &&
          response.body.isNotEmpty) {
        try {
          // V2 Protocol: Encrypted data is wrapped in JSON {"data": "..."}
          final jsonWrapper = jsonDecode(response.body);
          if (jsonWrapper is Map && jsonWrapper.containsKey('data')) {
            final encryptedData = jsonWrapper['data'];
            final decrypted = CryptoUtils.decryptAES(encryptedData, _password!);
            _log.info(
              "Successfully decrypted RemoCard V2 response (length: ${decrypted.length})",
            );
            response = http.Response(
              decrypted,
              response.statusCode,
              headers: response.headers,
              isRedirect: response.isRedirect,
              persistentConnection: response.persistentConnection,
              reasonPhrase: response.reasonPhrase,
              request: response.request,
            );
          }
        } catch (e) {
          // Only warn if we really expected encryption (i.e. we have a password and the body looks like JSON)
          // If parsing fails, it might be a plain text error or non-wrapped V1-style (though we are moving to V2)
          // or it might be that the server is NOT using encryption despite us having a password configured.
          // However, if we sent a password, we likely expect encryption if the server is configured for it.
          // For V2, we assume strict wrapping if encrypted.
          // We will log a warning but proceed with original body if decryption flow failed,
          // in case it wasn't actually encrypted.
          _log.warning("Failed to process potential encrypted response: $e");
        }
      }

      _throwIfError(response);
      return response;
    } catch (e) {
      if (e is RemoCardException || e is AppException) rethrow;
      if (e is TimeoutException) {
        throw AppException(AppErrorCode.ERROR_REMOTE_TIMEOUT, originalError: e);
      }
      throw AppException(
        AppErrorCode.ERROR_REMOTE_CONNECTION_FAILED,
        message: 'Failed to connect to $url',
        originalError: e,
      );
    }
  }

  String _getCleanUrlAndSetPassword() {
    if (_baseUrl == null) throw Exception("Base URL not set");

    // Support URLs like "http://password@host:port" or "http://host:port"
    try {
      final uri = Uri.parse(_baseUrl!);
      if (uri.userInfo.isNotEmpty) {
        if (uri.userInfo.contains(':')) {
          // Handle ":password" or "user:password"
          final parts = uri.userInfo.split(':');
          _password = parts
              .sublist(1)
              .join(':'); // Everything after first colon
        } else {
          _password = uri.userInfo;
        }
        final cleanUri = uri.replace(userInfo: '');
        return cleanUri.toString();
      }
    } catch (_) {}

    _password = AppSettings().remoCardPassword;
    return _baseUrl!;
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final cleanUrl = _getCleanUrlAndSetPassword();
    final url = cleanUrl.endsWith('/')
        ? '$cleanUrl${path.substring(1)}'
        : '$cleanUrl$path';

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-Remocard-Version': '2',
    };
    if (_password != null && _password!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_password';
    }

    String jsonBody = jsonEncode(body);

    // Encrypt if password set
    if (_password != null && _password!.isNotEmpty) {
      final key = CryptoUtils.keyFromPassword(_password!);
      final encrypted = CryptoUtils.encryptAESWithKey(jsonBody, key);
      jsonBody = jsonEncode({'data': encrypted});
    }

    try {
      http.Response response = await http
          .post(Uri.parse(url), headers: headers, body: jsonBody)
          .timeout(const Duration(seconds: 15));

      // Decrypt response if needed
      if (_password != null &&
          _password!.isNotEmpty &&
          response.body.isNotEmpty) {
        try {
          // V2 Protocol: Encrypted data is wrapped in JSON {"data": "..."}
          final jsonWrapper = jsonDecode(response.body);
          if (jsonWrapper is Map && jsonWrapper.containsKey('data')) {
            final encryptedData = jsonWrapper['data'];
            final decrypted = CryptoUtils.decryptAES(encryptedData, _password!);
            _log.info(
              "Successfully decrypted RemoCard V2 POST response (length: ${decrypted.length})",
            );
            response = http.Response(
              decrypted,
              response.statusCode,
              headers: response.headers,
              isRedirect: response.isRedirect,
              persistentConnection: response.persistentConnection,
              reasonPhrase: response.reasonPhrase,
              request: response.request,
            );
          }
        } catch (e) {
          // Only warn if we really expected encryption
          _log.warning(
            "Failed to process potential encrypted POST response: $e",
          );
        }
      }

      _throwIfError(response);
      return response;
    } catch (e) {
      if (e is RemoCardException || e is AppException) rethrow;
      if (e is TimeoutException) {
        throw AppException(AppErrorCode.ERROR_REMOTE_TIMEOUT, originalError: e);
      }
      throw AppException(
        AppErrorCode.ERROR_REMOTE_CONNECTION_FAILED,
        message: 'Failed to connect to $url',
        originalError: e,
      );
    }
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode == 200) return;

    try {
      final data = jsonDecode(response.body);
      final errorMsg = data['error'] ?? response.body;

      if (errorMsg.toString().toLowerCase().contains('invalid password')) {
        throw AppException(
          AppErrorCode.ERROR_REMOTE_AUTH_FAILED,
          message: errorMsg.toString(),
          originalError: response,
        );
      }

      throw AppException(
        AppErrorCode.ERROR_TRANSACTION_FAILED,
        message: errorMsg.toString(),
        originalError: response,
      );
    } on RemoCardException {
      rethrow;
    } catch (e) {
      throw RemoCardException(
        'Server returned error ${response.statusCode}: ${response.body}',
      );
    }
  }

  @override
  Future<void> connect(Reader reader) async {
    return await runExclusive(() async {
      updateConnectedReader(reader);
      final readerName = reader.id;

      // If context is available, use it directly
      if (reader.context != null && reader.context is String) {
        _internalReaderName = reader.context;
      } else {
        // Fallback: Parse ID
        if (readerName.startsWith('remocard:')) {
          final parts = readerName.replaceFirst('remocard:', '').split('|');
          if (parts.isNotEmpty) {
            _baseUrl = parts[0];
            _internalReaderName = parts.last;
            _getCleanUrlAndSetPassword();
          }
        } else {
          // Assume simple connection to existing baseUrl
          _internalReaderName = readerName;
        }
      }

      final cleanUrl = _getCleanUrlAndSetPassword();

      log.info(
        'Connected to RemoCard reader: $_internalReaderName at $cleanUrl',
      );
      _stateController.add(EuiccPortState.open);
      _lastAtr = "3B8F01801F42454C45323420312E30332E30311D";
    });
  }

  @override
  Future<void> disconnect() async {
    return await runExclusive(() async {
      _internalReaderName = null;
      updateConnectedReader(null);
      _password = null;
      _stateController.add(EuiccPortState.closed);
    });
  }

  @override
  Future<Uint8List> sendRawApdu(Uint8List apdu) async {
    if (_internalReaderName == null) {
      throw AppException(
        AppErrorCode.ERROR_REMOTE_CONNECTION_FAILED,
        message: 'Not connected',
      );
    }

    final response = await _post('/sendRawApdu', {
      'reader': _internalReaderName,
      'apdu': HexUtils.bytesToHex(apdu),
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return HexUtils.hexToBytes(data['response']);
    } else {
      // _throwIfError already called in _post
      throw Exception("RemoCard error: ${response.body}");
    }
  }

  @override
  Future<void> cleanupChannels() async {
    if (_internalReaderName == null) return;
    log.info('Ensuring single channel: cleaning up remote channels...');
    // try {
    //   await super.cleanupChannels();
    // } catch (e2) {
    //   log.warning('Fallback cleanup failed: $e2');
    // }
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<Channel> openChannel({List<String>? aids}) async {
    return await runExclusive(() async {
      await cleanupChannels();

      String? matchedAid;
      if (aids != null && aids.isNotEmpty) {
        log.info({'reader': internalReaderName, 'aids': aids}.toString());
        final response = await _post('/openChannel', {
          'reader': internalReaderName,
          'aids': aids,
        });

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          log.info(data.toString());
          if (data['success'] == true) {
            matchedAid = data['aid'];
          } else {
            throw RemoCardException(
              "Failed to open channel for any of the provided AIDs",
            );
          }
        } else {
          _throwIfError(response);
          throw RemoCardException("Failed to open channel: ${response.body}");
        }
      }

      return _RemoChannel(this, matchedAid);
    });
  }
}

class _RemoChannel extends BaseChannel {
  final RemoCardAdapter _adapter;
  String? _aidHex;

  _RemoChannel(this._adapter, [this._aidHex]) : super(_adapter, 0);

  @override
  String? get aid => _aidHex;

  @override
  Future<void> close() async {
    if (_aidHex != null) {
      try {
        await _adapter._post('/closeChannel', {
          'reader': _adapter.internalReaderName,
          'aids': [_aidHex],
        });
      } catch (e) {
        RemoCardAdapter._log.warning("Failed to close remote channel: $e");
      }
    }
  }

  @override
  Future<Uint8List> sendRawApdu(Uint8List apdu) async {
    if (_aidHex == null) throw Exception('No AID selected');

    final response = await _adapter._post('/sendApdu', {
      'reader': _adapter.internalReaderName,
      'aid': _aidHex,
      'apdu': HexUtils.bytesToHex(apdu),
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return HexUtils.hexToBytes(data['response']);
    } else {
      // _throwIfError already called in _post
      throw Exception("RemoCard error: ${response.body}");
    }
  }

  @override
  Future<Uint8List> transmit(
    int cla,
    int ins,
    int p1,
    int p2, [
    Uint8List? data,
    int? le,
  ]) async {
    // If this is a blank channel and we see a SELECT AID, open it remotely
    if (_aidHex == null && ins == 0xA4 && p1 == 0x04 && data != null) {
      final targetAid = HexUtils.bytesToHex(data);
      final response = await _adapter._post('/openChannel', {
        'reader': _adapter.internalReaderName,
        'aids': [targetAid],
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _aidHex = targetAid;
          return Uint8List.fromList([0x90, 0x00]);
        } else {
          throw RemoCardException(
            "Server failed to open channel for AID $targetAid",
          );
        }
      } else {
        _adapter._throwIfError(response);
        throw RemoCardException(
          "Failed to open remote channel: ${response.body}",
        );
      }
    }
    return await super.transmit(cla, ins, p1, p2, data, le);
  }
}
