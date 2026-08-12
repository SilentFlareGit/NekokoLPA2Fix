import 'dart:io' as io;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:zxing_lib/zxing.dart' hide Reader;
import 'package:zxing_lib/common.dart';
import 'package:logging/logging.dart';

final _log = Logger('ZxingDecoder');

Future<String?> decodeQrWithZxing(String path) async {
  try {
    final bytes = await io.File(path).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    final width = image.width;
    final height = image.height;

    // Convert image to Int32List of pixels for zxing_lib
    final Int32List pixels = Int32List(width * height);
    int i = 0;
    for (final pixel in image) {
      // RGBLuminanceSource expects pixels in 0xRRGGBB or 0xAARRGGBB format
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      pixels[i++] = (r << 16) | (g << 8) | b;
    }

    final luminanceSource = RGBLuminanceSource(width, height, pixels);
    final bitmap = BinaryBitmap(HybridBinarizer(luminanceSource));

    final reader = MultiFormatReader();
    final result = reader.decode(bitmap);

    return result.text;
  } catch (e) {
    _log.warning("zxing_lib decode failed: $e");
    return null;
  }
}
