// ignore_for_file: unused_field
import 'package:sqflite/sqflite.dart';
import '../utils/mcc_mapper.dart';
import 'package:logging/logging.dart';
import 'database_service.dart';
import '../utils/profile_tag_utils.dart';
import '../utils/migration_helper.dart';

class ProfileMetadata {
  final String iccid;
  final String? nickname;
  final String? name;
  final String? providerName;
  final String? mcc;
  final String? mnc;
  final bool? enabled;
  final int? profileClass;
  final int? profileSize;
  final String? gid1;
  final String? gid2;
  final List<String> tags;
  final DateTime lastSeen;
  final String? eid;
  final String? customIcon;

  ProfileMetadata({
    required this.iccid,
    this.nickname,
    this.name,
    this.providerName,
    this.mcc,
    this.mnc,
    this.enabled,
    this.profileClass,
    this.profileSize,
    this.gid1,
    this.gid2,
    this.tags = const [],
    required this.lastSeen,
    this.eid,
    this.customIcon,
  });

  Map<String, dynamic> toMap() => {
    'iccid': iccid,
    'nickname': nickname,
    'name': name,
    'providerName': providerName,
    'mcc': mcc,
    'mnc': mnc,
    'enabled': enabled == true ? 1 : 0,
    'profileClass': profileClass,
    'profileSize': profileSize,
    'gid1': gid1,
    'gid2': gid2,
    'tags': tags.join(' '),
    'lastSeen': lastSeen.millisecondsSinceEpoch,
    'eid': eid,
    'customIcon': customIcon,
  };

  factory ProfileMetadata.fromMap(Map<String, dynamic> map) => ProfileMetadata(
    iccid: map['iccid'] as String,
    nickname: map['nickname'] as String?,
    name: map['name'] as String?,
    providerName: map['providerName'] as String?,
    mcc: map['mcc'] as String?,
    mnc: map['mnc'] as String?,
    enabled: map['enabled'] == 1,
    profileClass: map['profileClass'] as int?,
    profileSize: map['profileSize'] as int?,
    gid1: map['gid1'] as String?,
    gid2: map['gid2'] as String?,
    tags: (map['tags'] as String? ?? '')
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList(),
    lastSeen: DateTime.fromMillisecondsSinceEpoch(map['lastSeen'] as int),
    eid: map['eid'] as String?,
    customIcon: map['customIcon'] as String?,
  );

  String get displayName {
    if (nickname != null && nickname!.isNotEmpty) {
      final parsed = ProfileTagUtils.parse(nickname!, regionCode: flag);
      if (parsed.displayName.isNotEmpty) return parsed.displayName;
    }
    if (name != null && name!.isNotEmpty) return name!;
    if (providerName != null && providerName!.isNotEmpty) return providerName!;
    return 'Unknown Profile';
  }

  String get flag {
    return MccMapper.mccToCountryCode(mcc, mnc: mnc, iccid: iccid);
  }

  String get flagUrl {
    return MccMapper.getFlagUrl(mcc, mnc: mnc, iccid: iccid);
  }
}

class ProfileMetadataService {
  static const String _tableName = 'profile_metadata'; // Correct table name
  static final Logger _log = Logger('ProfileMetadataService');

  static ProfileMetadataService? _instance;

  ProfileMetadataService._();

  static Future<ProfileMetadataService> getInstance() async {
    _instance ??= ProfileMetadataService._();
    return _instance!;
  }

  Future<Database> get _database async {
    return await DatabaseService().database;
  }

  Future<void> saveProfile({
    required String iccid,
    String? nickname,
    String? name,
    String? providerName,
    String? mcc,
    String? mnc,
    bool? enabled,
    int? profileClass,
    int? profileSize,
    String? gid1,
    String? gid2,
    List<String>? tags,
    String? eid,
    String? customIcon,
  }) async {
    // Preserve existing customIcon if not provided
    String? iconParam = customIcon;
    if (iconParam == null) {
      final existing = await getProfile(iccid);
      iconParam = existing?.customIcon;
    }

    final metadata = ProfileMetadata(
      iccid: iccid,
      nickname: nickname,
      name: name,
      providerName: providerName,
      mcc: mcc,
      mnc: mnc,
      enabled: enabled,
      profileClass: profileClass,
      profileSize: profileSize,
      gid1: gid1,
      gid2: gid2,
      tags: tags ?? [],
      lastSeen: DateTime.now(),
      eid: eid,
      customIcon: iconParam,
    );

    final db = await _database;
    await db.insert(
      _tableName,
      metadata.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Reconcile size migration if needed
    if (eid != null) {
      await MigrationHelper.reconcile(eid, iccid);
    }
  }

  Future<ProfileMetadata?> getProfile(String iccid) async {
    // _log.fine('getProfile called for ICCID: $iccid');
    final db = await _database;
    final results = await db.query(
      _tableName,
      where: 'iccid = ?',
      whereArgs: [iccid],
      limit: 1,
    );

    if (results.isEmpty) {
      // _log.fine('getProfile: No profile found for ICCID: $iccid');
      return null;
    }
    final profile = ProfileMetadata.fromMap(results.first);
    // _log.fine('getProfile: Found profile for ICCID: $iccid - ${profile.displayName}');
    return profile;
  }

  Future<List<ProfileMetadata>> getAllProfiles() async {
    final db = await _database;
    final results = await db.query(_tableName, orderBy: 'lastSeen DESC');

    return results.map((map) => ProfileMetadata.fromMap(map)).toList();
  }

  Future<List<ProfileMetadata>> getRecentProfiles({int limit = 50}) async {
    final db = await _database;
    final results = await db.query(
      _tableName,
      orderBy: 'lastSeen DESC',
      limit: limit,
    );

    return results.map((map) => ProfileMetadata.fromMap(map)).toList();
  }

  Future<void> updateLastSeen(String iccid) async {
    final db = await _database;
    await db.update(
      _tableName,
      {'lastSeen': DateTime.now().millisecondsSinceEpoch},
      where: 'iccid = ?',
      whereArgs: [iccid],
    );
  }

  Future<void> deleteProfile(String iccid) async {
    final db = await _database;
    await db.delete(_tableName, where: 'iccid = ?', whereArgs: [iccid]);
  }

  Future<void> deleteOldProfiles({int daysToKeep = 90}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final db = await _database;
    await db.delete(
      _tableName,
      where: 'lastSeen < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );
  }

  Future<int> getProfileCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    // DatabaseService manages the connection, so we don't close it here.
    // _database = null; // No longer a stored field
    _instance = null;
  }
}
