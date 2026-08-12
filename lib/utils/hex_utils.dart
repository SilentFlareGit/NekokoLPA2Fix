import 'dart:typed_data';

class HexUtils {
  static String bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List hexToBytes(String hex) {
    hex = hex.replaceAll(' ', '');
    // Check for odd length
    if (hex.length % 2 != 0) {
      hex = '0$hex';
    }
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  static String swapNibbles(String input) {
    final buffer = StringBuffer();
    // Ensure even length for safe swapping
    if (input.length % 2 != 0) input = 'F$input';

    for (int i = 0; i < input.length; i += 2) {
      if (i + 1 < input.length) {
        buffer.write(input[i + 1]);
        buffer.write(input[i]);
      } else {
        buffer.write(input[i]);
      }
    }
    return buffer.toString();
  }
}
