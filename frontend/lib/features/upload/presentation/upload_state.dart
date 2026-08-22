import 'package:freezed_annotation/freezed_annotation.dart';

import '../../statements/domain/statement.dart';

part 'upload_state.freezed.dart';

enum UploadStage { idle, uploading, recognized, rejected }

@freezed
abstract class UploadState with _$UploadState {
  const factory UploadState({
    @Default(UploadStage.idle) UploadStage stage,
    String? fileName,
    int? fileSizeBytes,
    @Default(0) double progressPercent,
    String? jobId,
    Statement? statement,
    String? errorMessage,
  }) = _UploadState;
}
