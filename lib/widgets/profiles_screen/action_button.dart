import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../common/loading_spinner.dart';

class ActionButton extends StatelessWidget {
  final IconData icon;
  final Widget? iconWidget;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final bool isLoading;
  final int badgeCount;

  const ActionButton({
    super.key,
    required this.icon,
    this.iconWidget,
    this.onPressed,
    this.onLongPress,
    required this.label,
    this.isPrimary = false,
    this.isDestructive = false,
    this.isLoading = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmall = MediaQuery.of(context).size.width < 300;
    final buttonSize = isSmall ? 40.0 : 52.0;

    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: Container(
        decoration: BoxDecoration(
          color: isDestructive
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.2)
              : (isPrimary
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface),
          borderRadius: BorderRadius.circular(14),
          border: (isPrimary || isDestructive)
              ? null
              : Border.all(color: theme.dividerColor),
          boxShadow: [
            if (isPrimary)
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: isLoading ? null : onPressed,
              onLongPress: isLoading ? null : onLongPress,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    isLoading
                        ? LoadingSpinner(
                            size: 20,
                            strokeWidth: 2,
                            color: isPrimary
                                ? Colors.white
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                          )
                        : (iconWidget ??
                              Icon(
                                icon,
                                color: isDestructive
                                    ? theme.colorScheme.error
                                    : (isPrimary
                                          ? Colors.white
                                          : AppTheme.onSurfaceSubtle(context)),
                                size: 22,
                              )),
                    if (badgeCount > 0 && !isLoading)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.surface,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              badgeCount > 99 ? '99+' : '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
