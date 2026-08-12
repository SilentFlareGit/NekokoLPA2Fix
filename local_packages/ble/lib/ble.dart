export 'src/ble_web.dart'
    if (dart.library.io) 'ble_native.dart'
    if (dart.library.html) 'src/ble_web.dart';
