// ignore_for_file: avoid_unnecessary_containers
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../adapter/euicc_adapter.dart';
import '../common/reader_api_icon.dart';
import 'reader_helper.dart';

class ReaderTabs extends StatelessWidget implements PreferredSizeWidget {
  final TabController tabController;
  final List<Reader> readers;

  const ReaderTabs({
    super.key,
    required this.tabController,
    required this.readers,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExtremelySmall = MediaQuery.of(context).size.width < 300;

    return Container(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(25),
        ),
        child: TabBar(
          controller: tabController,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: theme.colorScheme.surface,
            boxShadow: theme.brightness == Brightness.dark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: AppTheme.onSurfaceSubtle(context),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isExtremelySmall ? 11 : 13,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isExtremelySmall ? 11 : 13,
          ),
          tabs: readers.map((r) {
            final displayName = r.name;
            final parts = displayName.split('|');
            final isSelected = tabController.index == readers.indexOf(r);

            return Tab(
              height: 42,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isExtremelySmall) ...[
                    _buildReaderIcon(context, r.id, isSelected),
                    SizedBox(width: isExtremelySmall ? 3 : 6),
                  ],
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parts[0],
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (parts.length > 1)
                          Text(
                            parts[1],
                            style: TextStyle(
                              fontSize: isExtremelySmall ? 9 : 10,
                              fontWeight: FontWeight.w400,
                              color:
                                  (isSelected
                                          ? theme.colorScheme.primary
                                          : AppTheme.onSurfaceSubtle(context))
                                      .withValues(alpha: 0.7),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReaderIcon(
    BuildContext context,
    String readerId,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final color = ReaderHelper.getIconColor(
      readerId,
      context,
      overrideColor: isSelected ? theme.colorScheme.primary : null,
    );
    final apiIcon = ReaderApiIcon.forReaderId(
      readerId,
      context: context,
      size: 14,
      color: color,
    );
    if (apiIcon != null) return apiIcon;

    return Icon(ReaderHelper.getIconData(readerId), size: 14, color: color);
  }
}
