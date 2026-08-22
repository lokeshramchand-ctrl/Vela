import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// Shows [child] as a modal bottom sheet matching the design's sheet spec:
/// radius 28 top corners, drag handle, dark or light surface, heavy/medium
/// scrim depending on [dark].
Future<T?> showVelaSheet<T>(
  BuildContext context, {
  required Widget child,
  bool dark = true,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: dark ? AppColors.scrimHeavy : AppColors.scrimMedium,
    builder: (context) => VelaSheetChrome(dark: dark, child: child),
  );
}

class VelaSheetChrome extends StatelessWidget {
  const VelaSheetChrome({super.key, required this.child, this.dark = true});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          padding: EdgeInsets.fromLTRB(AppSpacing.gutter, 14, AppSpacing.gutter, AppSpacing.lg + viewInsetsBottom),
          decoration: BoxDecoration(
            color: dark ? AppColors.ink850 : AppColors.card,
            border: Border(
              top: BorderSide(color: dark ? AppColors.hairlineDark : AppColors.hairlineLight),
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.hairlineDark : AppColors.hairlineLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(child: SingleChildScrollView(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}
