import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/feature_providers.dart';
import 'app_update_state.dart';

final appUpdateControllerProvider = NotifierProvider<AppUpdateController, AppUpdateState>(AppUpdateController.new);

class AppUpdateController extends Notifier<AppUpdateState> {
  CancelToken? _cancelToken;

  @override
  AppUpdateState build() => const AppUpdateState();

  /// Fire-and-forget, called once from AppShell on launch - a broken or
  /// unreachable update check must never interrupt the user's actual
  /// session, so failures are swallowed here rather than surfaced.
  Future<void> checkForUpdate() async {
    if (state.stage == AppUpdateStage.checking) return;
    state = state.copyWith(stage: AppUpdateStage.checking, clearError: true);
    try {
      final repo = ref.read(appUpdateRepositoryProvider);
      final infoFuture = repo.checkForUpdate();
      final currentVersionCode = await repo.currentVersionCode();
      final info = await infoFuture;
      if (info == null || info.versionCode <= currentVersionCode) {
        state = state.copyWith(stage: AppUpdateStage.upToDate);
        return;
      }
      state = state.copyWith(stage: AppUpdateStage.available, info: info);
    } catch (_) {
      state = state.copyWith(stage: AppUpdateStage.idle);
    }
  }

  Future<void> downloadAndInstall() async {
    final info = state.info;
    if (info == null) return;
    _cancelToken = CancelToken();
    state = state.copyWith(stage: AppUpdateStage.downloading, progressPercent: 0, clearError: true);
    try {
      final repo = ref.read(appUpdateRepositoryProvider);
      final path = await repo.downloadApk(
        info,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          state = state.copyWith(progressPercent: received / total * 100);
        },
      );
      state = state.copyWith(stage: AppUpdateStage.readyToInstall);
      await repo.installApk(path);
    } on ApiException catch (e) {
      state = state.copyWith(stage: AppUpdateStage.error, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(stage: AppUpdateStage.error, errorMessage: "Couldn't install the update. Please try again.");
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel('Cancelled by user');
    state = state.copyWith(stage: AppUpdateStage.available);
  }

  void dismiss() => state = const AppUpdateState();
}
