import 'package:clindiary/app/core/network/api_client.dart';
import 'package:clindiary/features/billing/domain/billing_status.dart';

class BillingRepository {
  BillingRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<BillingStatus> fetchStatus() async {
    try {
      final response = await _apiClient.getJson('/api/v1/billing/me');
      return BillingStatus.fromJson(response);
    } on ApiException catch (error) {
      if (_isLocalOnlyError(error)) {
        return BillingStatus.fromJson(_statusForPlan('ai_plus_yearly'));
      }
      rethrow;
    }
  }

  Future<List<BillingPlan>> fetchPlans() async {
    try {
      final response = await _apiClient.getJsonList('/api/v1/billing/plans');
      return response
          .map((item) => BillingPlan.fromJson(item as Map<String, dynamic>))
          .toList();
    } on ApiException catch (error) {
      if (_isLocalOnlyError(error)) {
        final plans = _defaultPlansJson();
        return plans.map(BillingPlan.fromJson).toList();
      }
      rethrow;
    }
  }

  Future<BillingStatus> activateDebugPlan(String planCode) async {
    try {
      final response = await _apiClient.postJson(
        '/api/v1/billing/dev/activate',
        body: {'plan_code': planCode},
      );
      return BillingStatus.fromJson(response['status'] as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (_isLocalOnlyError(error)) {
        return BillingStatus.fromJson(_statusForPlan(planCode));
      }
      rethrow;
    }
  }

  Future<BillingStatus> cancelDebugPlan() async {
    try {
      final response = await _apiClient.postJson('/api/v1/billing/dev/cancel');
      return BillingStatus.fromJson(response['status'] as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (_isLocalOnlyError(error)) {
        return BillingStatus.fromJson(_statusForPlan('free'));
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> _defaultPlansJson() {
    return const <Map<String, dynamic>>[
      {
        'id': 'plan-free',
        'code': 'free',
        'name': 'Free',
        'description': 'Local-only mode',
        'billing_interval': 'monthly',
        'price_cents': 0,
        'currency': 'EUR',
        'sort_order': 0,
        'highlight_label': null,
        'is_active': true,
        'is_public': true,
        'is_recommended': false,
        'feature_codes': <String>[],
      },
      {
        'id': 'plan-pro',
        'code': 'ai_plus_yearly',
        'name': 'AI Plus Annual',
        'description': 'Full AI feature set for demo',
        'billing_interval': 'yearly',
        'price_cents': 9900,
        'currency': 'EUR',
        'sort_order': 1,
        'highlight_label': 'Recommended',
        'is_active': true,
        'is_public': true,
        'is_recommended': true,
        'feature_codes': <String>[
          'cloud_document_storage',
          'ai_document_query',
          'advanced_reports',
        ],
      },
    ];
  }

  Map<String, dynamic> _statusForPlan(String planCode) {
    final plans = _defaultPlansJson()
        .map((plan) => Map<String, dynamic>.from(plan))
        .toList();
    final currentPlan = plans.firstWhere(
      (plan) => plan['code']?.toString() == planCode,
      orElse: () => plans.first,
    );
    final entitlementCodes =
        (currentPlan['feature_codes'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => item.toString())
            .toList();
    final priceCents = currentPlan['price_cents'] as int? ?? 0;

    return {
      'current_plan': currentPlan,
      'available_plans': plans,
      'entitlement_codes': entitlementCodes,
      'has_active_paid_subscription': priceCents > 0,
      'checkout_ready': true,
      'hackathon_demo_mode': true,
      'active_subscription': null,
    };
  }

  bool _isLocalOnlyError(ApiException error) => error.code == 'local_only_mode';
}
