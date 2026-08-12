import 'package:flutter/material.dart';
import '../../models/asn1/rsp_definitions.g.dart';
import '../../services/profile_metadata_service.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../common/loading_spinner.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NotificationCard extends StatefulWidget {
  final PendingNotification notification;
  final int sequenceNumber;
  final String operationName;
  final IconData operationIcon;
  final Color operationColor;
  final String profileName;
  final String? iccid;
  final String? address;
  final ProfileMetadata? profileMetadata;
  final String status; // 'on-card', 'sent', 'failed'
  final bool isProcessing;
  final bool isDeleting;
  final VoidCallback onTap;
  final Function(String) onMenuSelected;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.sequenceNumber,
    required this.operationName,
    required this.operationIcon,
    required this.operationColor,
    required this.profileName,
    this.iccid,
    this.address,
    this.profileMetadata,
    this.status = 'on-card',
    this.isProcessing = false,
    this.isDeleting = false,
    required this.onTap,
    required this.onMenuSelected,
  });

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _borderController;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isDeleting) {
      _borderController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant NotificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDeleting && !_borderController.isAnimating) {
      _borderController.repeat(reverse: true);
    } else if (!widget.isDeleting && _borderController.isAnimating) {
      _borderController.stop();
      _borderController.value = 0;
    }
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final deleteColor = Colors.red[400]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedBuilder(
        animation: _borderController,
        builder: (context, child) {
          final pulse = widget.isDeleting ? _borderController.value : 0.0;
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isDeleting
                    ? deleteColor.withValues(alpha: 0.45 + pulse * 0.45)
                    : AppTheme.surfaceSubtle(context),
                width: widget.isDeleting ? 1.5 + pulse * 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isDeleting
                      ? deleteColor.withValues(alpha: 0.16 + pulse * 0.12)
                      : Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                  blurRadius: widget.isDeleting ? 18 + pulse * 10 : 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sequence badge with operation icon and tag
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.operationColor.withValues(alpha: 0.15),
                                  widget.operationColor.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: widget.operationColor.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Icon(
                              widget.operationIcon,
                              size: 20,
                              color: widget.operationColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 48,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: widget.operationColor.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Text(
                              widget.operationName.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: widget.operationColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row: Flag, Profile name
                            Row(
                              children: [
                                // Flag
                                if (widget.profileMetadata != null) ...[
                                  Container(
                                    width: 20,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: CachedNetworkImage(
                                        imageUrl:
                                            widget.profileMetadata!.flagUrl,
                                        fit: BoxFit.cover,
                                        errorWidget:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.flag_outlined,
                                                  size: 12,
                                                ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                // Profile name
                                Expanded(
                                  child: Text(
                                    widget.profileName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: theme.colorScheme.onSurface,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // ICCID
                            if (widget.iccid != null) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.credit_card_rounded,
                                    size: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      widget.iccid!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        letterSpacing: 0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            // Server address
                            if (widget.address != null &&
                                widget.address!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.cloud_outlined,
                                    size: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _trimAddress(widget.address!),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Menu and Sequence ID
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          widget.isProcessing
                              ? Container(
                                  padding: const EdgeInsets.all(8),
                                  child: const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: LoadingSpinner(
                                      strokeWidth: 2,
                                      color: kPrimaryColor,
                                    ),
                                  ),
                                )
                              : PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: Material(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.more_horiz_rounded,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 8,
                                  color: AppTheme.cardBackground(context),
                                  onSelected: widget.onMenuSelected,
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'send',
                                      height: 48,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.send_rounded,
                                              size: 16,
                                              color: Colors.blue[400],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.sendNotification,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'curl',
                                      height: 48,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.code_rounded,
                                              size: 16,
                                              color: Colors.orange[400],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.exportAsCurl,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      height: 48,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 16,
                                              color: Colors.red[400],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.deleteNotification,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Status text for sent/failed
                              if (widget.status != 'on-card') ...[
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    widget.status == 'sent'
                                        ? AppLocalizations.of(context)!.sent
                                        : AppLocalizations.of(
                                            context,
                                          )!.failedToSend,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: widget.status == 'sent'
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              // Sequence number
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: 4,
                                  bottom: 2,
                                ),
                                child: Text(
                                  "#${widget.sequenceNumber}",
                                  style: AppTheme.mono(
                                    TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.onSurfaceVerySubtle(
                                        context,
                                      ),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.status == 'sent')
              Positioned(
                right: -1,
                top: -1,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                  ),
                  child: CustomPaint(
                    painter: _SentCornerPainter(Colors.blue[500]!),
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5, right: 5),
                          child: Icon(
                            Icons.send_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _trimAddress(String addr) {
    if (addr.isEmpty) return addr;
    try {
      final uri = Uri.parse(addr.startsWith('http') ? addr : 'https://$addr');
      return uri.host;
    } catch (_) {
      // Fallback if parsing fails: remove common prefixes/suffixes
      String result = addr;
      if (result.startsWith('https://')) result = result.substring(8);
      if (result.startsWith('http://')) result = result.substring(7);
      if (result.contains('/')) result = result.split('/').first;
      return result;
    }
  }
}

class _SentCornerPainter extends CustomPainter {
  final Color color;

  const _SentCornerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SentCornerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
