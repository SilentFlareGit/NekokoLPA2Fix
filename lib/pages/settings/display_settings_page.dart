import 'package:flutter/material.dart';
import '../../settings/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/styled_header_scaffold.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/platform_adapter.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class DisplaySettingsPage extends StatelessWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings(),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return StyledHeaderScaffold(
          title: l10n.displaySettings,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final int colCount = (width / 450).floor().clamp(1, 10);

              final List<Widget> sections = [
                _buildSection(
                  context,
                  title: l10n.general,
                  children: [
                    _buildThemeTypeSwitcher(context),
                    if (PlatformX.isMobile)
                      _buildForceDeviceDropdownSwitcher(context),
                    _buildUseWaterfallLayoutSwitcher(context),
                    _buildEnableBrowserSwitcher(context),
                    _buildSizeUnitSelector(context),
                    _buildEstimateProfileSizeSwitcher(context),
                    _buildUseNekokoIconsSwitcher(context),
                    _buildPhoneFormatSelector(context),
                  ],
                ),
                _buildSection(
                  context,
                  title: l10n.ui,
                  children: [
                    _buildAutoLoadSwitcher(context),
                    _buildShowProfileSearchSwitcher(context),
                  ],
                ),
              ];

              return MasonryGridView.count(
                padding: const EdgeInsets.all(20),
                crossAxisCount: colCount,
                mainAxisSpacing: 32,
                crossAxisSpacing: 32,
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  return sections[index];
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary,
              letterSpacing: 2.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.3 : 0.04,
                ),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1) _buildDivider(context),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);
    return Divider(
      height: 1,
      indent: 72,
      color: theme.dividerColor.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.1 : 0.05,
      ),
    );
  }

  Widget _buildResponsiveTile(
    BuildContext context, {
    required Widget icon,
    required String title,
    String? subtitle,
    required Widget child,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 20,
    ),
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
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
              const SizedBox(width: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveDropdown<T>({
    required BuildContext context,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    final theme = Theme.of(context);
    final currentItem = items.firstWhere((item) => item.value == value);

    return Theme(
      data: theme.copyWith(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<T>(
        initialValue: value,
        offset: const Offset(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.dividerColor),
        ),
        color: theme.colorScheme.surface,
        elevation: 8,
        onSelected: onChanged,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  child: currentItem.child,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppTheme.onSurfaceVerySubtle(context),
              ),
            ],
          ),
        ),
        itemBuilder: (context) {
          return items.map((item) {
            final isSelected = item.value == value;
            return PopupMenuItem<T>(
              value: item.value,
              child: Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.onSurface
                            : AppTheme.onSurfaceSubtle(context),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 14,
                      ),
                      child: item.child,
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
            );
          }).toList();
        },
      ),
    );
  }

  Widget _buildCustomSwitch(
    BuildContext context,
    bool value,
    Function(bool) onChanged, {
    bool enabled = true,
  }) {
    return Switch(value: value, onChanged: enabled ? onChanged : null);
  }

  // Widget Builders (Moved from SettingsPage)

  Widget _buildThemeTypeSwitcher(BuildContext context) {
    final settings = AppSettings();
    final l10n = AppLocalizations.of(context)!;

    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.indigo.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.color_lens_outlined,
          size: 20,
          color: Colors.indigo,
        ),
      ),
      title: l10n.themeStyle,
      subtitle: l10n.themeStyleSubtitle,
      child: _buildAdaptiveDropdown<AppThemeType>(
        context: context,
        value: settings.themeType,
        items: [
          DropdownMenuItem(
            value: AppThemeType.custom,
            child: Text(l10n.customDesign),
          ),
          DropdownMenuItem(
            value: AppThemeType.stock,
            child: Text(l10n.stockMD3),
          ),
        ],
        onChanged: (type) {
          if (type != null) settings.setThemeType(type);
        },
      ),
    );
  }

  Widget _buildForceDeviceDropdownSwitcher(BuildContext context) {
    final settings = AppSettings();
    final l10n = AppLocalizations.of(context)!;

    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_drop_down_circle_outlined,
          size: 20,
          color: Colors.blue,
        ),
      ),
      title: l10n.forceDeviceDropdown,
      subtitle: l10n.forceDeviceDropdownSubtitle,
      child: _buildCustomSwitch(
        context,
        settings.forceDeviceDropdown,
        (v) => settings.setForceDeviceDropdown(v),
      ),
      onTap: () =>
          settings.setForceDeviceDropdown(!settings.forceDeviceDropdown),
    );
  }

  Widget _buildSizeUnitSelector(BuildContext context) {
    final settings = AppSettings();
    final l10n = AppLocalizations.of(context)!;

    final Map<String, String> options = {
      "settings_item_unit_b": l10n.settings_item_unit_b,
      "settings_item_unit_kb": l10n.settings_item_unit_kb,
      "settings_item_unit_kib": l10n.settings_item_unit_kib,
      "settings_item_unit_adaptive_si": l10n.settings_item_unit_adaptive_si,
      "settings_item_unit_adaptive_bi": l10n.settings_item_unit_adaptive_bi,
    };

    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.data_usage_rounded,
          size: 20,
          color: Colors.blueGrey,
        ),
      ),
      title: l10n.sizeDisplayUnit,
      subtitle: l10n.sizeDisplayUnitSubtitle,
      child: _buildAdaptiveDropdown<String>(
        context: context,
        value: settings.sizeUnit,
        items: options.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            settings.setSizeUnit(newValue);
          }
        },
      ),
    );
  }

  Widget _buildEstimateProfileSizeSwitcher(BuildContext context) {
    final settings = AppSettings();
    final l10n = AppLocalizations.of(context)!;
    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.analytics_outlined,
          size: 20,
          color: Colors.amber,
        ),
      ),
      title: l10n.estimateProfileSize,
      subtitle: l10n.estimateProfileSizeSubtitle,
      child: _buildCustomSwitch(
        context,
        settings.estimateProfileSize,
        (v) => settings.setEstimateProfileSize(v),
      ),
      onTap: () =>
          settings.setEstimateProfileSize(!settings.estimateProfileSize),
    );
  }

  Widget _buildPhoneFormatSelector(BuildContext context) {
    final settings = AppSettings();
    final l10n = AppLocalizations.of(context)!;

    final Map<PhoneFormatStrategy, String> options = {
      PhoneFormatStrategy.internationalOnly: l10n.phoneFormatInternationalOnly,
      PhoneFormatStrategy.internationalAndMobile:
          l10n.phoneFormatInternationalAndMobile,
      PhoneFormatStrategy.internationalAndAll:
          l10n.phoneFormatInternationalAndAll,
      PhoneFormatStrategy.off: l10n.phoneFormatOff,
    };

    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.phone_iphone_rounded,
          size: 20,
          color: Colors.green,
        ),
      ),
      title: l10n.phoneFormat,
      subtitle: l10n.phoneFormatSubtitle,
      child: _buildAdaptiveDropdown<PhoneFormatStrategy>(
        context: context,
        value: settings.phoneFormatStrategy,
        items: options.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            settings.setPhoneFormatStrategy(newValue);
          }
        },
      ),
    );
  }

  Widget _buildUseWaterfallLayoutSwitcher(BuildContext context) {
    final settings = AppSettings();
    final l10n = AppLocalizations.of(context)!;

    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.dashboard_rounded,
          size: 20,
          color: Colors.deepPurple,
        ),
      ),
      title: l10n.waterfallLayout,
      subtitle: l10n.waterfallLayoutSubtitle,
      child: _buildCustomSwitch(
        context,
        settings.useWaterfallLayout,
        (v) => settings.setUseWaterfallLayout(v),
      ),
      onTap: () => settings.setUseWaterfallLayout(!settings.useWaterfallLayout),
    );
  }

  Widget _buildEnableBrowserSwitcher(BuildContext context) {
    final settings = AppSettings();
    final l10n = AppLocalizations.of(context)!;

    // Only show this setting if there are variant tabs configured
    if (settings.variantTabs.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.cyan.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.tab_rounded, size: 20, color: Colors.cyan),
      ),
      title: l10n.enableBrowser,
      subtitle: l10n.enableBrowserSubtitle,
      child: _buildCustomSwitch(
        context,
        settings.enableBrowser,
        (v) => settings.setEnableBrowser(v),
      ),
      onTap: () => settings.setEnableBrowser(!settings.enableBrowser),
    );
  }

  Widget _buildUseNekokoIconsSwitcher(BuildContext context) {
    final settings = AppSettings();
    final l10n = AppLocalizations.of(context)!;

    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.pink.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          size: 20,
          color: Colors.pink,
        ),
      ),
      title: l10n.useNekokoIcons,
      subtitle: l10n.useNekokoIconsSubtitle,
      child: _buildCustomSwitch(
        context,
        settings.useNekokoIcons,
        (v) => settings.setUseNekokoIcons(v),
      ),
      onTap: () => settings.setUseNekokoIcons(!settings.useNekokoIcons),
    );
  }

  Widget _buildAutoLoadSwitcher(BuildContext context) {
    final settings = AppSettings();
    final l10n = AppLocalizations.of(context)!;

    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.sync, size: 20, color: Colors.blue),
      ),
      title: l10n.autoLoadProfiles,
      subtitle: l10n.autoLoadProfilesSubtitle,
      child: _buildCustomSwitch(
        context,
        settings.autoLoadProfiles,
        (v) => settings.setAutoLoadProfiles(v),
      ),
      onTap: () => settings.setAutoLoadProfiles(!settings.autoLoadProfiles),
    );
  }

  Widget _buildShowProfileSearchSwitcher(BuildContext context) {
    final settings = AppSettings();
    final l10n = AppLocalizations.of(context)!;

    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.search, size: 20, color: Colors.green),
      ),
      title: l10n.showProfileSearch,
      subtitle: l10n.showProfileSearchSubtitle,
      child: _buildCustomSwitch(
        context,
        settings.showProfileSearch,
        (v) => settings.setShowProfileSearch(v),
      ),
      onTap: () => settings.setShowProfileSearch(!settings.showProfileSearch),
    );
  }
}
