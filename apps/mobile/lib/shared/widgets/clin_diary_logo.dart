import 'package:flutter/material.dart';

class ClinDiaryLogo extends StatelessWidget {
  const ClinDiaryLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return RepaintBoundary(
      child: Semantics(
        label: 'ClinDiary',
        image: true,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ClinDiaryLogoPainter(
              backgroundColor: colorScheme.primary,
              pageColor: colorScheme.surface,
              borderColor: colorScheme.onSurface.withValues(
                alpha: brightness == Brightness.dark ? 0.28 : 0.16,
              ),
              accentColor: colorScheme.secondary,
              lineColor: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClinDiaryLogoPainter extends CustomPainter {
  const _ClinDiaryLogoPainter({
    required this.backgroundColor,
    required this.pageColor,
    required this.borderColor,
    required this.accentColor,
    required this.lineColor,
  });

  final Color backgroundColor;
  final Color pageColor;
  final Color borderColor;
  final Color accentColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final outerRect = Rect.fromLTWH(0, 0, side, side);
    final outerRadius = Radius.circular(side * 0.26);

    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, outerRadius),
      Paint()
        ..color = backgroundColor
        ..isAntiAlias = true,
    );

    final pageRect = Rect.fromLTWH(
      side * 0.18,
      side * 0.16,
      side * 0.60,
      side * 0.68,
    );
    final pageRadius = Radius.circular(side * 0.12);

    canvas.drawRRect(
      RRect.fromRectAndRadius(pageRect, pageRadius),
      Paint()
        ..color = pageColor
        ..isAntiAlias = true,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(pageRect, pageRadius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.025
        ..color = borderColor
        ..isAntiAlias = true,
    );

    final spineRect = Rect.fromLTWH(
      pageRect.left + pageRect.width * 0.12,
      pageRect.top + pageRect.height * 0.12,
      pageRect.width * 0.16,
      pageRect.height * 0.76,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(spineRect, Radius.circular(side * 0.06)),
      Paint()
        ..color = accentColor
        ..isAntiAlias = true,
    );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = side * 0.038
      ..color = lineColor.withValues(alpha: 0.84)
      ..isAntiAlias = true;

    final lineStartX = spineRect.right + pageRect.width * 0.10;
    final lineEndX = pageRect.right - pageRect.width * 0.10;
    final firstLineY = pageRect.top + pageRect.height * 0.34;
    final secondLineY = pageRect.top + pageRect.height * 0.53;
    final thirdLineY = pageRect.top + pageRect.height * 0.71;

    canvas.drawLine(
      Offset(lineStartX, firstLineY),
      Offset(lineEndX, firstLineY),
      linePaint,
    );
    canvas.drawLine(
      Offset(lineStartX, secondLineY),
      Offset(lineEndX - side * 0.03, secondLineY),
      linePaint,
    );
    canvas.drawLine(
      Offset(lineStartX, thirdLineY),
      Offset(lineEndX - side * 0.08, thirdLineY),
      linePaint,
    );

    final crossCenter = Offset(
      pageRect.right - pageRect.width * 0.17,
      pageRect.top + pageRect.height * 0.18,
    );
    final crossPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = side * 0.038
      ..color = accentColor
      ..isAntiAlias = true;

    canvas.drawLine(
      Offset(crossCenter.dx - side * 0.03, crossCenter.dy),
      Offset(crossCenter.dx + side * 0.03, crossCenter.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(crossCenter.dx, crossCenter.dy - side * 0.03),
      Offset(crossCenter.dx, crossCenter.dy + side * 0.03),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ClinDiaryLogoPainter oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor ||
        pageColor != oldDelegate.pageColor ||
        borderColor != oldDelegate.borderColor ||
        accentColor != oldDelegate.accentColor ||
        lineColor != oldDelegate.lineColor;
  }
}