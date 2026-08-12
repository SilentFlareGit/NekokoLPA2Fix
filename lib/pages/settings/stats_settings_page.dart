import 'package:flutter/material.dart';
import '../../settings/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/styled_header_scaffold.dart';
import '../../services/database_service.dart';
import '../../services/operator_icon_service.dart';

class StatsSettingsPage extends StatefulWidget {
  const StatsSettingsPage({super.key});

  @override
  State<StatsSettingsPage> createState() => _StatsSettingsPageState();
}

class _StatsSettingsPageState extends State<StatsSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings(),
      builder: (context, _) {
        final settings = AppSettings();
        return StyledHeaderScaffold(
          title: 'Nekoko Cloud',
          subtitle: 'Help improve compatibility and size prediction',
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(context, "STATISTICS COLLECTION"),
                const SizedBox(height: 16),
                _buildMainToggle(context, settings),
                const SizedBox(height: 16),
                _buildSecondaryOptions(context, settings),
                const SizedBox(height: 24),
                _buildInfoBox(
                  context,
                  "Nekoko Cloud collect anonymized installation statistics to help better predict the profile size and compatibility issues. Size prediction will no longer be available when this is turned off. Only installation-related data will be collected, and it does not contain any personal information and will be anonymized.",
                ),
              ],
            ),
          ),
        );
      },
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

  Widget _buildMainToggle(BuildContext context, AppSettings settings) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceSubtle(context)),
      ),
      child: _buildSwitchRow(
        context,
        title: "Enable Nekoko Cloud",
        subtitle: "Contribute to database improvement",
        value: settings.enableNekokoStats,
        onChanged: (v) => settings.setEnableNekokoStats(v),
      ),
    );
  }

  Widget _buildSecondaryOptions(BuildContext context, AppSettings settings) {
    final theme = Theme.of(context);
    final enabled = settings.enableNekokoStats;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceSubtle(context)),
      ),
      child: Column(
        children: [
          _buildSwitchRow(
            context,
            title: "Estimate Profile Size",
            subtitle: "Predict storage usage for installed profiles",
            value: settings.estimateProfileSize,
            onChanged: (v) => settings.setEstimateProfileSize(v),
            isDisabled: !enabled,
          ),
          const Divider(),
          _buildClearCacheButton(context, enabled),
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
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
              value: isDisabled ? false : value,
              onChanged: isDisabled ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearCacheButton(BuildContext context, bool enabled) {
    return InkWell(
      onTap: enabled ? () => _clearIconCache(context) : null,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Clear Icon Cache",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Remove all cached operator icons",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.onSurfaceSubtle(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.delete_outline,
                color: enabled
                    ? Theme.of(context).colorScheme.error
                    : AppTheme.onSurfaceSubtle(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clearIconCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Icon Cache'),
        content: const Text(
          'This will remove all cached operator icons. They will be re-downloaded when needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Clear',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await DatabaseService().clearOperatorIcons();
        OperatorIconService().clearMemoryCache();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Icon cache cleared successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear cache: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
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
          Icon(
            Icons.analytics_outlined,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
