import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import '../settings/app_settings.dart';

class ConnectivityService {
  static final Logger _log = Logger('ConnectivityService');
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  Timer? _timer;
  bool _isChecking = false;

  void startPeriodicCheck() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      checkConnectivity();
    });
    checkConnectivity();
  }

  void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
  }

  Future<bool> checkConnectivity() async {
    if (_isChecking) return AppSettings().isOnline;
    _isChecking = true;

    try {
      final urls = [
        'https://cp.cloudflare.com/generate_204',
        'http://connectivity-check.ubuntu.com/',
      ];

      for (final url in urls) {
        try {
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 5));
          if (response.statusCode == 204 ||
              (url.contains('ubuntu') && response.statusCode == 200)) {
            _updateOnlineStatus(true);
            return true;
          }
        } catch (e) {
          _log.fine("Connectivity check failed for $url: $e");
        }
      }

      _updateOnlineStatus(false);
      return false;
    } finally {
      _isChecking = false;
    }
  }

  void _updateOnlineStatus(bool online) {
    if (AppSettings().isOnline != online) {
      _log.info(
        "Connectivity status changed: ${online ? 'ONLINE' : 'OFFLINE'}",
      );
      AppSettings().setOnline(online);
    }
  }
}
