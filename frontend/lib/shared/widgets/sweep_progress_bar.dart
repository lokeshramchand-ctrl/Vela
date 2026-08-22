import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A pill progress bar with an animated diagonal shine sweeping across the
/// fill (the design's `vsweep` keyframe, ~1.5s ease-in-out infinite).
class SweepProgressBar extends StatefulWidget {
  const SweepProgressBar({
    super.key,
    required this.percent,
    this.height = 6,
    this.trackColor,
    this.fillColor,
  });

  final double percent; // 0-100
  final double height;
  final Color? trackColor;
  final Color? fillColor;

  @override
  State<SweepProgressBar> createState() => _SweepProgressBarState();
}

class _SweepProgressBarState extends State<SweepProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.height / 2),
      child: Container(
        height: widget.height,
        color: widget.trackColor ?? AppColors.ink700,
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: (widget.percent.clamp(0, 100)) / 100,
              child: Container(color: widget.fillColor ?? AppColors.accent),
            ),
            FractionallySizedBox(
              widthFactor: (widget.percent.clamp(0, 100)) / 100,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return ShaderMask(
                    shaderCallback: (rect) {
                      final t = _controller.value;
                      return LinearGradient(
                        begin: Alignment(-3 + t * 6, 0),
                        end: Alignment(-2.4 + t * 6, 0),
                        colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0)],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.plus,
                    child: Container(color: Colors.transparent),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
