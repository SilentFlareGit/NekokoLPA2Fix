import 'package:flutter/material.dart';

enum ReaderApiIconType { omapi, telephony }

class ReaderApiIcon extends StatelessWidget {
  final ReaderApiIconType type;
  final double size;
  final Color color;

  const ReaderApiIcon({
    super.key,
    required this.type,
    required this.color,
    this.size = 20,
  });

  static bool isOmapiReader(String? readerId) {
    return readerId?.startsWith('omapi:') ?? false;
  }

  static bool isTelephonyReader(String? readerId) {
    if (readerId == null) return false;
    return readerId.startsWith('tmapi:') || readerId.contains('|telephony:');
  }

  static Widget? forReaderId(
    String? readerId, {
    required BuildContext context,
    double size = 20,
    Color? color,
  }) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    if (isOmapiReader(readerId)) {
      return ReaderApiIcon(
        type: ReaderApiIconType.omapi,
        size: size,
        color: resolvedColor,
      );
    }
    if (isTelephonyReader(readerId)) {
      return ReaderApiIcon(
        type: ReaderApiIconType.telephony,
        size: size,
        color: resolvedColor,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _ReaderApiIconPainter(type, color)),
    );
  }
}

class _ReaderApiIconPainter extends CustomPainter {
  final ReaderApiIconType type;
  final Color color;

  const _ReaderApiIconPainter(this.type, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case ReaderApiIconType.omapi:
        _paintOmapi(canvas, size);
      case ReaderApiIconType.telephony:
        _paintTelephony(canvas, size);
    }
  }

  void _paintOmapi(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final sim = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.2,
        size.height * 0.12,
        size.width * 0.55,
        size.height * 0.72,
      ),
      Radius.circular(size.width * 0.1),
    );
    final notch = Path()
      ..moveTo(size.width * 0.58, size.height * 0.12)
      ..lineTo(size.width * 0.75, size.height * 0.29)
      ..lineTo(size.width * 0.75, size.height * 0.12)
      ..close();

    canvas.drawRRect(sim, fill);
    canvas.drawRRect(sim, stroke);
    canvas.drawPath(notch, fill);
    canvas.drawPath(notch, stroke);

    final contact = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final offset in [
      Offset(size.width * 0.36, size.height * 0.44),
      Offset(size.width * 0.57, size.height * 0.44),
      Offset(size.width * 0.36, size.height * 0.64),
      Offset(size.width * 0.57, size.height * 0.64),
    ]) {
      canvas.drawCircle(offset, size.width * 0.035, contact);
    }

    final keyPath = Path()
      ..moveTo(size.width * 0.55, size.height * 0.82)
      ..lineTo(size.width * 0.82, size.height * 0.82)
      ..moveTo(size.width * 0.72, size.height * 0.82)
      ..lineTo(size.width * 0.72, size.height * 0.92)
      ..moveTo(size.width * 0.82, size.height * 0.82)
      ..lineTo(size.width * 0.82, size.height * 0.91);
    canvas.drawCircle(
      Offset(size.width * 0.48, size.height * 0.82),
      size.width * 0.075,
      stroke,
    );
    canvas.drawPath(keyPath, stroke);
  }

  void _paintTelephony(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final phone = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.2,
        size.height * 0.08,
        size.width * 0.52,
        size.height * 0.82,
      ),
      Radius.circular(size.width * 0.12),
    );
    canvas.drawRRect(phone, fill);
    canvas.drawRRect(phone, stroke);
    canvas.drawLine(
      Offset(size.width * 0.4, size.height * 0.18),
      Offset(size.width * 0.52, size.height * 0.18),
      stroke,
    );
    canvas.drawCircle(
      Offset(size.width * 0.46, size.height * 0.8),
      size.width * 0.025,
      Paint()..color = color,
    );

    final bolt = Path()
      ..moveTo(size.width * 0.62, size.height * 0.18)
      ..lineTo(size.width * 0.46, size.height * 0.53)
      ..lineTo(size.width * 0.61, size.height * 0.53)
      ..lineTo(size.width * 0.49, size.height * 0.9)
      ..lineTo(size.width * 0.84, size.height * 0.43)
      ..lineTo(size.width * 0.66, size.height * 0.43)
      ..close();
    canvas.drawPath(
      bolt,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    final rootStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.77, size.height * 0.18),
      Offset(size.width * 0.92, size.height * 0.18),
      rootStroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.82, size.height * 0.1),
      Offset(size.width * 0.82, size.height * 0.27),
      rootStroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.89, size.height * 0.1),
      Offset(size.width * 0.89, size.height * 0.27),
      rootStroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ReaderApiIconPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
