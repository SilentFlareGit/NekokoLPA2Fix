import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'simple_dialog_container.dart';
import 'loading_spinner.dart';

class PremiumDialogs {
  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = "Confirm",
    String cancelLabel = "Cancel",
    bool isDestructive = false,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        final theme = Theme.of(context);
        return SimpleDialogContainer(
          title: title,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.onSurfaceSubtle(context),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppTheme.surfaceSubtle(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          cancelLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurfaceSubtle(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: isDestructive
                              ? Colors.red[400]
                              : theme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showLoadingDialog({
    required BuildContext context,
    required String message,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Loading",
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return SimpleDialogContainer(
          title: "Processing",
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: LoadingSpinner(strokeWidth: 3),
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceSubtle(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
