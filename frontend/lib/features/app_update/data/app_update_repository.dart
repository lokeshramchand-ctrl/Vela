import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/app_update_info.dart';

class AppUpdateRepository {
  AppUpdateRepository({required this._apiClient});

  final ApiClient _apiClient;

  /// Null means "nothing published yet" (backend 404s) - not an error, since
  /// that's the expected state before the first release ever goes out.
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/app/latest-version');
      return AppUpdateInfo.fromJson(response.data!);
    } on ApiHttpException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Android's versionCode - the same integer the backend compares against
  /// as version_code. package_info_plus surfaces it as buildNumber (a
  /// String) on every platform since iOS's equivalent, CFBundleVersion, is
  /// not always numeric.
  Future<int> currentVersionCode() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  Future<String> downloadApk(
    AppUpdateInfo info, {
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/velar-update-${info.versionCode}.apk';
    try {
      await _apiClient.dio.download(
        info.downloadUrl,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw apiExceptionFromDioError(e);
    }
    return savePath;
  }

  /// Hands off to Android's own package installer via open_filex (bundles
  /// its own FileProvider - no manifest wiring needed beyond
  /// REQUEST_INSTALL_PACKAGES, see AndroidManifest.xml). Android still shows
  /// its own "install unknown app" confirmation - nothing here bypasses that.
  /// Throws if the OS couldn't launch the installer at all (e.g. the user
  /// has never granted "install unknown apps" for this app and denied the
  /// resulting settings prompt) so the caller can show a real error instead
  /// of silently doing nothing.
  Future<void> installApk(String path) async {
    final result = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }
}
