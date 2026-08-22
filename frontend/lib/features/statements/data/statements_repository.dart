import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/insight.dart';
import '../domain/statement.dart';
import '../domain/statement_analytics.dart';
import '../domain/transaction.dart';

class StatementsRepository {
  StatementsRepository({required this._apiClient});

  final ApiClient _apiClient;

  Future<StatementUploadResponse> upload({
    required String filePath,
    required String filename,
    String? password,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
      if (password != null && password.isNotEmpty) 'password': password,
    });
    final response = await _apiClient.upload<Map<String, dynamic>>(
      '/statements/upload',
      formData: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
    return StatementUploadResponse.fromJson(response.data!);
  }

  Future<StatementListResponse> list({
    int page = 1,
    int pageSize = 20,
    ProcessingStatus? processingStatus,
    String sortBy = 'uploaded_at',
    String sortOrder = 'desc',
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/statements',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (processingStatus != null) 'processing_status': _statusToJson(processingStatus),
        'sort_by': sortBy,
        'sort_order': sortOrder,
      },
    );
    return StatementListResponse.fromJson(response.data!);
  }

  Future<Statement> get(String statementId) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/statements/$statementId');
    return Statement.fromJson(response.data!);
  }

  Future<void> delete(String statementId) => _apiClient.delete('/statements/$statementId');

  Future<TransactionListResponse> transactions(
    String statementId, {
    int page = 1,
    int pageSize = 20,
    String? category,
    TransactionType? transactionType,
    String? merchant,
    DateTime? startDate,
    DateTime? endDate,
    String sortBy = 'timestamp',
    String sortOrder = 'desc',
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/statements/$statementId/transactions',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'category': ?category,
        if (transactionType != null) 'transaction_type': transactionType == TransactionType.debit ? 'DEBIT' : 'CREDIT',
        'merchant': ?merchant,
        if (startDate != null) 'start_date': _dateOnly(startDate),
        if (endDate != null) 'end_date': _dateOnly(endDate),
        'sort_by': sortBy,
        'sort_order': sortOrder,
      },
    );
    return TransactionListResponse.fromJson(response.data!);
  }

  Future<StatementAnalytics> analytics(String statementId) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/statements/$statementId/analytics');
    return StatementAnalytics.fromJson(response.data!);
  }

  Future<StatementInsightsResponse> insights(String statementId) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/statements/$statementId/insights');
    return StatementInsightsResponse.fromJson(response.data!);
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _statusToJson(ProcessingStatus status) => switch (status) {
        ProcessingStatus.pending => 'PENDING',
        ProcessingStatus.processing => 'PROCESSING',
        ProcessingStatus.completed => 'COMPLETED',
        ProcessingStatus.failed => 'FAILED',
      };
}
