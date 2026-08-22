import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class MiniBarChartEntry {
  const MiniBarChartEntry({required this.label, required this.heightFraction, this.highlighted = false, this.tooltip});
  final String label;
  final double heightFraction; // 0-1
  final bool highlighted;
  final String? tooltip;
}

/// Monthly mini bar chart - translucent bars, one highlighted/current month
/// in solid accent with a floating value tooltip.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({super.key, required this.entries, this.height = 78, this.dark = true});

  final List<MiniBarChartEntry> entries;
  final double height;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in entries)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Stack(
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.none,
                      children: [
                        if (entry.highlighted && entry.tooltip != null)
                          Positioned(
                            top: -22,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(100)),
                              child: Text(entry.tooltip!, style: AppTypography.badge10.copyWith(color: AppColors.accentInk)),
                            ),
                          ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: entry.heightFraction.clamp(0.02, 1),
                            child: Container(
                              decoration: BoxDecoration(
                                color: entry.highlighted ? AppColors.accent : Colors.white.withValues(alpha: 0.14),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ).animate().scaleY(begin: 0, end: 1, alignment: Alignment.bottomCenter, duration: 420.ms, curve: const Cubic(0.2, 0.8, 0.2, 1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final entry in entries)
              Expanded(
                child: Text(
                  entry.label,
                  textAlign: TextAlign.center,
                  style: AppTypography.meta115.copyWith(color: dark ? AppColors.onDarkFaint : AppColors.onLightFaint),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
