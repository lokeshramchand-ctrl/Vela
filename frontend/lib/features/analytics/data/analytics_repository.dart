import '../../../core/network/api_client.dart';
import '../domain/analytics_models.dart';

class AnalyticsRepository {
  AnalyticsRepository({required this._apiClient});

  final ApiClient _apiClient;

  Future<List<CategoryPatternEntry>> categoryPatterns({int days = 30}) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/v1/analytics/patterns/categories',
      queryParameters: {'days': days},
    );
    return response.data!.map((e) => CategoryPatternEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<MerchantPatternEntry>> merchantPatterns({int limit = 5}) async {
    final response = await _apiClient.get<List<dynamic>>(
      '/v1/analytics/patterns/merchants',
      queryParameters: {'limit': limit},
    );
    return response.data!.map((e) => MerchantPatternEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SubscriptionsSummary> subscriptions() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/v1/analytics/subscriptions');
    return SubscriptionsSummary.fromJson(response.data!);
  }

  Future<MoMTrend> trendsMoM() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/v1/analytics/trends/mom');
    return MoMTrend.fromJson(response.data!);
  }

  /// API-key only, not JWT/user-scoped - evaluated against the merchant's
  /// global behavioral profile. Query params, not a JSON body.
  Future<AnomalyCheckResult> anomalyCheck({required String merchant, required double amount}) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/v1/analytics/anomaly/check',
      queryParameters: {'merchant': merchant, 'amount': amount},
    );
    return AnomalyCheckResult.fromJson(response.data!);
  }
}
