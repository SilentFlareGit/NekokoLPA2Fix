import 'dart:typed_data';
import '../utils/mcc_mapper.dart';
import '../utils/profile_tag_utils.dart';

class EuiccProfile {
  final String iccid;
  final String? name;
  final String? nickname;
  final String? serviceProviderName;
  final bool enabled;
  final int profileClass; // 0: test, 1: provisioning, 2: operational
  final String? isdpAid;
  final Uint8List? icon;
  final String? mcc;
  final String? mnc;
  final String? gid1;
  final String? gid2;
  final String? smdpAddress;
  final List<String> tags;

  EuiccProfile({
    required this.iccid,
    this.name,
    this.nickname,
    this.serviceProviderName,
    required this.enabled,
    this.profileClass = 2,
    this.isdpAid,
    this.icon,
    this.mcc,
    this.mnc,
    this.gid1,
    this.gid2,
    this.smdpAddress,
    this.tags = const [],
    this.customIcon,
  });

  // Mutable metadata
  String? customIcon;

  late final String displayName = _computeDisplayName();

  String _computeDisplayName() {
    if (nickname != null && nickname!.trim().isNotEmpty) {
      final parsed = ProfileTagUtils.parse(nickname, regionCode: flag);
      if (parsed.displayName.isNotEmpty) return parsed.displayName;
    }
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (serviceProviderName != null && serviceProviderName!.trim().isNotEmpty) {
      return serviceProviderName!.trim();
    }
    return 'Unnamed Profile';
  }

  String get flag {
    return MccMapper.mccToCountryCode(mcc, mnc: mnc, iccid: iccid);
  }

  String get flagEmoji {
    return MccMapper.getFlagEmoji(mcc, mnc: mnc, iccid: iccid);
  }

  String get flagUrl {
    return MccMapper.getFlagUrl(mcc, mnc: mnc, iccid: iccid);
  }

  EuiccProfile copyWith({
    String? iccid,
    String? name,
    String? nickname,
    String? serviceProviderName,
    bool? enabled,
    int? profileClass,
    String? isdpAid,
    Uint8List? icon,
    String? mcc,
    String? mnc,
    String? gid1,
    String? gid2,
    String? smdpAddress,
    List<String>? tags,
    String? customIcon,
  }) {
    return EuiccProfile(
      iccid: iccid ?? this.iccid,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      serviceProviderName: serviceProviderName ?? this.serviceProviderName,
      enabled: enabled ?? this.enabled,
      profileClass: profileClass ?? this.profileClass,
      isdpAid: isdpAid ?? this.isdpAid,
      icon: icon ?? this.icon,
      mcc: mcc ?? this.mcc,
      mnc: mnc ?? this.mnc,
      gid1: gid1 ?? this.gid1,
      gid2: gid2 ?? this.gid2,
      smdpAddress: smdpAddress ?? this.smdpAddress,
      tags: tags ?? this.tags,
      customIcon: customIcon ?? this.customIcon,
    );
  }

  @override
  String toString() {
    return 'EuiccProfile(iccid: $iccid, name: $name, enabled: $enabled)';
  }
}
