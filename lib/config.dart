import 'utils/platform_adapter.dart';

bool get kIsPrivileged =>
    const bool.fromEnvironment('PRIVILEGED_BUILD', defaultValue: false) &&
    PlatformX.isAndroid;

class AppConfig {
  static String appName = 'NekokoLPA 2';
}
