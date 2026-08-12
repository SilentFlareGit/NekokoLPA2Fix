import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/euicc_profile.dart';
import '../../../../models/asn1/rsp_definitions.g.dart';

enum ReaderStatus {
  idle,
  loading,
  ready,
  noCard,
  unsupported,
  araMFailed,
  bleError,
  remoteError,
}

class ReaderStateData {
  final List<EuiccProfile>? profiles;
  final String? eid;
  final EUICCInfo2? info2;
  final Object? lastError;
  final ReaderStatus status;

  final bool isAraMFailed;
  final String? unsupportedOperatorIcon;
  final String? unsupportedFallbackDetails;
  final bool loading;
  final bool isConnecting;
  final bool isListingProfiles;
  final String? operationLoadingMessage;
  final String? togglingIccid;
  final bool hasBeenLoaded;

  const ReaderStateData({
    this.profiles,
    this.eid,
    this.info2,
    this.lastError,
    this.status = ReaderStatus.idle,
    this.isAraMFailed = false,
    this.unsupportedOperatorIcon,
    this.unsupportedFallbackDetails,
    this.loading = false,
    this.isConnecting = false,
    this.isListingProfiles = false,
    this.operationLoadingMessage,
    this.togglingIccid,
    this.hasBeenLoaded = false,
  });

  ReaderStateData copyWith({
    List<EuiccProfile>? profiles,
    String? eid,
    EUICCInfo2? info2,
    Object? lastError,
    ReaderStatus? status,
    bool? isAraMFailed,
    String? unsupportedOperatorIcon,
    String? unsupportedFallbackDetails,
    bool? loading,
    bool? isConnecting,
    bool? isListingProfiles,
    String? operationLoadingMessage,
    String? togglingIccid,
    bool? hasBeenLoaded,
  }) {
    return ReaderStateData(
      profiles: profiles ?? this.profiles,
      eid: eid ?? this.eid,
      info2: info2 ?? this.info2,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
      isAraMFailed: isAraMFailed ?? this.isAraMFailed,
      unsupportedOperatorIcon:
          unsupportedOperatorIcon ?? this.unsupportedOperatorIcon,
      unsupportedFallbackDetails:
          unsupportedFallbackDetails ?? this.unsupportedFallbackDetails,
      loading: loading ?? this.loading,
      isConnecting: isConnecting ?? this.isConnecting,
      isListingProfiles: isListingProfiles ?? this.isListingProfiles,
      operationLoadingMessage:
          operationLoadingMessage ?? this.operationLoadingMessage,
      togglingIccid: togglingIccid ?? this.togglingIccid,
      hasBeenLoaded: hasBeenLoaded ?? this.hasBeenLoaded,
    );
  }
}

class ReaderStateNotifier extends Notifier<ReaderStateData> {
  ReaderStateNotifier(this.readerId);

  final String readerId;

  @override
  ReaderStateData build() => const ReaderStateData();

  void setStatus(ReaderStatus status) {
    state = state.copyWith(status: status);
  }

  void setProfiles(List<EuiccProfile> profiles) {
    state = state.copyWith(profiles: profiles, hasBeenLoaded: true);
  }
}

final readerStateProvider =
    NotifierProvider.family<ReaderStateNotifier, ReaderStateData, String>(
      ReaderStateNotifier.new,
    );
