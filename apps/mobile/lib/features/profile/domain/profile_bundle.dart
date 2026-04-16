class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.userId,
    required this.isPrimary,
    this.firstName,
    this.lastName,
    this.birthDate,
    this.biologicalSex,
    this.heightCm,
    this.weightKg,
    required this.smoker,
    this.formerSmoker = false,
    this.smokingPackYears,
    this.yearsSinceQuitting,
    this.alcoholUse,
    this.activityLevel,
    this.postmenopausal = false,
    this.fragilityFractureHistory = false,
    this.fallsLastYear,
    this.feelsUnsteady = false,
    this.sexuallyActive,
    this.newOrMultiplePartners = false,
    this.partnerWithSti = false,
    this.sexWithMen = false,
    this.stiOrExposureConcerns = false,
    this.tryingToConceive = false,
    this.currentlyPregnant = false,
    this.takingFolicAcid = false,
    this.regionCode,
    this.relationshipLabel,
    this.occupation,
    this.exerciseHabits,
    this.sleepPattern,
    this.symptomTriggers,
    this.functionalLimitations,
  });

  final String id;
  final String userId;
  final bool isPrimary;
  final String? firstName;
  final String? lastName;
  final DateTime? birthDate;
  final String? biologicalSex;
  final double? heightCm;
  final double? weightKg;
  final bool smoker;
  final bool formerSmoker;
  final double? smokingPackYears;
  final int? yearsSinceQuitting;
  final String? alcoholUse;
  final String? activityLevel;
  final bool postmenopausal;
  final bool fragilityFractureHistory;
  final int? fallsLastYear;
  final bool feelsUnsteady;
  final bool? sexuallyActive;
  final bool newOrMultiplePartners;
  final bool partnerWithSti;
  final bool sexWithMen;
  final bool stiOrExposureConcerns;
  final bool tryingToConceive;
  final bool currentlyPregnant;
  final bool takingFolicAcid;
  final String? regionCode;
  final String? relationshipLabel;
  final String? occupation;
  final String? exerciseHabits;
  final String? sleepPattern;
  final String? symptomTriggers;
  final String? functionalLimitations;

  String get displayName {
    final parts = [
      firstName,
      lastName,
    ].whereType<String>().where((value) => value.isNotEmpty).toList();
    return parts.isEmpty ? 'Clinical profile' : parts.join(' ');
  }

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      isPrimary: json['is_primary'] as bool? ?? false,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      birthDate: json['birth_date'] == null
          ? null
          : DateTime.parse(json['birth_date'].toString()),
      biologicalSex: json['biological_sex'] as String?,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      smoker: json['smoker'] as bool? ?? false,
      formerSmoker: json['former_smoker'] as bool? ?? false,
      smokingPackYears: (json['smoking_pack_years'] as num?)?.toDouble(),
      yearsSinceQuitting: json['years_since_quitting'] as int?,
      alcoholUse: json['alcohol_use'] as String?,
      activityLevel: json['activity_level'] as String?,
      postmenopausal: json['postmenopausal'] as bool? ?? false,
      fragilityFractureHistory:
          json['fragility_fracture_history'] as bool? ?? false,
      fallsLastYear: json['falls_last_year'] as int?,
      feelsUnsteady: json['feels_unsteady'] as bool? ?? false,
      sexuallyActive: json['sexually_active'] as bool?,
      newOrMultiplePartners:
          json['new_or_multiple_partners'] as bool? ?? false,
      partnerWithSti: json['partner_with_sti'] as bool? ?? false,
      sexWithMen: json['sex_with_men'] as bool? ?? false,
      stiOrExposureConcerns:
          json['sti_or_exposure_concerns'] as bool? ?? false,
      tryingToConceive: json['trying_to_conceive'] as bool? ?? false,
      currentlyPregnant: json['currently_pregnant'] as bool? ?? false,
      takingFolicAcid: json['taking_folic_acid'] as bool? ?? false,
      regionCode: json['region_code'] as String?,
      relationshipLabel: json['relationship_label'] as String?,
      occupation: json['occupation'] as String?,
      exerciseHabits: json['exercise_habits'] as String?,
      sleepPattern: json['sleep_pattern'] as String?,
      symptomTriggers: json['symptom_triggers'] as String?,
      functionalLimitations: json['functional_limitations'] as String?,
    );
  }
}

class OnboardingStatus {
  const OnboardingStatus({
    required this.healthDataConsent,
    this.consentedAt,
    this.aiExternalConsent = false,
    this.aiExternalConsentedAt,
    this.onboardingCompletedAt,
  });

  final bool healthDataConsent;
  final DateTime? consentedAt;
  final bool aiExternalConsent;
  final DateTime? aiExternalConsentedAt;
  final DateTime? onboardingCompletedAt;

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    return OnboardingStatus(
      healthDataConsent: json['health_data_consent'] as bool? ?? false,
      consentedAt: json['consented_at'] == null
          ? null
          : DateTime.parse(json['consented_at'].toString()),
      aiExternalConsent: json['ai_external_consent'] as bool? ?? false,
      aiExternalConsentedAt: json['ai_external_consented_at'] == null
          ? null
          : DateTime.parse(json['ai_external_consented_at'].toString()),
      onboardingCompletedAt: json['onboarding_completed_at'] == null
          ? null
          : DateTime.parse(json['onboarding_completed_at'].toString()),
    );
  }
}

class AllergyItem {
  const AllergyItem({
    required this.id,
    required this.allergen,
    this.severity,
    this.notes,
    this.pendingSync = false,
  });

  final String id;
  final String allergen;
  final String? severity;
  final String? notes;
  final bool pendingSync;

  factory AllergyItem.fromJson(Map<String, dynamic> json) => AllergyItem(
    id: json['id'].toString(),
    allergen: json['allergen'].toString(),
    severity: json['severity'] as String?,
    notes: json['notes'] as String?,
    pendingSync: json['pending_sync'] as bool? ?? false,
  );
}

class MedicalConditionItem {
  const MedicalConditionItem({
    required this.id,
    required this.name,
    this.status,
    this.notes,
    this.diagnosisDate,
    this.pendingSync = false,
  });

  final String id;
  final String name;
  final String? status;
  final String? notes;
  final DateTime? diagnosisDate;
  final bool pendingSync;

  factory MedicalConditionItem.fromJson(Map<String, dynamic> json) =>
      MedicalConditionItem(
        id: json['id'].toString(),
        name: json['name'].toString(),
        status: json['status'] as String?,
        notes: json['notes'] as String?,
        diagnosisDate: json['diagnosis_date'] == null
            ? null
            : DateTime.parse(json['diagnosis_date'].toString()),
        pendingSync: json['pending_sync'] as bool? ?? false,
      );
}

class MedicationItem {
  const MedicationItem({
    required this.id,
    required this.name,
    this.dosage,
    this.frequency,
    this.route,
    this.startDate,
    this.endDate,
    required this.active,
    this.notes,
    required this.schedules,
    this.pendingSync = false,
  });

  final String id;
  final String name;
  final String? dosage;
  final String? frequency;
  final String? route;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool active;
  final String? notes;
  final List<MedicationScheduleItem> schedules;
  final bool pendingSync;

  factory MedicationItem.fromJson(Map<String, dynamic> json) => MedicationItem(
    id: json['id'].toString(),
    name: json['name'].toString(),
    dosage: json['dosage'] as String?,
    frequency: json['frequency'] as String?,
    route: json['route'] as String?,
    startDate: json['start_date'] == null
        ? null
        : DateTime.parse(json['start_date'].toString()),
    endDate: json['end_date'] == null
        ? null
        : DateTime.parse(json['end_date'].toString()),
    active: json['active'] as bool? ?? true,
    notes: json['notes'] as String?,
    schedules: (json['schedules'] as List<dynamic>? ?? [])
        .map(
          (item) =>
              MedicationScheduleItem.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
    pendingSync: json['pending_sync'] as bool? ?? false,
  );
}

class MedicationScheduleItem {
  const MedicationScheduleItem({
    required this.id,
    required this.scheduledTime,
    required this.daysOfWeek,
    this.startDate,
    this.endDate,
    this.cycleDaysOn,
    this.cycleDaysOff,
    this.pausedUntil,
    this.instructions,
    required this.active,
  });

  final String id;
  final String scheduledTime;
  final List<int> daysOfWeek;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? cycleDaysOn;
  final int? cycleDaysOff;
  final DateTime? pausedUntil;
  final String? instructions;
  final bool active;

  String get compactLabel {
    final parts = <String>[scheduledTime];
    if (daysOfWeek.isNotEmpty) {
      parts.add(_weekdaySummary(daysOfWeek));
    }
    if (cycleDaysOn != null && cycleDaysOff != null) {
      parts.add('${cycleDaysOn!} on/${cycleDaysOff!} off');
    }
    if (pausedUntil != null) {
      parts.add('pausa');
    }
    return parts.join(' • ');
  }

  factory MedicationScheduleItem.fromJson(Map<String, dynamic> json) {
    return MedicationScheduleItem(
      id: json['id'].toString(),
      scheduledTime: json['scheduled_time'].toString(),
      daysOfWeek: (json['days_of_week'] as List<dynamic>? ?? [])
          .map((item) => int.parse(item.toString()))
          .toList(),
      startDate: json['start_date'] == null
          ? null
          : DateTime.parse(json['start_date'].toString()),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'].toString()),
      cycleDaysOn: (json['cycle_days_on'] as num?)?.toInt(),
      cycleDaysOff: (json['cycle_days_off'] as num?)?.toInt(),
      pausedUntil: json['paused_until'] == null
          ? null
          : DateTime.parse(json['paused_until'].toString()),
      instructions: json['instructions'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }
}

String _weekdaySummary(List<int> days) {
  const labels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
  return days
      .where((day) => day >= 0 && day < labels.length)
      .map((day) => labels[day])
      .join('/');
}

class FamilyHistoryItem {
  const FamilyHistoryItem({
    required this.id,
    required this.relation,
    required this.conditionName,
    this.notes,
    this.pendingSync = false,
  });

  final String id;
  final String relation;
  final String conditionName;
  final String? notes;
  final bool pendingSync;

  factory FamilyHistoryItem.fromJson(Map<String, dynamic> json) =>
      FamilyHistoryItem(
        id: json['id'].toString(),
        relation: json['relation'].toString(),
        conditionName: json['condition_name'].toString(),
        notes: json['notes'] as String?,
        pendingSync: json['pending_sync'] as bool? ?? false,
      );
}

class VaccinationRecordItem {
  const VaccinationRecordItem({
    required this.id,
    required this.vaccineName,
    this.administeredOn,
    this.doseNumber,
    this.nextDueDate,
    this.providerName,
    this.notes,
    this.pendingSync = false,
  });

  final String id;
  final String vaccineName;
  final DateTime? administeredOn;
  final int? doseNumber;
  final DateTime? nextDueDate;
  final String? providerName;
  final String? notes;
  final bool pendingSync;

  bool get isPlanned => administeredOn == null;

  factory VaccinationRecordItem.fromJson(Map<String, dynamic> json) {
    return VaccinationRecordItem(
      id: json['id'].toString(),
      vaccineName: json['vaccine_name'].toString(),
      administeredOn: json['administered_on'] == null
          ? null
          : DateTime.parse(json['administered_on'].toString()),
      doseNumber: (json['dose_number'] as num?)?.toInt(),
      nextDueDate: json['next_due_date'] == null
          ? null
          : DateTime.parse(json['next_due_date'].toString()),
      providerName: json['provider_name'] as String?,
      notes: json['notes'] as String?,
      pendingSync: json['pending_sync'] as bool? ?? false,
    );
  }
}

class ClinicalEpisodeItem {
  const ClinicalEpisodeItem({
    required this.id,
    required this.title,
    this.summary,
    this.status,
    this.onsetDate,
    this.resolvedDate,
    this.nextReviewDate,
    this.notes,
    this.pendingSync = false,
  });

  final String id;
  final String title;
  final String? summary;
  final String? status;
  final DateTime? onsetDate;
  final DateTime? resolvedDate;
  final DateTime? nextReviewDate;
  final String? notes;
  final bool pendingSync;

  factory ClinicalEpisodeItem.fromJson(Map<String, dynamic> json) {
    return ClinicalEpisodeItem(
      id: json['id'].toString(),
      title: json['title'].toString(),
      summary: json['summary'] as String?,
      status: json['status'] as String?,
      onsetDate: json['onset_date'] == null
          ? null
          : DateTime.parse(json['onset_date'].toString()),
      resolvedDate: json['resolved_date'] == null
          ? null
          : DateTime.parse(json['resolved_date'].toString()),
      nextReviewDate: json['next_review_date'] == null
          ? null
          : DateTime.parse(json['next_review_date'].toString()),
      notes: json['notes'] as String?,
      pendingSync: json['pending_sync'] as bool? ?? false,
    );
  }
}

class ProfileBundle {
  const ProfileBundle({
    required this.profile,
    required this.onboarding,
    required this.allergies,
    required this.medicalConditions,
    required this.medications,
    required this.familyHistory,
    this.managedProfiles = const <PatientProfile>[],
    this.vaccinations = const <VaccinationRecordItem>[],
    this.clinicalEpisodes = const <ClinicalEpisodeItem>[],
  });

  final PatientProfile profile;
  final OnboardingStatus onboarding;
  final List<AllergyItem> allergies;
  final List<MedicalConditionItem> medicalConditions;
  final List<MedicationItem> medications;
  final List<FamilyHistoryItem> familyHistory;
  final List<PatientProfile> managedProfiles;
  final List<VaccinationRecordItem> vaccinations;
  final List<ClinicalEpisodeItem> clinicalEpisodes;

  factory ProfileBundle.fromJson(Map<String, dynamic> json) {
    return ProfileBundle(
      profile: PatientProfile.fromJson(json['profile'] as Map<String, dynamic>),
      onboarding: OnboardingStatus.fromJson(
        json['onboarding'] as Map<String, dynamic>,
      ),
      allergies: (json['allergies'] as List<dynamic>)
          .map((item) => AllergyItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      medicalConditions: (json['medical_conditions'] as List<dynamic>)
          .map(
            (item) =>
                MedicalConditionItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      medications: (json['medications'] as List<dynamic>)
          .map((item) => MedicationItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      familyHistory: (json['family_history'] as List<dynamic>)
          .map(
            (item) => FamilyHistoryItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      managedProfiles: (json['managed_profiles'] as List<dynamic>? ?? [])
          .map((item) => PatientProfile.fromJson(item as Map<String, dynamic>))
          .toList(),
      vaccinations: (json['vaccinations'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                VaccinationRecordItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      clinicalEpisodes: (json['clinical_episodes'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                ClinicalEpisodeItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
