import 'dart:convert';
import 'package:logging/logging.dart';
import 'database_service.dart';

/// In-memory cache for card status to avoid repeated database queries
class CardStatusCache {
  static final Logger _log = Logger('CardStatusCache');
  static final CardStatusCache _instance = CardStatusCache._internal();

  factory CardStatusCache() => _instance;

  CardStatusCache._internal();

  final Map<String, Map<String, dynamic>?> _cache = {};

  /// Get card status from cache or database
  Future<Map<String, dynamic>?> getCardStatus(String iccid) async {
    // Check cache first
    if (_cache.containsKey(iccid)) {
      return _cache[iccid];
    }

    // Fetch from database
    try {
      final status = await DatabaseService().getCardStatus(iccid);
      if (status != null && status['data'] != null) {
        // Validation: Check expiry
        if (status['expiry'] != null) {
          final expiry = status['expiry'] as int;
          if (DateTime.now().millisecondsSinceEpoch > expiry) {
            _log.info('Cached status for $iccid expired');
            // Proceed to return null so it can be refreshed
            _cache[iccid] = null;
            return null;
          }
        }

        final data = jsonDecode(status['data'] as String);
        _cache[iccid] = data;
        return data;
      }
    } catch (e) {
      _log.warning('Failed to get card status for $iccid: $e');
    }

    _cache[iccid] = null;
    return null;
  }

  /// Get synchronously from cache only (returns null if not cached)
  Map<String, dynamic>? getCardStatusSync(String iccid) {
    return _cache[iccid];
  }

  /// Preload card statuses for multiple ICCIDs
  Future<void> preloadCardStatuses(List<String> iccids) async {
    final futures = <Future>[];
    for (final iccid in iccids) {
      if (!_cache.containsKey(iccid)) {
        futures.add(getCardStatus(iccid));
      }
    }
    await Future.wait(futures);
  }

  /// Directly update the cache for a specific ICCID
  void updateCache(String iccid, Map<String, dynamic>? data) {
    _cache[iccid] = data;
  }

  /// Clear cache for a specific ICCID
  void invalidate(String iccid) {
    _cache.remove(iccid);
  }

  /// Clear entire cache
  void clear() {
    _cache.clear();
  }
}
