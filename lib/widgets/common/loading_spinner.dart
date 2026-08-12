import 'package:flutter/material.dart';

class LoadingSpinner extends StatelessWidget {
  final double? size;
  final Color? color;
  final double strokeWidth;

  const LoadingSpinner({
    super.key,
    this.size,
    this.color,
    this.strokeWidth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Using RepaintBoundary to isolate the animation repaint area.
    // This often fixes "laggy" spinner issues on Android where the spinner
    // causes the entire page (or large parts of it) to repaint on every frame.
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          color: color ?? theme.colorScheme.primary,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}
