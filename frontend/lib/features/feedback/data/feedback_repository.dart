import '../../../core/network/api_client.dart';

class FeedbackRepository {
  FeedbackRepository({required this._apiClient});

  final ApiClient _apiClient;

  /// `feedback_recorded` is true only when [correctedCategory] actually
  /// differs from [originalPrediction] (a real correction, not a
  /// confirmation) - see docs/API_REFERENCE.md §7.
  Future<bool> submit({
    required String transactionId,
    required String originalPrediction,
    required String correctedCategory,
    required double confidence,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/v1/feedback/',
      data: {
        'transaction_id': transactionId,
        'original_prediction': originalPrediction,
        'corrected_category': correctedCategory,
        'confidence': confidence,
      },
    );
    return response.data!['feedback_recorded'] as bool;
  }
}
