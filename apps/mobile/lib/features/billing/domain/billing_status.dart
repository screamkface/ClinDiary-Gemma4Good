class BillingPlan {
  const BillingPlan({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.billingInterval,
    required this.priceCents,
    required this.currency,
    required this.sortOrder,
    this.highlightLabel,
    required this.isActive,
    required this.isPublic,
    required this.isRecommended,
    required this.featureCodes,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final String billingInterval;
  final int priceCents;
  final String currency;
  final int sortOrder;
  final String? highlightLabel;
  final bool isActive;
  final bool isPublic;
  final bool isRecommended;
  final List<String> featureCodes;

  bool get isFree => code == 'free' || priceCents == 0;

  String get formattedPrice {
    if (isFree) {
      return 'Gratis';
    }
    final euros = (priceCents / 100).toStringAsFixed(2).replaceAll('.', ',');
    if (billingInterval == 'yearly') {
      return '$euros $currency / anno';
    }
    return '$euros $currency / mese';
  }

  factory BillingPlan.fromJson(Map<String, dynamic> json) => BillingPlan(
    id: json['id'].toString(),
    code: json['code'].toString(),
    name: json['name'].toString(),
    description: json['description'] as String?,
    billingInterval: json['billing_interval'].toString(),
    priceCents: json['price_cents'] as int? ?? 0,
    currency: json['currency']?.toString() ?? 'EUR',
    sortOrder: json['sort_order'] as int? ?? 0,
    highlightLabel: json['highlight_label'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    isPublic: json['is_public'] as bool? ?? true,
    isRecommended: json['is_recommended'] as bool? ?? false,
    featureCodes: (json['feature_codes'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(),
  );
}

class BillingSubscription {
  const BillingSubscription({
    required this.id,
    required this.provider,
    required this.status,
    required this.autoRenew,
    required this.startedAt,
    required this.currentPeriodStart,
    this.currentPeriodEnd,
    this.canceledAt,
    this.trialEndsAt,
    required this.plan,
  });

  final String id;
  final String provider;
  final String status;
  final bool autoRenew;
  final DateTime startedAt;
  final DateTime currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? canceledAt;
  final DateTime? trialEndsAt;
  final BillingPlan plan;

  factory BillingSubscription.fromJson(Map<String, dynamic> json) =>
      BillingSubscription(
        id: json['id'].toString(),
        provider: json['provider'].toString(),
        status: json['status'].toString(),
        autoRenew: json['auto_renew'] as bool? ?? false,
        startedAt: DateTime.parse(json['started_at'].toString()),
        currentPeriodStart: DateTime.parse(
          json['current_period_start'].toString(),
        ),
        currentPeriodEnd: json['current_period_end'] == null
            ? null
            : DateTime.parse(json['current_period_end'].toString()),
        canceledAt: json['canceled_at'] == null
            ? null
            : DateTime.parse(json['canceled_at'].toString()),
        trialEndsAt: json['trial_ends_at'] == null
            ? null
            : DateTime.parse(json['trial_ends_at'].toString()),
        plan: BillingPlan.fromJson(json['plan'] as Map<String, dynamic>),
      );
}

class BillingStatus {
  const BillingStatus({
    required this.currentPlan,
    required this.availablePlans,
    required this.entitlementCodes,
    required this.hasActivePaidSubscription,
    required this.checkoutReady,
    this.activeSubscription,
  });

  final BillingPlan currentPlan;
  final List<BillingPlan> availablePlans;
  final List<String> entitlementCodes;
  final bool hasActivePaidSubscription;
  final bool checkoutReady;
  final BillingSubscription? activeSubscription;

  bool hasFeature(String featureCode) => entitlementCodes.contains(featureCode);

  factory BillingStatus.fromJson(Map<String, dynamic> json) => BillingStatus(
    currentPlan: BillingPlan.fromJson(
      json['current_plan'] as Map<String, dynamic>,
    ),
    availablePlans: (json['available_plans'] as List<dynamic>? ?? const [])
        .map((item) => BillingPlan.fromJson(item as Map<String, dynamic>))
        .toList(),
    entitlementCodes: (json['entitlement_codes'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(),
    hasActivePaidSubscription:
        json['has_active_paid_subscription'] as bool? ?? false,
    checkoutReady: json['checkout_ready'] as bool? ?? false,
    activeSubscription: json['active_subscription'] == null
        ? null
        : BillingSubscription.fromJson(
            json['active_subscription'] as Map<String, dynamic>,
          ),
  );
}
