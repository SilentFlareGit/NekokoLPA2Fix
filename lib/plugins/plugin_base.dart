import 'package:flutter/material.dart';
import '../adapter/euicc_adapter.dart';
import '../logic/profile_download_session.dart';
import '../models/asn1/rsp_definitions.g.dart';
import '../models/euicc_profile.dart';
import '../models/profile_card_bottom_data.dart';

abstract class ProfilePlugin {
  String get id;
  String get name;
  AppTabSpec? get appTab => null;
  List<Widget> buildReaderActions(
    BuildContext context,
    ReaderActionContext actionContext,
  ) => const <Widget>[];

  /// Provide actions for the EID context menu.
  List<PluginAction> getEidActions(
    BuildContext context,
    String? eid, {
    String? aid,
  }) => [];

  /// Check if this plugin might have data for this profile.
  bool isMatch(EuiccProfile profile);

  /// Called when profiles are loaded for a specific EID.
  /// Plugins can use this to start background queries or pre-fetch data.
  /// The [onUpdate] callback should be called if the plugin fetches new data that requires a UI refresh.
  Future<void> onProfilesLoaded(
    String eid,
    List<EuiccProfile> profiles, {
    VoidCallback? onUpdate,
  }) async {}

  /// Called after a profile installation attempt has enough context to report.
  ///
  /// Data collection plugins can implement this without coupling download logic
  /// to their transport, payload shape, or remote endpoint.
  Future<void> onInstallationReported(InstallationReportContext report) async {}

  /// Build additional content before the profile list.
  Widget? buildHeader(BuildContext context, String? eid) => null;

  /// Build additional data for a specific profile card.
  Widget? buildProfileCardExtra(BuildContext context, EuiccProfile profile) =>
      null;

  /// Get data to be displayed in the absolute bottom of a profile card.
  /// Plugins should return data if eligible; multiple plugins data will be merged if possible,
  /// or stacked.
  ProfileCardBottomData? getProfileCardBottomData(EuiccProfile profile) => null;

  /// Provide routes for plugin-specific pages.
  Map<String, WidgetBuilder> get routes => {};

  /// Get a list of actions (e.g., menu items) for a profile.
  List<PluginAction> getProfileActions(
    BuildContext context,
    EuiccProfile profile,
  ) => [];
}

class PluginAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  PluginAction({required this.label, required this.icon, required this.onTap});
}

class AppTabSpec {
  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final WidgetBuilder builder;

  const AppTabSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.builder,
  });
}

class ReaderActionContext {
  const ReaderActionContext({
    required this.adapter,
    required this.reader,
    required this.profiles,
  });

  final Adapter adapter;
  final Reader? reader;
  final List<EuiccProfile>? profiles;
}

class InstallationReportContext {
  const InstallationReportContext({
    required this.session,
    required this.authBefore,
    this.authAfter,
    this.installResult,
    this.bppSize,
    this.notification,
  });

  final ProfileDownloadSession? session;
  final AuthenticateResponseOk? authBefore;
  final AuthenticateResponseOk? authAfter;
  final String? installResult;
  final int? bppSize;
  final PendingNotification? notification;

  bool get isSuccess => installResult == null;
}
