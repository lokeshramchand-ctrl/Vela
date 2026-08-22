import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';

class NavTabSpec {
  const NavTabSpec({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// The 3-tab floating pill bottom nav (Overview / Signals / Activity).
class FloatingBottomNav extends StatelessWidget {
  const FloatingBottomNav({super.key, required this.tabs, required this.currentIndex, required this.onTap});

  final List<NavTabSpec> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppColors.ink900,
        border: Border.all(color: AppColors.hairlineDark),
        borderRadius: BorderRadius.circular(100),
        boxShadow: AppShadows.floatingNav,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++)
            Semantics(
              button: true,
              selected: i == currentIndex,
              excludeSemantics: true,
              label: tabs[i].label,
              child: GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: i == currentIndex ? AppColors.ink700 : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i == currentIndex) ...[
                        Icon(tabs[i].icon, size: 14, color: AppColors.accent),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        tabs[i].label,
                        style: AppTypography.buttonLabel13.copyWith(
                          color: i == currentIndex ? AppColors.onDark : AppColors.onDarkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
