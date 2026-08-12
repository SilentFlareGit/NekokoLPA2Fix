import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:permission_handler/permission_handler.dart';
import '../../settings/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/styled_header_scaffold.dart';
import '../../l10n/app_localizations.dart';
import '../../services/local_notification_service.dart';
import '../tag_manager_page.dart';
import '../scheduled_notifications_page.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class TagsAndRemindersPage extends StatefulWidget {
  const TagsAndRemindersPage({super.key});

  @override
  State<TagsAndRemindersPage> createState() => _TagsAndRemindersPageState();
}

class _TagsAndRemindersPageState extends State<TagsAndRemindersPage> {
  bool _notificationsEnabled = false;
  bool _permissionCheckFailed = false;
  Timer? _countdownTimer;
  int _countdownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final isUnsupportedPlatform =
        !kIsWeb && (defaultTargetPlatform == TargetPlatform.linux);

    if (isUnsupportedPlatform) {
      if (mounted) {
        setState(() {
          _permissionCheckFailed = true;
          _notificationsEnabled = false;
        });
      }
      return;
    }

    try {
      bool enabled = false;
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.android) {
        enabled = await LocalNotificationService().checkPermission();
      } else {
        final status = await Permission.notification.status;
        enabled = status.isGranted || status.isProvisional;
      }

      if (mounted) {
        setState(() {
          _notificationsEnabled = enabled;
          _permissionCheckFailed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _permissionCheckFailed = true;
          _notificationsEnabled = false;
        });
      }
    }
  }

  Future<void> _requestPermission() async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final status = await Permission.notification.request();
      if (mounted) {
        setState(() {
          _notificationsEnabled = status.isGranted;
        });
      }

      if (mounted && status.isPermanentlyDenied) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.permissionsRequired),
            content: Text(l10n.notificationsDisabledMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.pop(context);
                },
                child: Text(l10n.openSettings),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      await LocalNotificationService().init();
      if (mounted) {
        setState(() {
          _permissionCheckFailed = true;
          _notificationsEnabled = false;
        });
      }
    }
  }

  void _startScheduledTest() async {
    if (!_notificationsEnabled && !_permissionCheckFailed) {
      await _requestPermission();
      if (!_notificationsEnabled && !_permissionCheckFailed) return;
    }

    setState(() {
      _countdownSeconds = 5;
    });

    LocalNotificationService().scheduleTestReminder();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
        } else {
          _countdownTimer?.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings(),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return StyledHeaderScaffold(
          title: l10n.tagsAndReminders,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final int colCount = (width / 450).floor().clamp(1, 10);

              final List<Widget> sections = [
                _buildSection(
                  context,
                  title: l10n.general,
                  children: [
                    _buildTagManagerTile(context),
                    _buildTagRemindersSwitcher(context),
                  ],
                ),
                if (AppSettings().enableScheduledNotifications)
                  _buildSection(
                    context,
                    title: l10n.notifications,
                    children: [
                      _buildPermissionStatusTile(context),
                      _buildTestNotificationTile(context),
                      _buildViewScheduledRemindersTile(context),
                    ],
                  ),
              ];

              return MasonryGridView.count(
                padding: const EdgeInsets.all(20),
                crossAxisCount: colCount,
                mainAxisSpacing: 32,
                crossAxisSpacing: 32,
                itemCount: sections.length,
                itemBuilder: (context, index) => sections[index],
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

  Widget _buildCustomSwitch(
    BuildContext context,
    bool value,
    Function(bool) onChanged, {
    bool enabled = true,
  }) {
    return Switch(value: value, onChanged: enabled ? onChanged : null);
  }

  Widget _buildTagManagerTile(BuildContext context) {
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
          Icons.label_outline_rounded,
          size: 20,
          color: Colors.blue,
        ),
      ),
      title: l10n.tagManager,
      subtitle: "View and search profile tags",
      child: Icon(
        Icons.chevron_right,
        color: AppTheme.onSurfaceVerySubtle(context),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TagManagerPage()),
      ),
    );
  }

  Widget _buildTagRemindersSwitcher(BuildContext context) {
    final settings = AppSettings();
    final l10n = AppLocalizations.of(context)!;
    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.timer_outlined, size: 20, color: Colors.teal),
      ),
      title: l10n.tagReminders,
      subtitle: l10n.tagRemindersSubtitle,
      child: _buildCustomSwitch(
        context,
        settings.enableScheduledNotifications,
        (v) => settings.setEnableScheduledNotifications(v),
      ),
      onTap: () => settings.setEnableScheduledNotifications(
        !settings.enableScheduledNotifications,
      ),
    );
  }

  Widget _buildPermissionStatusTile(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _notificationsEnabled
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _notificationsEnabled
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          size: 20,
          color: _notificationsEnabled ? Colors.green : Colors.orange,
        ),
      ),
      title: "Notification Permission", // Literal as requested/implied
      subtitle: _notificationsEnabled
          ? l10n.permissionsActive
          : (_permissionCheckFailed
                ? l10n.couldNotVerifyStatus
                : l10n.permissionsRequired),
      child: _notificationsEnabled
          ? const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.green,
              size: 20,
            )
          : FilledButton.tonal(
              onPressed: _requestPermission,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(l10n.enable, style: const TextStyle(fontSize: 12)),
            ),
      onTap: _notificationsEnabled ? null : _requestPermission,
    );
  }

  Widget _buildTestNotificationTile(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.indigo.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.science_outlined,
          size: 20,
          color: Colors.indigo,
        ),
      ),
      title: l10n.testNotification,
      subtitle: _countdownSeconds > 0
          ? "Sending in $_countdownSeconds seconds..."
          : "Verify notification delivery",
      child: _countdownSeconds > 0
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: _countdownSeconds / 5.0,
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            )
          : Icon(
              Icons.play_arrow_rounded,
              color: AppTheme.onSurfaceVerySubtle(context),
            ),
      onTap: _countdownSeconds > 0 ? null : _startScheduledTest,
    );
  }

  Widget _buildViewScheduledRemindersTile(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _buildResponsiveTile(
      context,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.list_alt_rounded, size: 20, color: Colors.teal),
      ),
      title: l10n.viewScheduledReminders,
      subtitle: l10n.viewScheduledRemindersSubtitle,
      child: Icon(
        Icons.chevron_right,
        color: AppTheme.onSurfaceVerySubtle(context),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ScheduledNotificationsPage(),
        ),
      ),
    );
  }
}
