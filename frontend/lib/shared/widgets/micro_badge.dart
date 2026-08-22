import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';

/// Small uppercase mono pill tag, e.g. "UNUSUAL", "WATCH", "ANALYSING".
class MicroBadge extends StatelessWidget {
  const MicroBadge({super.key, required this.label, required this.tint, required this.foreground});

  final String label;
  final Color tint;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(100)),
      child: Text(label, style: AppTypography.badge95.copyWith(color: foreground)),
    );
  }
}
