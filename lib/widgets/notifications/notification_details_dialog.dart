// ignore_for_file: unnecessary_underscores
import 'package:flutter/material.dart';
import '../../models/asn1/rsp_definitions.g.dart';
import '../../services/profile_metadata_service.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../common/simple_dialog_container.dart';
import 'package:cached_network_image/cached_network_image.dart';

class NotificationDetailsDialog extends StatelessWidget {
  final PendingNotification notification;
  final int sequence;
  final String operation;
  final Color operationColor;
  final String profileName;
  final String? iccid;
  final String? address;
  final ProfileMetadata? metadata;

  const NotificationDetailsDialog({
    super.key,
    required this.notification,
    required this.sequence,
    required this.operation,
    required this.operationColor,
    required this.profileName,
    this.iccid,
    this.address,
    this.metadata,
  });

  static void show({
    required BuildContext context,
    required PendingNotification notification,
    required int sequence,
    required String operation,
    required Color operationColor,
    required String profileName,
    String? iccid,
    String? address,
    ProfileMetadata? metadata,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: AppLocalizations.of(context)!.dismiss,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return NotificationDetailsDialog(
          notification: notification,
          sequence: sequence,
          operation: operation,
          operationColor: operationColor,
          profileName: profileName,
          iccid: iccid,
          address: address,
          metadata: metadata,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SimpleDialogContainer(
      title: AppLocalizations.of(context)!.notificationDetails,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (metadata != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: metadata!.flagUrl,
                        width: 32,
                        height: 22,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(Icons.flag),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profileName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _detailRow(
              context,
              AppLocalizations.of(context)!.sequence,
              "#$sequence",
            ),
            _detailRow(
              context,
              AppLocalizations.of(context)!.operation,
              operation.toUpperCase(),
            ),
            if (iccid != null)
              _detailRow(context, AppLocalizations.of(context)!.iccid, iccid!),
            if (address != null)
              _detailRow(
                context,
                AppLocalizations.of(context)!.server,
                address!,
              ),
            _detailRow(
              context,
              AppLocalizations.of(context)!.profileNameLabel,
              profileName,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.surfaceSubtle(context),
                      foregroundColor: AppTheme.onSurfaceSubtle(context),
                      elevation: 0,
                    ),
                    child: Text(AppLocalizations.of(context)!.close),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.onSurfaceSubtle(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.mono(
                TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
