import 'dart:async';

import 'package:flutter/material.dart';
import '../../settings/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/styled_header_scaffold.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StyledHeaderScaffold(
      title: l10n.notificationProcessing,
      subtitle: l10n.manageAutoNotification,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(context, l10n.automaticProcessing),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildGrid(
                    context,
                    (width / 400).floor().clamp(1, 10),
                  ),
                ),
                const SizedBox(height: 24),
                _buildInfoBox(context, l10n.notificationProcessingHelp),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid(BuildContext context, int columns) {
    final settings = AppSettings();
    final l10n = AppLocalizations.of(context)!;
    final developerModeEnabled = settings.developerModeEnabled;

    final cards = [
      _buildTimingCard(
        context,
        title: l10n.notificationProcessingTimings,
        description: l10n.notificationProcessingTimingsHelp,
        rows: [
          _TimingToggleRow(
            title: l10n.initialLoad,
            subtitle: l10n.processNotificationsOnInitialLoad,
            value: settings.notifProcessInitialLoad,
            onChanged: settings.setNotifProcessInitialLoad,
          ),
          _TimingToggleRow(
            title: l10n.afterSwitchingProfile,
            subtitle: l10n.processNotificationsAfterSwitchingProfile,
            value: settings.notifProcessAfterSwitch,
            onChanged: settings.setNotifProcessAfterSwitch,
          ),
          _TimingToggleRow(
            title: l10n.afterProfileDeletion,
            subtitle: l10n.processNotificationsAfterProfileDeletion,
            value: settings.notifProcessAfterDeletion,
            onChanged: settings.setNotifProcessAfterDeletion,
            disableRequiresDeveloperMode: true,
            developerModeEnabled: developerModeEnabled,
          ),
          _TimingToggleRow(
            title: l10n.beforeProfileDownload,
            subtitle: l10n.processNotificationsBeforeProfileDownload,
            value: settings.notifProcessBeforeDownload,
            onChanged: settings.setNotifProcessBeforeDownload,
            disableRequiresDeveloperMode: true,
            developerModeEnabled: developerModeEnabled,
          ),
          _TimingToggleRow(
            title: l10n.afterProfileInstalled,
            subtitle: l10n.processNotificationsAfterProfileInstalled,
            value: settings.notifProcessAfterInstall,
            onChanged: settings.setNotifProcessAfterInstall,
            disableRequiresDeveloperMode: true,
            developerModeEnabled: developerModeEnabled,
          ),
        ],
      ),
      _buildProcessCard(
        context,
        title: l10n.enabling,
        description: l10n.afterEnablingProfile,
        sendValue: settings.notifAutoSendEnable,
        removeValue: settings.notifAutoRemoveEnable,
        deleteWithoutSendingValue: settings.notifDeleteWithoutSendingEnable,
        onSendChanged: (v) => settings.setNotifAutoSendEnable(v),
        onRemoveChanged: (v) => settings.setNotifAutoRemoveEnable(v),
        onDeleteWithoutSendingChanged: (v) =>
            settings.setNotifDeleteWithoutSendingEnable(v),
      ),
      _buildProcessCard(
        context,
        title: l10n.disabling,
        description: l10n.afterDisablingProfile,
        sendValue: settings.notifAutoSendDisable,
        removeValue: settings.notifAutoRemoveDisable,
        deleteWithoutSendingValue: settings.notifDeleteWithoutSendingDisable,
        onSendChanged: (v) => settings.setNotifAutoSendDisable(v),
        onRemoveChanged: (v) => settings.setNotifAutoRemoveDisable(v),
        onDeleteWithoutSendingChanged: (v) =>
            settings.setNotifDeleteWithoutSendingDisable(v),
      ),
      _buildProcessCard(
        context,
        title: l10n.installation,
        description: l10n.afterProfileDownload,
        sendValue: settings.notifAutoSendInstall,
        removeValue: settings.notifAutoRemoveInstall,
        deleteWithoutSendingValue: null,
        onSendChanged: (v) => settings.setNotifAutoSendInstall(v),
        onRemoveChanged: (v) => settings.setNotifAutoRemoveInstall(v),
        onDeleteWithoutSendingChanged: null,
      ),
      _buildProcessCard(
        context,
        title: l10n.deletion,
        description: l10n.afterProfileDeletion,
        sendValue: settings.notifAutoSendDelete,
        removeValue: settings.notifAutoRemoveDelete,
        deleteWithoutSendingValue: null,
        onSendChanged: (v) => settings.setNotifAutoSendDelete(v),
        onRemoveChanged: (v) => settings.setNotifAutoRemoveDelete(v),
        onDeleteWithoutSendingChanged: null,
      ),
    ];

    return MasonryGridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      itemCount: cards.length,
      itemBuilder: (context, index) => cards[index],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTimingCard(
    BuildContext context, {
    required String title,
    required String description,
    required List<_TimingToggleRow> rows,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceSubtle(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.onSurfaceSubtle(context),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(indent: 20),
            _buildSwitchRow(
              context,
              title: rows[i].title,
              subtitle: rows[i].effectiveSubtitle(context),
              value: rows[i].value,
              isDisabled:
                  rows[i].disableRequiresDeveloperMode &&
                  !rows[i].developerModeEnabled,
              onChanged: (value) {
                setState(() {});
                unawaited(rows[i].onChanged(value));
              },
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildProcessCard(
    BuildContext context, {
    required String title,
    required String description,
    required bool sendValue,
    required bool removeValue,
    required bool? deleteWithoutSendingValue,
    required Function(bool) onSendChanged,
    required Function(bool) onRemoveChanged,
    required Function(bool)? onDeleteWithoutSendingChanged,
  }) {
    final theme = Theme.of(context);
    final isDangerMode = deleteWithoutSendingValue == true;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceSubtle(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.onSurfaceSubtle(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          if (!isDangerMode) ...[
            _buildSwitchRow(
              context,
              title: AppLocalizations.of(context)!.autoSend,
              subtitle: AppLocalizations.of(context)!.sendToServerAutomatically,
              value: sendValue,
              onChanged: (value) {
                setState(() {});
                onSendChanged(value);
              },
            ),
            if (sendValue) ...[
              const Divider(indent: 20),
              _buildSwitchRow(
                context,
                title: AppLocalizations.of(context)!.autoRemove,
                subtitle: AppLocalizations.of(
                  context,
                )!.removeFromCardAfterSending,
                value: removeValue,
                onChanged: (value) {
                  setState(() {});
                  onRemoveChanged(value);
                },
              ),
            ],
          ],

          if (deleteWithoutSendingValue != null &&
              onDeleteWithoutSendingChanged != null) ...[
            if (!isDangerMode) const Divider(indent: 20),
            _buildSwitchRow(
              context,
              title: AppLocalizations.of(context)!.removeWithoutSending,
              subtitle: AppLocalizations.of(
                context,
              )!.removeWithoutSendingCaution,
              value: deleteWithoutSendingValue,
              onChanged: (value) {
                setState(() {});
                onDeleteWithoutSendingChanged(value);
              },
              isDanger: true,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isDisabled = false,
    bool isDanger = false,
  }) {
    final theme = Theme.of(context);
    final dangerColor = theme.colorScheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDanger ? dangerColor : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.onSurfaceSubtle(context),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: isDisabled ? null : onChanged,
              activeTrackColor: isDanger ? dangerColor : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimingToggleRow {
  final String title;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool) onChanged;
  final bool disableRequiresDeveloperMode;
  final bool developerModeEnabled;

  const _TimingToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.disableRequiresDeveloperMode = false,
    this.developerModeEnabled = true,
  });

  String effectiveSubtitle(BuildContext context) {
    if (!disableRequiresDeveloperMode || developerModeEnabled) {
      return subtitle;
    }

    return '$subtitle ${AppLocalizations.of(context)!.developerModeRequiredToDisableTiming}';
  }
}
