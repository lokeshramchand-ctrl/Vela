import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The `vpulse` keyframe: opacity .35<->.9, scale 1<->1.35, ~1.5s
/// ease-in-out infinite. Used for "analysing" live dots and the
/// in-progress period indicator.
class PulsingDot extends StatelessWidget {
  const PulsingDot({super.key, required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1, end: 1.35, duration: 750.ms, curve: Curves.easeInOut)
        .fadeIn(begin: 0.35, duration: 750.ms, curve: Curves.easeInOut);
  }
}
