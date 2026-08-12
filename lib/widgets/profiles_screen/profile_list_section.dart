import 'package:flutter/material.dart';
import '../../models/euicc_profile.dart';
import '../profile_card.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../settings/app_settings.dart';
import '../../plugins/plugin_manager.dart';

class ProfileListSection extends StatefulWidget {
  final List<EuiccProfile> profiles;
  final String? eid;
  final String? togglingIccid;
  final String? deletingIccid;
  final bool isWide;
  final bool isLocked;
  final double padding;
  final double paddingV;
  final Function(String iccid) getCardKey;
  final Function(EuiccProfile profile, bool value) onToggle;
  final Function(EuiccProfile profile, GlobalKey cardKey) onMenu;
  final Function(EuiccProfile profile) onTagTap;
  final Future<void> Function()? onRefresh;

  const ProfileListSection({
    super.key,
    required this.profiles,
    this.eid,
    this.togglingIccid,
    this.deletingIccid,
    required this.isWide,
    required this.padding,
    required this.paddingV,
    required this.getCardKey,
    required this.onToggle,
    required this.onMenu,
    required this.onTagTap,
    this.isLocked = false,
    this.onRefresh,
  });

  @override
  State<ProfileListSection> createState() => _ProfileListSectionState();
}
class _ProfileListSectionState extends State<ProfileListSection> {
  final ValueNotifier<double> _overscrollNotifier = ValueNotifier<double>(0);

  @override
  void dispose() {
    _overscrollNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    Widget listContent;

    if (widget.isWide) {
      listContent = LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - widget.padding * 2;
          if (width <= 0) return const SizedBox.shrink();

          const double maxCrossAxisExtent = 400;
          const double crossAxisSpacing = 16;
          int crossAxisCount = (width / maxCrossAxisExtent).ceil();
          if (crossAxisCount < 1) crossAxisCount = 1;


          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: ListenableBuilder(
                  listenable: PluginManager(),
                  builder: (context, _) {
                    return Column(
                      children: PluginManager().buildHeaders(
                        context,
                        widget.eid,
                      ),
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  left: widget.padding,
                  right: widget.padding,
                  top: widget.paddingV,
                  bottom: widget.paddingV + 80,
                ),
                sliver: AppSettings().useWaterfallLayout
                    ? SliverMasonryGrid.count(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: crossAxisSpacing,
                        itemBuilder: (context, index) {
                          final p = widget.profiles[index];
                          final cardKey =
                              widget.getCardKey(p.iccid) as GlobalKey;
                          return RepaintBoundary(
                            child: ProfileCard(
                              key: ValueKey(p.iccid),
                              cardKey: cardKey,
                              profile: p,
                              eid: widget.eid,
                              isToggling: widget.togglingIccid == p.iccid,
                              isDeleting: widget.deletingIccid == p.iccid,
                              isLocked: widget.isLocked,
                              onToggle: (v) => widget.onToggle(p, v),
                              onMenu: () => widget.onMenu(p, cardKey),
                              onTagTap: () => widget.onTagTap(p),
                            ),
                          );
                        },
                        childCount: widget.profiles.length,
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, rowIndex) {
                            final startIndex = rowIndex * crossAxisCount;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (int i = 0; i < crossAxisCount; i++) ...[
                                    if (i > 0) SizedBox(width: crossAxisSpacing),
                                    Expanded(
                                      child: (startIndex + i < widget.profiles.length)
                                          ? RepaintBoundary(
                                              child: ProfileCard(
                                                key: ValueKey(
                                                  widget.profiles[startIndex + i]
                                                      .iccid,
                                                ),
                                                cardKey: widget.getCardKey(
                                                  widget.profiles[startIndex + i]
                                                      .iccid,
                                                ) as GlobalKey,
                                                profile: widget.profiles[startIndex + i],
                                                eid: widget.eid,
                                                isToggling: widget.togglingIccid ==
                                                    widget.profiles[startIndex + i]
                                                        .iccid,
                                                isDeleting: widget.deletingIccid ==
                                                    widget.profiles[startIndex + i]
                                                        .iccid,
                                                isLocked: widget.isLocked,
                                                onToggle: (v) => widget.onToggle(
                                                  widget.profiles[startIndex + i],
                                                  v,
                                                ),
                                                onMenu: () => widget.onMenu(
                                                  widget.profiles[startIndex + i],
                                                  widget.getCardKey(
                                                    widget.profiles[startIndex + i]
                                                        .iccid,
                                                  ) as GlobalKey,
                                                ),
                                                onTagTap: () => widget.onTagTap(
                                                  widget.profiles[startIndex + i],
                                                ),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                          childCount: (widget.profiles.length / crossAxisCount)
                              .ceil(),
                        ),
                      ),
              ),
            ],
          );
        },
      );
    } else {
      listContent = CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: PluginManager(),
              builder: (context, _) {
                return Column(
                  children: PluginManager().buildHeaders(context, widget.eid),
                );
              },
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              left: widget.padding,
              right: widget.padding,
              top: widget.paddingV,
              bottom: widget.paddingV + 80,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final p = widget.profiles[index];
                final cardKey = widget.getCardKey(p.iccid) as GlobalKey;
                return RepaintBoundary(
                  child: ProfileCard(
                    key: ValueKey(p.iccid),
                    cardKey: cardKey,
                    profile: p,
                    eid: widget.eid,
                    isToggling: widget.togglingIccid == p.iccid,
                    isDeleting: widget.deletingIccid == p.iccid,
                    isLocked: widget.isLocked,
                    isCompact: true,
                    onToggle: (v) => widget.onToggle(p, v),
                    onMenu: () => widget.onMenu(p, cardKey),
                    onTagTap: () => widget.onTagTap(p),
                  ),
                );
              }, childCount: widget.profiles.length),
            ),
          ),
        ],
      );
    }

    Widget content = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final pixels = notification.metrics.pixels;
          if (pixels < 0) {
            _overscrollNotifier.value = pixels.abs();
          } else if (_overscrollNotifier.value != 0) {
            _overscrollNotifier.value = 0;
          }
        }
        return false;
      },
      child: listContent,
    );

    if (widget.onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: widget.onRefresh!,
        color: theme.colorScheme.primary,
        displacement: 60, // Move spinner down to avoid overlap with text
        child: content,
      );
    }

    final installedText = l10n.profilesInstalled(widget.profiles.length);

    return Stack(
      children: [
        ValueListenableBuilder<double>(
          valueListenable: _overscrollNotifier,
          builder: (context, overscroll, _) {
            if (overscroll <= 5) return const SizedBox.shrink();
            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: overscroll.clamp(
                  0,
                  60,
                ), // Clamp height to match displacement gap
                alignment: Alignment.bottomCenter, // Align to bottom of the gap
                padding: const EdgeInsets.only(bottom: 15),
                child: Opacity(
                  opacity: (overscroll / 40).clamp(0, 1),
                  child: Text(
                    installedText,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        content,
      ],
    );
  }
}
