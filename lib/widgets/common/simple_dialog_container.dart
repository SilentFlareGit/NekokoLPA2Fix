import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'loading_spinner.dart';
import '../../utils/platform_adapter.dart';

class SimpleDialogContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final bool isLoading;
  final Widget? headerAction;

  const SimpleDialogContainer({
    super.key,
    required this.title,
    required this.child,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.isLoading = false,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;
    final keyboardInset = mediaQuery.viewInsets.bottom;

    // Use standard behavior on Desktop/Web, only animate on Mobile where keyboard pushes UI
    final useAnimate = PlatformX.isMobile && keyboardInset > 0;

    Widget dialogBody = Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: isSmallScreen ? double.infinity : 400,
          constraints: const BoxConstraints(maxHeight: 600),
          margin: EdgeInsets.all(isSmallScreen ? 12 : 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isSmallScreen ? 16 : 24,
                  isSmallScreen ? 16 : 24,
                  isSmallScreen ? 16 : 24,
                  isSmallScreen ? 12 : 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 17 : 20,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    ?headerAction,
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content
              Flexible(
                child: RepaintBoundary(
                  child: SingleChildScrollView(child: child),
                ),
              ),

              const Divider(height: 1),

              // Actions
              if (secondaryActionLabel != null || primaryActionLabel != null)
                RepaintBoundary(
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                    child: Row(
                      children: [
                        if (secondaryActionLabel != null)
                          Expanded(
                            child: TextButton(
                              onPressed: isLoading
                                  ? null
                                  : (onSecondaryAction ??
                                        () => Navigator.pop(context)),
                              style: isSmallScreen
                                  ? TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    )
                                  : null,
                              child: Text(
                                secondaryActionLabel!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.onSurfaceSubtle(context),
                                ),
                              ),
                            ),
                          ),

                        if (secondaryActionLabel != null &&
                            primaryActionLabel != null)
                          const SizedBox(width: 8),

                        if (primaryActionLabel != null)
                          Expanded(
                            child: FilledButton(
                              onPressed: isLoading ? null : onPrimaryAction,
                              style: isSmallScreen
                                  ? FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    )
                                  : null,
                              child: isLoading
                                  ? const LoadingSpinner(
                                      size: 20,
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      primaryActionLabel!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (useAnimate) {
      return AnimatedPadding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: dialogBody,
      );
    }
    return dialogBody;
  }
}
