import 'package:flutter/foundation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ccid.dart';
import 'ccid_method_channel.dart';
import 'ccid_pcsc_stub.dart' if (dart.library.io) 'ccid_pcsc.dart';
import 'ccid_web_stub.dart' if (dart.library.js_interop) 'ccid_web.dart';

abstract class CcidPlatform extends PlatformInterface {
  /// Constructs a CcidPlatform.
  CcidPlatform() : super(token: _token);

  static final Object _token = Object();

  static final CcidPlatform _methodChannelInstance = MethodChannelCcid();
  static final CcidPlatform _webInstance = WebCcid();

  static final CcidPlatform _pcscInstance = PcscCcid();

  /// The default instance of [CcidPlatform] to use.
  ///
  /// Defaults to [MethodChannelCcid].
  static CcidPlatform get instance {
    if (kIsWeb) {
      return _webInstance;
    } else if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return _methodChannelInstance;
    } else {
      return _pcscInstance;
    }
  }

  Future<List<String>> listReaders() {
    throw UnimplementedError('poll() has not been implemented.');
  }

  Future<Map<String, String>> listReaderATRs() {
    throw UnimplementedError('poll() has not been implemented.');
  }

  Future<String?> transceive(String reader, String capdu) {
    throw UnimplementedError('transceive() has not been implemented.');
  }

  Future<String> powerCycle(String reader) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  Future<CcidCard> connect(String reader) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  Future<void> disconnect(String reader) {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  Future<void> requestPermission(String reader) {
    // Default implementation does nothing (for non-Android platforms)
    return Future.value();
  }

  Stream<dynamic> get events => const Stream.empty();
}
