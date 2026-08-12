import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SwitchModeButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String topLabel; // Current mode (Large/Primary)
  final String bottomLabel; // Alternative mode (Small/Muted)
  final bool isLoading;

  const SwitchModeButton({
    super.key,
    this.onPressed,
    required this.topLabel,
    required this.bottomLabel,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmall = MediaQuery.of(context).size.width < 350;
    final buttonWidth = isSmall ? 56.0 : 68.0;
    final buttonHeight = isSmall ? 44.0 : 52.0;

    return SizedBox(
      width: buttonWidth,
      height: buttonHeight,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isLoading ? null : onPressed,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          topLabel,
                          style: TextStyle(
                            fontSize: isSmall ? 13 : 15,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                            height: 1.0,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          bottomLabel,
                          style: TextStyle(
                            fontSize: isSmall ? 9 : 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurfaceVerySubtle(context),
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
