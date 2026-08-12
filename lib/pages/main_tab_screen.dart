import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'profiles_screen.dart';
import 'web_browser_page.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../settings/app_settings.dart';
import '../plugins/plugin_manager.dart';
import 'package:flutter/foundation.dart';
import '../utils/platform_adapter.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  bool _isHoveringTopBar = false;

  // Base pages that are always there or standard
  // We'll construct the active list in build or compute it.

  @override
  void initState() {
    super.initState();
    AppSettings().addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    AppSettings().removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final settings = AppSettings();
    // Determine if we should show standard buy tab

    final pluginTabs = PluginManager().appTabs;
    final tabEntries = <_MainTabEntry>[
      _MainTabEntry(
        label: l10n.manage,
        icon: Icons.sim_card_outlined,
        activeIcon: Icons.sim_card,
        pageBuilder: (_) => const ProfilesScreen(),
      ),
      ...pluginTabs.map(
        (tab) => _MainTabEntry(
          label: tab.label,
          icon: tab.icon,
          activeIcon: tab.activeIcon,
          pageBuilder: tab.builder,
        ),
      ),
    ];

    // Variant Tabs from Config
    if (settings.enableBrowser) {
      for (final tabConfig in settings.variantTabs) {
        if (!tabConfig.isEnabled) continue;
        if (!settings.isOnline) continue;
        if (kIsWeb) continue;
        if (PlatformX.isWindows || PlatformX.isLinux) continue;

        tabEntries.add(
          _MainTabEntry(
            label: tabConfig.label,
            icon: _resolveIcon(tabConfig.icon, false),
            activeIcon: _resolveIcon(tabConfig.icon, true),
            pageBuilder: (_) => WebBrowserPage(
              initialUrl: tabConfig.url,
              title: tabConfig.title,
            ),
          ),
        );
      }
    }

    final pages = tabEntries
        .map((entry) => Builder(builder: entry.pageBuilder))
        .toList(growable: false);
    final tabs = List<Widget>.generate(
      tabEntries.length,
      (index) => _buildTabItem(
        context,
        index: index,
        isActive: _currentIndex == index,
        icon: tabEntries[index].icon,
        activeIcon: tabEntries[index].activeIcon,
        label: tabEntries[index].label,
      ),
      growable: false,
    );

    // Adjust current index if it went out of bounds
    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    final showBottomBar = tabs.length > 1;
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    Widget body = IndexedStack(index: _currentIndex, children: pages);

    // Add floating top bar for desktop
    if (isDesktop && showBottomBar) {
      body = Stack(
        children: [
          body,
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Center(
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHoveringTopBar = true),
                onExit: (_) => setState(() => _isHoveringTopBar = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.9,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(tabs.length, (index) {
                      final bool isActive = _currentIndex == index;
                      final entry = tabEntries[index];
                      final label = entry.label;
                      final icon = isActive ? entry.activeIcon : entry.icon;

                      return InkWell(
                        onTap: () {
                          setState(() => _currentIndex = index);
                          HapticFeedback.selectionClick();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: isActive
                              ? BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(20),
                                )
                              : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 18,
                                color: isActive
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                child: _isHoveringTopBar
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(width: 8),
                                          Text(
                                            label,
                                            style: TextStyle(
                                              color: isActive
                                                  ? theme.colorScheme.onPrimary
                                                  : theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              fontWeight: isActive
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: (showBottomBar && !isDesktop)
          ? Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 56, // Shorter height
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: tabs,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTabItem(
    BuildContext context, {
    required int index,
    required bool isActive,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final color = isActive
        ? theme.colorScheme.primary
        : AppTheme.onSurfaceSubtle(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          HapticFeedback.selectionClick();
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _resolveIcon(String name, bool active) {
    switch (name) {
      case 'web':
        return active ? Icons.explore : Icons.explore_outlined;
      case 'shopping_cart':
        return active ? Icons.shopping_cart : Icons.shopping_cart_outlined;
      case 'language':
        return active ? Icons.language : Icons.language_outlined;
      case 'sim_card':
        return active ? Icons.sim_card : Icons.sim_card_outlined;
      case 'devices_other':
        return active ? Icons.devices_other : Icons.devices_other_outlined;
      default:
        return active ? Icons.circle : Icons.circle_outlined;
    }
  }
}

class _MainTabEntry {
  const _MainTabEntry({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.pageBuilder,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final WidgetBuilder pageBuilder;
}
