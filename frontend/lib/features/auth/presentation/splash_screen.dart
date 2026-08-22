import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'auth_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Routing off of auth state happens in the router's redirect (see
    // app_router.dart) - this screen is purely the loading visual while
    // authControllerProvider resolves.
    ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.ink900,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentDim]),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text('V', style: AppTypography.amountMedium19.copyWith(color: AppColors.accentInk)),
            ),
            const SizedBox(height: 14),
            Text('Vela', style: AppTypography.wordmark14.copyWith(color: AppColors.onDark)),
            const SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
