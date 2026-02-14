import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

/// Circular safety score gauge (0-100)
class SafetyScoreGauge extends StatelessWidget {
  final double score;
  final double size;
  final bool showLabel;

  const SafetyScoreGauge({
    super.key,
    required this.score,
    this.size = 100,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forScore(score);
    final label = AppColors.labelForScore(score);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GaugePainter(
              score: score,
              color: color,
            ),
            child: Center(
              child: Text(
                score.round().toString(),
                style: TextStyle(
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppColors.iconForScore(score),
                color: color,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Background arc
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * 0.75, // Start at 7 o'clock
      pi * 1.5, // 270 degrees
      false,
      bgPaint,
    );

    // Score arc
    final scorePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / 100) * pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * 0.75,
      sweepAngle,
      false,
      scorePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.score != score || old.color != color;
}
