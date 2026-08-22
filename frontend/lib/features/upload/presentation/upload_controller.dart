import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/feature_providers.dart';
import '../../statements/presentation/period_providers.dart';
import 'upload_state.dart';

final uploadControllerProvider = NotifierProvider<UploadController, UploadState>(UploadController.new);

class UploadController extends Notifier<UploadState> {
  CancelToken? _cancelToken;
  String? _lastPath;
  String? _lastName;
  int? _lastSize;

  @override
  UploadState build() => const UploadState();

  Future<void> pickAndUpload() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null) return;
    _lastPath = file.path;
    _lastName = file.name;
    _lastSize = file.size;
    await _upload(path: file.path!, name: file.name, sizeBytes: file.size);
  }

  Future<void> retryWithPassword(String password) async {
    if (_lastPath == null || _lastName == null) return;
    await _upload(path: _lastPath!, name: _lastName!, sizeBytes: _lastSize ?? 0, password: password);
  }

  Future<void> _upload({required String path, required String name, required int sizeBytes, String? password}) async {
    _cancelToken = CancelToken();
    state = state.copyWith(
      stage: UploadStage.uploading,
      fileName: name,
      fileSizeBytes: sizeBytes,
      progressPercent: 0,
      errorMessage: null,
    );
    try {
      final repo = ref.read(statementsRepositoryProvider);
      final response = await repo.upload(
        filePath: path,
        filename: name,
        password: password,
        cancelToken: _cancelToken,
        onSendProgress: (sent, total) {
          if (total <= 0) return;
          state = state.copyWith(progressPercent: sent / total * 100);
        },
      );
      final statement = await repo.get(response.statementId);
      state = state.copyWith(stage: UploadStage.recognized, jobId: response.jobId, statement: statement);
      ref.invalidate(periodsProvider);
    } on ApiException catch (e) {
      if (e is ApiHttpException && e.statusCode == 413) {
        state = state.copyWith(stage: UploadStage.rejected, errorMessage: 'This file is too large - Vela accepts statements up to 10MB.');
        return;
      }
      state = state.copyWith(stage: UploadStage.rejected, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(stage: UploadStage.rejected, errorMessage: 'Something went wrong. Please try again.');
    }
  }

  void cancel() {
    _cancelToken?.cancel('Cancelled by user');
    state = const UploadState();
  }

  void reset() => state = const UploadState();

  bool get looksLikePasswordIssue => (state.errorMessage ?? '').toLowerCase().contains('password');
}
