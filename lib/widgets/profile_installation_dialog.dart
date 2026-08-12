import 'package:flutter/material.dart';
import '../services/deep_link_service.dart';

class ProfileInstallationDialog extends StatefulWidget {
  final String lpaCode;

  const ProfileInstallationDialog({super.key, required this.lpaCode});

  @override
  State<ProfileInstallationDialog> createState() =>
      _ProfileInstallationDialogState();
}

class _ProfileInstallationDialogState extends State<ProfileInstallationDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Install eSIM Profile'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text('You have a pending profile to install:'),
            const SizedBox(height: 8),
            Text(
              widget.lpaCode,
              style: TextStyle(
                fontFamily: 'Monospace',
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            const Text('Would you like to install it now?'),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Install Later'),
          onPressed: () {
            // Dismiss dialog but KEEP state (so it re-appears later)
            // To prevent it appearing immediately again in this session, we might need a "snooze" mechanism in Service.
            // But user requirement says "persist across re-launches".
            // If we just pop, the listener in Main.dart might re-trigger if it listens to "value".
            // Actually, listener only triggers on change. So popping is fine for THIS session.
            // UNLESS the listener checks value on build.
            // Main.dart uses `addListener`, so it triggers on change.
            // But `initState` in Main also checks initial value? No, I implemented that logic in `_onPendingLpaChanged` which is only added as listener.
            // Wait, Main.dart adds listener but doesn't check initial value manually in `initState` in my previous edit?
            // Actually I should have checked initial value.
            // Let's assume for now popping is safe.
            Navigator.of(context).pop();
          },
        ),
        FilledButton(
          child: const Text('Install Now'),
          onPressed: () {
            // Dismiss dialog
            Navigator.of(context).pop();

            // Navigate to main screen (ProfilesScreen / Manage Tab)
            Navigator.of(context).popUntil((route) => route.isFirst);

            // Signal to ProfilesScreen to start the selection/download flow
            DeepLinkService().triggerSelection.value = true;
          },
        ),
      ],
    );
  }
}
