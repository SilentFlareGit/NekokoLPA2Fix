import 'ccid_platform_interface.dart';

class Ccid {
  Future<List<String>> listReaders() {
    return CcidPlatform.instance.listReaders();
  }

  Future<Map<String, String>> listReaderATRs() {
    return CcidPlatform.instance.listReaderATRs();
  }

  Future<CcidCard> connect(String reader) {
    return CcidPlatform.instance.connect(reader);
  }

  Future<String> powerCycle(String reader) {
    return CcidPlatform.instance.powerCycle(reader);
  }

  Future<void> disconnect(String reader) {
    return CcidPlatform.instance.disconnect(reader);
  }

  Future<void> requestPermission(String reader) {
    return CcidPlatform.instance.requestPermission(reader);
  }

  Stream<dynamic> get events => CcidPlatform.instance.events;
}

class CcidCard {
  final String reader;
  final String atr;

  CcidCard(this.reader, this.atr);

  Future<String?> transceive(String capdu) {
    return CcidPlatform.instance.transceive(reader, capdu);
  }

  Future<void> disconnect() {
    return CcidPlatform.instance.disconnect(reader);
  }

  Future<String> powerCycle() {
    return CcidPlatform.instance.powerCycle(reader);
  }
}
