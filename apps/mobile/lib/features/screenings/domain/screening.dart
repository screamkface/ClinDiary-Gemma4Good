class RegionalScreeningAvailability {
  const RegionalScreeningAvailability({
    required this.regionCode,
    required this.regionName,
    this.bookingUrl,
    this.notes,
    required this.active,
  });

  final String regionCode;
  final String regionName;
  final String? bookingUrl;
  final String? notes;
  final bool active;

  factory RegionalScreeningAvailability.fromJson(Map<String, dynamic> json) {
    return RegionalScreeningAvailability(
      regionCode: json['region_code'].toString(),
      regionName: json['region_name'].toString(),
      bookingUrl: json['booking_url'] as String?,
      notes: json['notes'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }
}

class ScreeningCatalogItem {
  const ScreeningCatalogItem({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    this.minAge,
    this.maxAge,
    this.targetSex,
    this.intervalMonths,
    required this.publicCoverageFlag,
    required this.category,
    required this.carePathway,
    required this.recommendationLevel,
    this.cadenceLabel,
    required this.catalogOnly,
    this.explanation,
    required this.active,
    required this.regionalAvailability,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final int? minAge;
  final int? maxAge;
  final String? targetSex;
  final int? intervalMonths;
  final bool publicCoverageFlag;
  final String category;
  final String carePathway;
  final String recommendationLevel;
  final String? cadenceLabel;
  final bool catalogOnly;
  final String? explanation;
  final bool active;
  final List<RegionalScreeningAvailability> regionalAvailability;

  factory ScreeningCatalogItem.fromJson(Map<String, dynamic> json) {
    return ScreeningCatalogItem(
      id: json['id'].toString(),
      code: json['code'].toString(),
      name: json['name'].toString(),
      description: json['description'].toString(),
      minAge: json['min_age'] as int?,
      maxAge: json['max_age'] as int?,
      targetSex: json['target_sex'] as String?,
      intervalMonths: json['interval_months'] as int?,
      publicCoverageFlag: json['public_coverage_flag'] as bool? ?? false,
      category: json['category'].toString(),
      carePathway: json['care_pathway']?.toString() ?? 'discuss_with_doctor',
      recommendationLevel: json['recommendation_level']?.toString() ?? 'routine',
      cadenceLabel: json['cadence_label'] as String?,
      catalogOnly: json['catalog_only'] as bool? ?? false,
      explanation: json['explanation'] as String?,
      active: json['active'] as bool? ?? true,
      regionalAvailability:
          (json['regional_availability'] as List<dynamic>? ?? [])
              .map(
                (item) => RegionalScreeningAvailability.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }
}

class PatientScreeningStatusItem {
  const PatientScreeningStatusItem({
    required this.id,
    required this.screeningProgramId,
    required this.screeningCode,
    required this.screeningName,
    required this.screeningCategory,
    required this.carePathway,
    required this.recommendationLevel,
    this.cadenceLabel,
    required this.publicCoverageFlag,
    this.explanation,
    this.recommendationReason,
    this.lastDoneDate,
    this.nextDueDate,
    required this.completedThisYear,
    this.currentYearLastCompletedOn,
    required this.status,
    required this.regionalAvailability,
  });

  final String id;
  final String screeningProgramId;
  final String screeningCode;
  final String screeningName;
  final String screeningCategory;
  final String carePathway;
  final String recommendationLevel;
  final String? cadenceLabel;
  final bool publicCoverageFlag;
  final String? explanation;
  final String? recommendationReason;
  final DateTime? lastDoneDate;
  final DateTime? nextDueDate;
  final bool completedThisYear;
  final DateTime? currentYearLastCompletedOn;
  final String status;
  final List<RegionalScreeningAvailability> regionalAvailability;

  bool get isActionable => status == 'recommended' || status == 'overdue';

  factory PatientScreeningStatusItem.fromJson(Map<String, dynamic> json) {
    return PatientScreeningStatusItem(
      id: json['id'].toString(),
      screeningProgramId: json['screening_program_id'].toString(),
      screeningCode: json['screening_code'].toString(),
      screeningName: json['screening_name'].toString(),
      screeningCategory: json['screening_category'].toString(),
      carePathway: json['care_pathway']?.toString() ?? 'discuss_with_doctor',
      recommendationLevel:
          json['recommendation_level']?.toString() ?? 'routine',
      cadenceLabel: json['cadence_label'] as String?,
      publicCoverageFlag: json['public_coverage_flag'] as bool? ?? false,
      explanation: json['explanation'] as String?,
      recommendationReason: json['recommendation_reason'] as String?,
      lastDoneDate: json['last_done_date'] == null
          ? null
          : DateTime.parse(json['last_done_date'].toString()),
      nextDueDate: json['next_due_date'] == null
          ? null
          : DateTime.parse(json['next_due_date'].toString()),
      completedThisYear: json['completed_this_year'] as bool? ?? false,
      currentYearLastCompletedOn:
          json['current_year_last_completed_on'] == null
          ? null
          : DateTime.parse(json['current_year_last_completed_on'].toString()),
      status: json['status'].toString(),
      regionalAvailability:
          (json['regional_availability'] as List<dynamic>? ?? [])
              .map(
                (item) => RegionalScreeningAvailability.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }
}
