import 'package:flutter/foundation.dart';

class PlatformX {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static String get operatingSystem => 'web';

  static bool get isWeb => true;

  // High level groups
  static bool get isMobile => isMobileWeb;
  static bool get isDesktop => !isMobileWeb;

  static bool get isMobileWeb =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  // Capability checks
  static bool get supportsBle => true; // Web Bluetooth support in some browsers

  // IO specific helpers (stubs for web)
  static String? getEnv(String name) => null;
  static void ensureDirectory(String path) {
    // No-op on web
  }
}
