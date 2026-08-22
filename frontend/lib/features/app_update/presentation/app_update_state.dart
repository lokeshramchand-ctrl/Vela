import '../domain/app_update_info.dart';

enum AppUpdateStage { idle, checking, upToDate, available, downloading, readyToInstall, error }

class AppUpdateState {
  const AppUpdateState({
    this.stage = AppUpdateStage.idle,
    this.info,
    this.progressPercent = 0,
    this.errorMessage,
  });

  final AppUpdateStage stage;
  final AppUpdateInfo? info;
  final double progressPercent;
  final String? errorMessage;

  AppUpdateState copyWith({
    AppUpdateStage? stage,
    AppUpdateInfo? info,
    double? progressPercent,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AppUpdateState(
      stage: stage ?? this.stage,
      info: info ?? this.info,
      progressPercent: progressPercent ?? this.progressPercent,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
