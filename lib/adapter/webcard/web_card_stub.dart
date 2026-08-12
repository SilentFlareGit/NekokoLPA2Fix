import 'dart:async';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import '../euicc_adapter.dart';

class WebCardAdapter extends BaseAdapter {
  WebCardAdapter() : super(Logger('WebCardAdapter'));

  @override
  Stream<EuiccPortState> get stateStream => const Stream.empty();

  @override
  bool get requiresRefresh => false;

  @override
  String? get lastAtr => null;

  @override
  Future<List<Reader>> listReaders({bool force = false}) async => [];

  @override
  Future<void> connect(Reader reader) async => throw UnimplementedError();

  @override
  Future<void> disconnect() async {}

  @override
  Future<Channel> openChannel({List<String>? aids}) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> sendRawApdu(Uint8List apdu) async =>
      throw UnimplementedError();
}
