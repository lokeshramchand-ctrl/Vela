import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Circular job-progress ring: conic-gradient-style accent sweep vs a
/// translucent track, with a glow and a centered readout - matches the
/// Analysing screen's 172px ring.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.percent,
    this.size = 172,
    this.centerLabel,
    this.centerSubLabel,
  });

  final double percent; // 0-100
  final double size;
  final Widget? centerLabel;
  final String? centerSubLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 60, spreadRadius: -10),
        ],
      ),
      child: CustomPaint(
        painter: _RingPainter(percent: percent.clamp(0, 100) / 100),
        child: Center(
          child: Container(
            width: size * 0.80,
            height: size * 0.80,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.ink900, shape: BoxShape.circle),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?centerLabel,
                if (centerSubLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    centerSubLabel!,
                    style: AppTypography.microLabelTracked105.copyWith(color: AppColors.onDarkFaint),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.percent});
  final double percent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    final strokeWidth = 10.0;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final fillPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * percent;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.percent != percent;
}
