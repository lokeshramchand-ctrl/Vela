import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../../features/app_update/presentation/app_update_controller.dart';
import '../../features/app_update/presentation/app_update_sheet.dart';
import '../../features/app_update/presentation/app_update_state.dart';
import '../../shared/widgets/floating_bottom_nav.dart';

/// Hosts the 3-tab shell (Overview/Signals/Activity) with the design's
/// floating pill nav absolutely positioned over the content, matching the
/// mock rather than a standard Material BottomNavigationBar.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _tabs = [
    NavTabSpec(label: 'Overview', icon: Icons.dashboard_outlined),
    NavTabSpec(label: 'Signals', icon: Icons.bolt_outlined),
    NavTabSpec(label: 'Activity', icon: Icons.receipt_long_outlined),
  ];

  @override
  void initState() {
    super.initState();
    // Fire-and-forget, once per app launch (this shell is only ever built
    // once - go_router keeps it alive across tab switches). Never blocks
    // navigation: the check runs after the first frame and only surfaces a
    // sheet if it finds something newer than the installed build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appUpdateControllerProvider.notifier).checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appUpdateControllerProvider, (previous, next) {
      if (next.stage == AppUpdateStage.available && previous?.stage != AppUpdateStage.available) {
        showAppUpdateSheet(context);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          Positioned.fill(child: widget.navigationShell),
          Positioned(
            left: 22,
            right: 22,
            bottom: 12 + MediaQuery.of(context).padding.bottom,
            child: Center(
              child: FloatingBottomNav(
                tabs: _tabs,
                currentIndex: widget.navigationShell.currentIndex,
                onTap: (index) => widget.navigationShell.goBranch(index, initialLocation: index == widget.navigationShell.currentIndex),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
