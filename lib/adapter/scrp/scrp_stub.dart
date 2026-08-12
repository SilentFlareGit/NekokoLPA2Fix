import 'dart:async';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import '../euicc_adapter.dart';

class ScrpAdapter extends BaseAdapter {
  ScrpAdapter() : super(Logger('ScrpAdapter'));

  @override
  bool get requiresRefresh => false;

  @override
  Stream<EuiccPortState> get stateStream => const Stream.empty();

  @override
  String? get lastAtr => null;

  @override
  Future<List<Reader>> listReaders({bool force = false}) async => [];

  @override
  Future<void> connect(Reader reader) async => throw UnimplementedError();

  @override
  Future<Channel> openChannel({List<String>? aids}) async {
    throw UnimplementedError();
  }

  Future<Reader?> scanScrp() async {
    log.info("scanScrp() called - triggering noop");
    return null;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> reconnect() async {}

  @override
  Future<Uint8List> sendRawApdu(Uint8List apdu) async =>
      throw UnimplementedError();
}
