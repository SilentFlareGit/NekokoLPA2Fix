import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import '../settings/app_settings.dart';
import 'database_service.dart';
import 'operator_icon_source.dart';

class OperatorIconService {
  static final Logger _log = Logger('OperatorIconService');
  static final OperatorIconService _instance = OperatorIconService._internal();
  factory OperatorIconService() => _instance;
  OperatorIconService._internal();

  final Map<String, String> _memoryCache = {};
  final Map<String, Future<String?>> _pendingLoads = {};
  final Map<String, Uint8List> _decodedBytesCache = {};
  Timer? _notifyTimer;
  // Notifier to trigger UI updates when icons are downloaded
  final ValueNotifier<int> iconUpdateNotifier = ValueNotifier<int>(0);

  String? getIconFromMemory({
    required String mcc,
    required String mnc,
    String? gid1,
    String? gid2,
  }) {
    final cacheKey = _getCacheKey(mcc, mnc, gid1, gid2);
    return _memoryCache[cacheKey];
  }

  Uint8List? getDecodedIconBytesFromMemory({
    required String mcc,
    required String mnc,
    String? gid1,
    String? gid2,
  }) {
    final cacheKey = _getCacheKey(mcc, mnc, gid1, gid2);
    final encoded = _memoryCache[cacheKey];
    if (encoded == null || encoded.isEmpty) return null;
    return _decodeAndCacheBytes(cacheKey, encoded);
  }

  Future<String?> getIcon({
    required String mcc,
    required String mnc,
    String? gid1,
    String? gid2,
  }) async {
    final cacheKey = _getCacheKey(mcc, mnc, gid1, gid2);

    // Check memory cache first
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    final pending = _pendingLoads[cacheKey];
    if (pending != null) return pending;

    final load = _loadIcon(cacheKey, mcc, mnc, gid1, gid2);
    _pendingLoads[cacheKey] = load;
    return load;
  }

  Future<String?> _loadIcon(
    String cacheKey,
    String mcc,
    String mnc,
    String? gid1,
    String? gid2,
  ) async {
    try {
      final dbImage = await DatabaseService().getOperatorIcon(
        mcc: mcc,
        mnc: mnc,
        gid1: gid1,
        gid2: gid2,
      );
      if (dbImage != null) {
        _memoryCache[cacheKey] = dbImage;
        return dbImage;
      }
      return null;
    } finally {
      _pendingLoads.remove(cacheKey);
    }
  }

  String _getCacheKey(String mcc, String mnc, String? gid1, String? gid2) {
    // Normalize nulls/empties for internal cache key consistency with DB
    return "$mcc-$mnc-${gid1 ?? ""}-${gid2 ?? ""}";
  }

  Future<void> fetchMissingIcons(List<Map<String, dynamic>> operators) async {
    if (!AppSettings().useNekokoIcons) {
      return;
    }

    final List<Map<String, dynamic>> missing = [];
    for (final op in operators) {
      final mcc = op['mcc']?.toString();
      final mnc = op['mnc']?.toString();
      if (mcc == null || mnc == null) continue;

      final gid1 = op['gid1']?.toString();
      final gid2 = op['gid2']?.toString();

      final existing = await getIcon(
        mcc: mcc,
        mnc: mnc,
        gid1: gid1,
        gid2: gid2,
      );
      if (existing == null) {
        missing.add({
          'mcc': mcc,
          'mnc': mnc,
          'gid1': gid1,
          'gid2': gid2,
          'profileName': op['profileName'],
          'serviceProviderName': op['serviceProviderName'],
        });
      }
    }

    if (missing.isEmpty) return;

    try {
      _log.info(
        "Resolving ${missing.length} missing operator icons from operator-icons...",
      );

      for (final op in missing) {
        final mcc = op['mcc']?.toString();
        final mnc = op['mnc']?.toString();
        if (mcc == null || mnc == null) continue;

        final gid1 = op['gid1']?.toString();
        final gid2 = op['gid2']?.toString();
        final imageUrl = await OperatorIconSource().resolveIconUrl(
          mcc: mcc,
          mnc: mnc,
          gid1: gid1,
          gid2: gid2,
          profileName: op['profileName']?.toString(),
          serviceProviderName: op['serviceProviderName']?.toString(),
        );

        if (imageUrl != null && imageUrl.isNotEmpty) {
          // Download each icon in background without awaiting
          _downloadAndCacheIcon(mcc, mnc, gid1, gid2, imageUrl);
        } else {
          _log.info("No icon available for $mcc-$mnc");
        }
      }
    } catch (e) {
      _log.severe("Error fetching operator icons: $e");
    }
  }

  /// Downloads and caches an operator icon in the background
  void _downloadAndCacheIcon(
    String mcc,
    String mnc,
    String? gid1,
    String? gid2,
    String imageUrl,
  ) async {
    try {
      _log.info("Downloading icon from: $imageUrl");
      final imageResponse = await http.get(Uri.parse(imageUrl));

      if (imageResponse.statusCode == 200) {
        // Convert to base64 for local storage
        final base64Image = base64Encode(imageResponse.bodyBytes);

        try {
          await DatabaseService().saveOperatorIcon(
            mcc: mcc,
            mnc: mnc,
            gid1: gid1,
            gid2: gid2,
            image: base64Image,
          );
          final cacheKey = _getCacheKey(mcc, mnc, gid1, gid2);
          _memoryCache[cacheKey] = base64Image;
          _decodeAndCacheBytes(cacheKey, base64Image);

          // Notify UI to update with debouncing to avoid excessive rebuilds
          _triggerNotify();

          _log.info(
            "Successfully cached icon for $mcc-$mnc (${imageResponse.bodyBytes.length} bytes)",
          );
        } catch (dbError) {
          _log.severe(
            "Failed to save icon to database for $mcc-$mnc: $dbError",
          );
          // Still cache in memory even if DB save fails
          final cacheKey = _getCacheKey(mcc, mnc, gid1, gid2);
          _memoryCache[cacheKey] = base64Image;
          _decodeAndCacheBytes(cacheKey, base64Image);
          _triggerNotify();
        }
      } else {
        _log.warning(
          "Failed to download icon from $imageUrl: ${imageResponse.statusCode}",
        );
      }
    } catch (e) {
      _log.severe("Error downloading icon from $imageUrl: $e");
    }
  }

  /// Clears the in-memory icon cache
  void clearMemoryCache() {
    _memoryCache.clear();
    _pendingLoads.clear();
    _decodedBytesCache.clear();
    _triggerNotify();
    _log.info("Memory cache cleared");
  }

  Uint8List? _decodeAndCacheBytes(String cacheKey, String encoded) {
    final cached = _decodedBytesCache[cacheKey];
    if (cached != null) return cached;
    try {
      final bytes = base64Decode(encoded);
      _decodedBytesCache[cacheKey] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  void _triggerNotify() {
    _notifyTimer?.cancel();
    _notifyTimer = Timer(const Duration(milliseconds: 200), () {
      iconUpdateNotifier.value++;
    });
  }
}
