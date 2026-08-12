import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'plugin_base.dart';
import 'build_plugin_registry.dart';
import '../models/euicc_profile.dart';
import '../models/profile_card_bottom_data.dart';

class PluginManager extends ChangeNotifier {
  static final Logger _log = Logger('PluginManager');
  static final PluginManager _instance = PluginManager._internal();
  factory PluginManager() => _instance;
  PluginManager._internal() {
    _registerPlugins();
  }

  final List<ProfilePlugin> _plugins = [];

  List<ProfilePlugin> get plugins => List.unmodifiable(_plugins);

  void _registerPlugins() {
    _plugins
      ..clear()
      ..addAll(BuildPluginRegistry.createPlugins());
  }

  bool hasPlugin(String id) => _plugins.any((plugin) => plugin.id == id);

  List<AppTabSpec> get appTabs => _plugins
      .map((plugin) => plugin.appTab)
      .whereType<AppTabSpec>()
      .toList(growable: false);

  Future<void> notifyProfilesLoaded(
    String eid,
    List<EuiccProfile> profiles,
  ) async {
    for (final plugin in _plugins) {
      await plugin.onProfilesLoaded(eid, profiles, onUpdate: notifyListeners);
    }
    notifyListeners();
  }

  Future<void> notifyInstallationReported(
    InstallationReportContext report,
  ) async {
    for (final plugin in _plugins) {
      try {
        await plugin.onInstallationReported(report);
      } catch (e, stackTrace) {
        _log.warning(
          'Plugin ${plugin.id} failed while handling installation report: $e',
          e,
          stackTrace,
        );
      }
    }
  }

  List<Widget> buildHeaders(BuildContext context, String? eid) {
    return _plugins
        .map((p) => p.buildHeader(context, eid))
        .whereType<Widget>()
        .toList();
  }

  List<Widget> buildReaderActions(
    BuildContext context,
    ReaderActionContext actionContext,
  ) {
    return _plugins
        .expand((plugin) => plugin.buildReaderActions(context, actionContext))
        .toList(growable: false);
  }

  List<Widget> buildProfileCardExtras(
    BuildContext context,
    EuiccProfile profile,
  ) {
    return _plugins
        .where((p) => p.isMatch(profile))
        .map((p) => p.buildProfileCardExtra(context, profile))
        .whereType<Widget>()
        .toList();
  }

  ProfileCardBottomData? getMergedProfileCardBottomData(EuiccProfile profile) {
    ProfileCardBottomData? mergedData;

    final matchingPlugins = _plugins.where((p) => p.isMatch(profile));

    for (final plugin in matchingPlugins) {
      final data = plugin.getProfileCardBottomData(profile);
      if (data != null && !data.isEmpty) {
        if (mergedData == null) {
          mergedData = data;
        } else {
          // Merge logic:
          // - Keep existing theme color (or maybe use the new one if the other was default?)
          // - Keep existing phone number if present, otherwise take new one
          // - Keep existing line expiry if present
          // - Keep existing balance
          // - Append packages
          // This is a simple merge strategy.
          mergedData = ProfileCardBottomData(
            themeColor: mergedData.themeColor, // Prefer first plugin's theme
            phoneNumber: mergedData.phoneNumber ?? data.phoneNumber,
            lineExpiry: mergedData.lineExpiry ?? data.lineExpiry,
            balance: mergedData.balance ?? data.balance,
            packages: [...mergedData.packages, ...data.packages],
          );
        }
      }
    }
    return mergedData;
  }

  List<PluginAction> getProfileActions(
    BuildContext context,
    EuiccProfile profile,
  ) {
    return _plugins
        .where((p) => p.isMatch(profile))
        .expand((p) => p.getProfileActions(context, profile))
        .toList();
  }

  List<PluginAction> getEidActions(
    BuildContext context,
    String? eid, {
    String? aid,
  }) {
    return _plugins
        .expand((p) => p.getEidActions(context, eid, aid: aid))
        .toList();
  }

  Map<String, WidgetBuilder> get allRoutes {
    final routes = <String, WidgetBuilder>{};
    for (final plugin in _plugins) {
      routes.addAll(plugin.routes);
    }
    return routes;
  }
}
