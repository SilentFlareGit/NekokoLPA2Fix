import 'dart:typed_data';

// Stub for dart:io File class on web
class File {
  final String path;
  File(this.path);
  Future<void> writeAsBytes(List<int> bytes) async {}
  Future<bool> exists() async => false;
  Future<Uint8List> readAsBytes() async => Uint8List(0);
}

class Platform {
  static String get operatingSystem => 'web';
}
