import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../l10n/app_localizations.dart';
import '../config.dart';

Future<void> showUpdateDialog(BuildContext context, UpdateInfo update) async {
  final l10n = AppLocalizations.of(context)!;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(
            Icons.system_update_rounded,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 12),
          Text(l10n.updateAvailable),
        ],
      ),
      content: SingleChildScrollView(
        child: ListBody(
          children: [
            Text(
              l10n.updateAvailableSubtitle(
                AppConfig.appName,
                update.version,
                update.build.toString(),
              ),
              style: const TextStyle(height: 1.5),
            ),
            if (update.changelog != null && update.changelog!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                l10n.changelog,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  update.changelog!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.later),
        ),
        ElevatedButton(
          onPressed: () async {
            final targetUrl = update.downloadUrl ?? update.url;
            if (targetUrl.isNotEmpty) {
              final uri = Uri.parse(targetUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            if (context.mounted) Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: Text(l10n.updateAction),
        ),
      ],
    ),
  );
}
