import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformX {
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static String get operatingSystem => Platform.operatingSystem;

  static bool get isWeb => kIsWeb;

  // High level groups
  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => isMacOS || isWindows || isLinux;

  static bool get isMobileWeb {
    if (!kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  // Capability checks
  static bool get supportsBle => isAndroid || isIOS || isMacOS || isWeb;

  // IO specific helpers
  static String? getEnv(String name) => Platform.environment[name];

  static void ensureDirectory(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }
}
