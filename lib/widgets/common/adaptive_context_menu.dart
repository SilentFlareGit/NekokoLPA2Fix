import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AdaptiveContextMenuItem {
  final String label;
  final IconData icon;
  final dynamic value;
  final bool enabled;
  final bool isDestructive;
  final Color? color;

  AdaptiveContextMenuItem({
    required this.label,
    required this.icon,
    required this.value,
    this.enabled = true,
    this.isDestructive = false,
    this.color,
  });
}

class AdaptiveContextMenu {
  static Future<T?> show<T>({
    required BuildContext context,
    required List<AdaptiveContextMenuItem> items,
    GlobalKey? anchorKey,
    Offset? position,
    String? title,
  }) async {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    if (isSmallScreen) {
      return showModalBottomSheet<T>(
        context: context,
        backgroundColor: AppTheme.surface(context),
        showDragHandle: true,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        builder: (context) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                  const SizedBox(height: 4),
                  ...items.map((item) {
                    final color =
                        item.color ??
                        (item.isDestructive
                            ? Colors.red
                            : theme.colorScheme.primary);
                    return ListTile(
                      dense: true,
                      enabled: item.enabled,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: item.enabled
                              ? color.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          item.icon,
                          color: item.enabled ? color : Colors.grey,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: !item.enabled
                              ? Colors.grey
                              : (item.isDestructive
                                    ? Colors.red
                                    : theme.colorScheme.onSurface),
                        ),
                      ),
                      onTap: () => Navigator.pop(context, item.value as T),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // Large screen - use showMenu
      RelativeRect? popupPosition;

      if (anchorKey != null) {
        final renderBox =
            anchorKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final offset = renderBox.localToGlobal(Offset.zero);
          final size = renderBox.size;
          popupPosition = RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + size.height * 0.5,
            offset.dx + size.width,
            offset.dy + size.height,
          );
        }
      } else if (position != null) {
        popupPosition = RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx,
          position.dy,
        );
      }

      if (popupPosition == null) return null;

      return showMenu<T>(
        context: context,
        position: popupPosition,
        color: AppTheme.cardBackground(context),
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        items: items
            .map(
              (item) => PopupMenuItem<T>(
                value: item.value as T,
                enabled: item.enabled,
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 18,
                      color: !item.enabled
                          ? Colors.grey
                          : (item.color ??
                                (item.isDestructive
                                    ? Colors.red
                                    : theme.colorScheme.onSurfaceVariant)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: !item.enabled
                            ? Colors.grey
                            : (item.color ??
                                  (item.isDestructive ? Colors.red : null)),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
    }
  }
}
