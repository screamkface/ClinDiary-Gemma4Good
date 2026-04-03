import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/features/billing/domain/billing_status.dart';

class BillingRepository {
  BillingRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<BillingStatus> fetchStatus() async {
    final response = await _apiClient.getJson('/api/v1/billing/me');
    return BillingStatus.fromJson(response);
  }

  Future<List<BillingPlan>> fetchPlans() async {
    final response = await _apiClient.getJsonList('/api/v1/billing/plans');
    return response
        .map((item) => BillingPlan.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<BillingStatus> activateDebugPlan(String planCode) async {
    final response = await _apiClient.postJson(
      '/api/v1/billing/dev/activate',
      body: {'plan_code': planCode},
    );
    return BillingStatus.fromJson(response['status'] as Map<String, dynamic>);
  }

  Future<BillingStatus> cancelDebugPlan() async {
    final response = await _apiClient.postJson('/api/v1/billing/dev/cancel');
    return BillingStatus.fromJson(response['status'] as Map<String, dynamic>);
  }
}
