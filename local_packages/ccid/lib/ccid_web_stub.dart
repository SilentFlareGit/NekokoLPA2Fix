import 'ccid.dart';
import 'ccid_platform_interface.dart';

/// A stub for CcidPlatform when not using Web.
/// This prevents dart:js_interop imports on non-Web builds.
class WebCcid extends CcidPlatform {
  @override
  Future<List<String>> listReaders() async => [];

  @override
  Future<Map<String, String>> listReaderATRs() async => {};

  @override
  Future<CcidCard> connect(String reader) async => throw UnimplementedError();

  @override
  Future<String> powerCycle(String reader) async => "";

  @override
  Future<String?> transceive(String reader, String capdu) async => null;

  @override
  Future<void> disconnect(String reader) async {}
}
