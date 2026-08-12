import 'ccid.dart';
import 'ccid_platform_interface.dart';

/// A stub implementation of [CcidPlatform] for platforms where PCSC is not supported (e.g. Web).
class PcscCcid extends CcidPlatform {
  @override
  Future<List<String>> listReaders() async {
    throw UnimplementedError('PCSC is not supported on this platform');
  }

  @override
  Future<Map<String, String>> listReaderATRs() async {
    throw UnimplementedError('PCSC is not supported on this platform');
  }

  @override
  Future<CcidCard> connect(String reader) async {
    throw UnimplementedError('PCSC is not supported on this platform');
  }

  @override
  Future<String> powerCycle(String reader) async {
    throw UnimplementedError('PCSC is not supported on this platform');
  }

  @override
  Future<String?> transceive(String reader, String capdu) async {
    throw UnimplementedError('PCSC is not supported on this platform');
  }

  @override
  Future<void> disconnect(String reader) async {
    throw UnimplementedError('PCSC is not supported on this platform');
  }
}
