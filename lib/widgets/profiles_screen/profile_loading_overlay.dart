import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/platform_adapter.dart';
import '../common/loading_spinner.dart';

class ProfileLoadingOverlay extends StatefulWidget {
  final bool isVisible;
  final String? message;
  final bool isFetchingNotifications;
  final bool isProcessingNotifications;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const ProfileLoadingOverlay({
    super.key,
    required this.isVisible,
    this.message,
    this.isFetchingNotifications = false,
    this.isProcessingNotifications = false,
    this.onCancel,
    this.onRetry,
  });

  @override
  State<ProfileLoadingOverlay> createState() => _ProfileLoadingOverlayState();
}

class _ProfileLoadingOverlayState extends State<ProfileLoadingOverlay> {
  bool _showActions = false;
  Timer? _timer;

  @override
  void didUpdateWidget(ProfileLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _startTimer();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _stopTimer();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _startTimer() {
    _stopTimer();
    _showActions = false;
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showActions = true);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _showActions = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        color: theme.colorScheme.surface.withValues(
          alpha: PlatformX.isAndroid ? 0.9 : 0.6,
        ),
        child: PlatformX.isAndroid
            ? _buildContent(context, theme)
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: _buildContent(context, theme),
              ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingSpinner(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            widget.isFetchingNotifications
                ? "Loading notifications..."
                : (widget.message ?? "Please wait..."),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.2,
              decoration: TextDecoration.none,
            ),
          ),
          if (_showActions && !widget.isFetchingNotifications) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onCancel != null)
                  TextButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close),
                    label: const Text("Cancel"),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                if (widget.onCancel != null && widget.onRetry != null)
                  const SizedBox(width: 8),
                if (widget.onRetry != null)
                  ElevatedButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Retry"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
