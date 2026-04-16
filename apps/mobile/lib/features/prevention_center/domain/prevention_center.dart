class PreventionCenterOverview {
  const PreventionCenterOverview({
    required this.actionableScreenings,
    required this.vaccineReviews,
    this.vaccineRegistryItems = 0,
    this.pregnancyItems = 0,
    this.sharedDecisionItems = 0,
    required this.seasonalChecks,
    required this.followUpItems,
  });

  final int actionableScreenings;
  final int vaccineReviews;
  final int vaccineRegistryItems;
  final int pregnancyItems;
  final int sharedDecisionItems;
  final int seasonalChecks;
  final int followUpItems;

  factory PreventionCenterOverview.fromJson(Map<String, dynamic> json) {
    return PreventionCenterOverview(
      actionableScreenings: json['actionable_screenings'] as int? ?? 0,
      vaccineReviews: json['vaccine_reviews'] as int? ?? 0,
      vaccineRegistryItems: json['vaccine_registry_items'] as int? ?? 0,
      pregnancyItems: json['pregnancy_items'] as int? ?? 0,
      sharedDecisionItems: json['shared_decision_items'] as int? ?? 0,
      seasonalChecks: json['seasonal_checks'] as int? ?? 0,
      followUpItems: json['follow_up_items'] as int? ?? 0,
    );
  }
}

class PreventionRecommendationItem {
  const PreventionRecommendationItem({
    required this.code,
    required this.title,
    this.subtitle,
    this.reason,
    this.actionHint,
    this.cadenceLabel,
    required this.status,
    required this.priority,
    required this.category,
    required this.kind,
    this.sourceType,
    this.sourceId,
  });

  final String code;
  final String title;
  final String? subtitle;
  final String? reason;
  final String? actionHint;
  final String? cadenceLabel;
  final String status;
  final String priority;
  final String category;
  final String kind;
  final String? sourceType;
  final String? sourceId;

  factory PreventionRecommendationItem.fromJson(Map<String, dynamic> json) {
    return PreventionRecommendationItem(
      code: json['code'].toString(),
      title: json['title'].toString(),
      subtitle: json['subtitle'] as String?,
      reason: json['reason'] as String?,
      actionHint: json['action_hint'] as String?,
      cadenceLabel: json['cadence_label'] as String?,
      status: json['status']?.toString() ?? 'review',
      priority: json['priority']?.toString() ?? 'normal',
      category: json['category']?.toString() ?? 'prevention',
      kind: json['kind']?.toString() ?? 'screening',
      sourceType: json['source_type'] as String?,
      sourceId: json['source_id']?.toString(),
    );
  }
}

class PreventionCenterData {
  const PreventionCenterData({
    required this.generatedAt,
    required this.displayName,
    this.age,
    this.biologicalSex,
    this.regionCode,
    this.regionName,
    required this.overview,
    this.annualVisit,
    required this.visitsAndControls,
    required this.vaccines,
    this.vaccineRegistry = const [],
    this.pregnancyAndPreconception = const [],
    this.sharedDecisions = const [],
    required this.seasonalChecks,
    required this.followUpReminders,
  });

  final DateTime generatedAt;
  final String displayName;
  final int? age;
  final String? biologicalSex;
  final String? regionCode;
  final String? regionName;
  final PreventionCenterOverview overview;
  final PreventionRecommendationItem? annualVisit;
  final List<PreventionRecommendationItem> visitsAndControls;
  final List<PreventionRecommendationItem> vaccines;
  final List<PreventionRecommendationItem> vaccineRegistry;
  final List<PreventionRecommendationItem> pregnancyAndPreconception;
  final List<PreventionRecommendationItem> sharedDecisions;
  final List<PreventionRecommendationItem> seasonalChecks;
  final List<PreventionRecommendationItem> followUpReminders;

  factory PreventionCenterData.fromJson(Map<String, dynamic> json) {
    return PreventionCenterData(
      generatedAt: DateTime.parse(json['generated_at'].toString()),
      displayName: json['display_name']?.toString() ?? 'Clinical profile',
      age: json['age'] as int?,
      biologicalSex: json['biological_sex'] as String?,
      regionCode: json['region_code'] as String?,
      regionName: json['region_name'] as String?,
      overview: PreventionCenterOverview.fromJson(
        json['overview'] as Map<String, dynamic>? ?? const {},
      ),
      annualVisit: json['annual_visit'] == null
          ? null
          : PreventionRecommendationItem.fromJson(
              json['annual_visit'] as Map<String, dynamic>,
            ),
      visitsAndControls:
          (json['visits_and_controls'] as List<dynamic>? ?? [])
              .map(
                (item) => PreventionRecommendationItem.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      vaccines: (json['vaccines'] as List<dynamic>? ?? [])
          .map(
            (item) => PreventionRecommendationItem.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      vaccineRegistry: (json['vaccine_registry'] as List<dynamic>? ?? [])
          .map(
            (item) => PreventionRecommendationItem.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      pregnancyAndPreconception:
          (json['pregnancy_and_preconception'] as List<dynamic>? ?? [])
              .map(
                (item) => PreventionRecommendationItem.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      sharedDecisions: (json['shared_decisions'] as List<dynamic>? ?? [])
          .map(
            (item) => PreventionRecommendationItem.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      seasonalChecks: (json['seasonal_checks'] as List<dynamic>? ?? [])
          .map(
            (item) => PreventionRecommendationItem.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      followUpReminders:
          (json['follow_up_reminders'] as List<dynamic>? ?? [])
              .map(
                (item) => PreventionRecommendationItem.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }
}
