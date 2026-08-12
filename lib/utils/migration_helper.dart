import 'dart:typed_data';

// Conditional import: Use dart:io on mobile/desktop, or local stub on web
import 'dart:io' if (dart.library.html) 'io_stub.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';
import 'platform_adapter.dart';

// We need path_provider only if not web, dealing with that is tricky in single file
// if path_provider exports are platform dependent.
// path_provider supports web, so it's safe to import.
import 'package:path_provider/path_provider.dart';

class MigrationHelper {
  static final Logger _log = Logger('MigrationHelper');
  static final Map<String, int> _memStats = {};

  static Future<void> performMigration() async {
    if (!PlatformX.isAndroid && !PlatformX.isIOS) return;

    try {
      String? mmkvPath;
      if (PlatformX.isAndroid) {
        final appDir = await getApplicationDocumentsDirectory();
        final filesDir = '${appDir.parent.path}/files';
        mmkvPath = '$filesDir/mmkv/sizeStats';
      } else if (PlatformX.isIOS) {
        final docDir = await getApplicationDocumentsDirectory();
        final appHome = docDir.parent.path;

        final path = '$appHome/Documents/mmkv/sizeStats';
        final file = io.File(path);
        // On web (stub), file.exists() might not exist or return false.
        // But we are guarded by kIsWeb above.
        // However, io_stub needs to match API used here or dynamic cast.
        // io_stub.File doesn't have `exists()` or `readAsBytes()`.
        // We need to upgrade io_stub or use proper stubs?
        // Actually, since I deleted the generic split files, I should just make this safe.
        // Since this code ONLY runs on IO, dynamic dispatch or ignore can work?
        // No, Analysis fails.
        // Best approach: Use the `File` class from conditional import.
        // Need to update `io_stub.dart` to include `exists()` and `readAsBytes()`.

        // Let's assume io_stub update is next step.
        // For now I write the code assuming `io.File` has these methods.
        // Note: implicit interface of io.File vs stub.

        // Wait, if I use `io.File`, the analyzer checks against the common interface
        // or if guarded, it might still verify signatures.
        // To be safe and since I cannot easily change io_stub without potentially breaking others (though it seems unused mostly?),
        // I'll update io_stub.dart in next step.

        if (await file.exists()) {
          _log.info('Found MMKV via candidate: $path');
          mmkvPath = path;
        }

        if (mmkvPath == null) {
          _log.warning('Standard MMKV paths failed.');
        }
      }

      final sizeStatsFile = mmkvPath != null ? io.File(mmkvPath) : null;

      if (sizeStatsFile == null || !await sizeStatsFile.exists()) {
        if (sizeStatsFile != null) {
          _log.info('MMKV sizeStats not found at ${sizeStatsFile.path}');
        }
        return;
      }

      final data = await sizeStatsFile.readAsBytes();
      final stats = _parseMMKV(data);

      if (stats.isEmpty) {
        return;
      }

      stats.forEach((key, value) {
        if (value > 5000 && value < 500000) {
          _memStats[key] = value.toInt();
        }
      });

      if (_memStats.isEmpty) return; // If after filtering, _memStats is empty
      final db = DatabaseService();
      final List<String> migratedIccids = [];

      for (final iccid in _memStats.keys) {
        final value = _memStats[iccid]!;

        // Find corresponding EID from metadata using partial match (LIKE)
        final metadata = await (await db.database).query(
          'profile_metadata',
          columns: ['eid', 'iccid'],
          where: 'iccid LIKE ?',
          whereArgs: ['$iccid%'],
        );

        if (metadata.isNotEmpty) {
          final foundEid = metadata.first['eid'] as String?;
          final fullIccid = metadata.first['iccid'] as String;
          if (foundEid != null) {
            await _saveToProfileStorage(db, foundEid, fullIccid, value);
            migratedIccids.add(iccid);
          }
        } else {
          _log.warning(
            'Found size stat for $iccid but no metadata found (LIKE $iccid%) to link EID (will retry on scan)',
          );
        }
      }

      // Clean up already migrated
      for (final iccid in migratedIccids) {
        _memStats.remove(iccid);
      }
    } catch (e, stack) {
      _log.severe('Error during migration: $e', e, stack);
    }
  }

  /// To be called when a profile is discovered during scanning
  static Future<void> reconcile(String eid, String iccid) async {
    // Check for exact OR partial match
    String? matchedKey;
    if (_memStats.containsKey(iccid)) {
      matchedKey = iccid;
    } else {
      // Find a key in _memStats that is a prefix of our current iccid
      try {
        matchedKey = _memStats.keys.firstWhere((key) => iccid.startsWith(key));
      } catch (e) {
        matchedKey = null;
      }
    }

    if (matchedKey != null && matchedKey.isNotEmpty) {
      final size = _memStats[matchedKey]!;
      _log.info(
        'Reconciling size for ICCID $iccid (matched $matchedKey), EID $eid: $size',
      );
      await _saveToProfileStorage(DatabaseService(), eid, iccid, size);
      _memStats.remove(matchedKey);
    }
  }

  static Map<String, double> _parseMMKV(Uint8List data) {
    if (data.length < 8) return {};

    final reader = ByteData.view(data.buffer, data.offsetInBytes, data.length);
    final actualSize = reader.getUint32(0, Endian.little);

    final Map<String, double> result = {};
    int pos = 8; // skip size and mystery header

    while (pos < 4 + actualSize && pos < data.length) {
      try {
        // Key length (varint)
        int keyLen;
        int keyLenByte = data[pos];
        if (keyLenByte >= 0x80) {
          keyLen = (keyLenByte & 0x7f) | (data[pos + 1] << 7);
          pos += 2;
        } else {
          keyLen = keyLenByte;
          pos += 1;
        }

        if (pos + keyLen > data.length) break;
        final key = String.fromCharCodes(data.sublist(pos, pos + keyLen));
        pos += keyLen;

        // Value length (varint)
        int valLen;
        if (pos >= data.length) break;
        int valLenByte = data[pos];
        if (valLenByte >= 0x80) {
          valLen = (valLenByte & 0x7f) | (data[pos + 1] << 7);
          pos += 2;
        } else {
          valLen = valLenByte;
          pos += 1;
        }

        if (pos + valLen > data.length) break;
        final valData = data.sublist(pos, pos + valLen);
        pos += valLen;

        if (valLen == 8) {
          final valReader = ByteData.view(
            valData.buffer,
            valData.offsetInBytes,
            valData.length,
          );
          final value = valReader.getFloat64(0, Endian.little);
          result[key] = value;
        } else if (valLen == 4) {
          final valReader = ByteData.view(
            valData.buffer,
            valData.offsetInBytes,
            valData.length,
          );
          final value = valReader.getInt32(0, Endian.little);
          result[key] = value.toDouble();
        } else {}
      } catch (e) {
        _log.warning('Error parsing MMKV entry at pos $pos: $e');
        break;
      }
    }
    return result;
  }

  static Future<void> _saveToProfileStorage(
    DatabaseService dbService,
    String eid,
    String iccid,
    int size,
  ) async {
    final db = await dbService.database;

    // Corresponding EID (with f padding)
    String paddedEid = eid;
    if (paddedEid.length < 32) {
      paddedEid = paddedEid.padRight(32, 'f');
    }

    await db.insert('profile_storage', {
      'eid': paddedEid,
      'iccid': iccid,
      'spaceConsumed': size,
      'version': 100,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
