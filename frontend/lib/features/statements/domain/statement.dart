import 'package:freezed_annotation/freezed_annotation.dart';

part 'statement.freezed.dart';
part 'statement.g.dart';

enum ProcessingStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('PROCESSING')
  processing,
  @JsonValue('COMPLETED')
  completed,
  @JsonValue('FAILED')
  failed,
}

@freezed
abstract class Statement with _$Statement {
  const factory Statement({
    required String id,
    required String originalFilename,
    required int fileSizeBytes,
    int? pageCount,
    required DateTime periodStart,
    required DateTime periodEnd,
    double? declaredSentAmount,
    double? declaredReceivedAmount,
    double? computedSentAmount,
    double? computedReceivedAmount,
    bool? reconciliationOk,
    required int transactionCount,
    required ProcessingStatus processingStatus,
    String? currentJobId,
    String? errorMessage,
    required String analyticsVersion,
    required DateTime uploadedAt,
    DateTime? processingCompletedAt,
    int? processingDurationMs,
  }) = _Statement;

  factory Statement.fromJson(Map<String, dynamic> json) => _$StatementFromJson(json);
}

@freezed
abstract class StatementListResponse with _$StatementListResponse {
  const factory StatementListResponse({
    required List<Statement> items,
    required int page,
    required int pageSize,
    required int total,
    required int totalPages,
  }) = _StatementListResponse;

  factory StatementListResponse.fromJson(Map<String, dynamic> json) => _$StatementListResponseFromJson(json);
}

@freezed
abstract class StatementUploadResponse with _$StatementUploadResponse {
  const factory StatementUploadResponse({
    required String statementId,
    required String jobId,
    required ProcessingStatus status,
  }) = _StatementUploadResponse;

  factory StatementUploadResponse.fromJson(Map<String, dynamic> json) => _$StatementUploadResponseFromJson(json);
}
