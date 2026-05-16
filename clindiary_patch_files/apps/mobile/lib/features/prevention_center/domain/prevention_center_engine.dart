import '../../profile/domain/profile_bundle.dart';
import 'prevention_center.dart';
import 'prevention_center_policy.dart';

class PreventionCenterEngine {
  const PreventionCenterEngine();

  PreventionCenterData build(
    ProfileBundle bundle, {
    String regionCode = 'IT',
    DateTime? generatedAt,
  }) {
    final referenceDate = generatedAt ?? DateTime.now().toUtc();
    final age = _ageOn(bundle.profile.birthDate, referenceDate);
    final sex = _normalizedSex(bundle.profile.biologicalSex);
    final isFemale = sex == 'female';
    final isMale = sex == 'male';
    final policy = RegionalPreventionPolicy.forRegion(regionCode);

    final annualVisit = _buildAnnualVisit(bundle, age, sex, referenceDate);
    final annualExams = _buildAnnualExams(
      bundle,
      age,
      sex,
      isFemale,
      isMale,
      policy,
      referenceDate,
    );
    final visitsAndControls = _buildVisitsAndControls(
      bundle,
      age,
      sex,
      isFemale,
      isMale,
      referenceDate,
    );
    final vaccines = _buildVaccines(bundle, age, sex, policy, referenceDate);
    final vaccineRegistry = _buildVaccineRegistry(bundle);
    final pregnancySection = _buildPregnancyItems(
      bundle,
      age,
      sex,
      referenceDate,
    );
    final sharedDecisions = _buildSharedDecisionItems(
      bundle,
      age,
      sex,
      isFemale,
      isMale,
      policy,
      referenceDate,
    );
    final seasonalChecks = _buildSeasonalChecks();
    final followUpItems = _buildFollowUpItems(bundle, referenceDate);

    final actionableScreenings = annualExams.length + visitsAndControls.length;

    return PreventionCenterData(
      generatedAt: referenceDate,
      displayName: bundle.profile.displayName,
      age: age,
      biologicalSex: bundle.profile.biologicalSex,
      regionCode: regionCode,
      regionName: _regionName(regionCode),
      overview: PreventionCenterOverview(
        actionableScreenings: actionableScreenings,
        vaccineReviews: vaccines.length,
        vaccineRegistryItems: vaccineRegistry.length,
        pregnancyItems: pregnancySection.length,
        sharedDecisionItems: sharedDecisions.length,
        seasonalChecks: seasonalChecks.length,
        followUpItems: followUpItems.length,
      ),
      annualVisit: annualVisit,
      annualExams: annualExams,
      visitsAndControls: visitsAndControls,
      vaccines: vaccines,
      vaccineRegistry: vaccineRegistry,
      pregnancyAndPreconception: pregnancySection,
      sharedDecisions: sharedDecisions,
      seasonalChecks: seasonalChecks,
      followUpReminders: followUpItems,
    );
  }

  // ---------------------------------------------------------------------------
  // Section Builders
  // ---------------------------------------------------------------------------

  PreventionRecommendationItem? _buildAnnualVisit(
    ProfileBundle bundle,
    int? age,
    String sex,
    DateTime referenceDate,
  ) {
    return _item(
      code: 'annual_general_visit',
      title: age != null && age < 18
          ? 'Pediatric annual visit'
          : 'Annual preventive visit',
      subtitle: age != null && age < 18
          ? 'Growth, vaccinations and family guidance'
          : 'General preventive review and medication check',
      reason: age != null && age < 18
          ? 'Routine pediatric prevention'
          : 'Yearly preventive coordination for the active profile',
      actionHint: age != null && age < 18
          ? 'Book with the pediatrician'
          : 'Book with the general practitioner or family doctor',
      cadenceLabel: 'Every 12 months',
      status: 'recommended',
      priority: age != null && age >= 65 ? 'high' : 'normal',
      category: 'general_prevention',
      kind: 'visit',
      sourceType: 'profile',
      sourceId: bundle.profile.id,
    );
  }

  List<PreventionRecommendationItem> _buildAnnualExams(
    ProfileBundle bundle,
    int? age,
    String sex,
    bool isFemale,
    bool isMale,
    RegionalPreventionPolicy policy,
    DateTime referenceDate,
  ) {
    final seen = <String>{};
    final items = <PreventionRecommendationItem>[];

    void add(PreventionRecommendationItem item) {
      if (seen.add(item.code) &&
          !_isSuppressedByRecord(bundle, item.code, referenceDate)) {
        items.add(item);
      }
    }

    // TODO: When adding a `hysterectomy` / `cervixPresent` field to the
    // patient profile, skip cervical screening items when the cervix is
    // no longer present. Currently the engine always generates cervical
    // items for age-eligible females.

    // -- Existing items for backward compatibility --
    if (age != null && age >= 18) {
      add(
        _item(
          code: 'annual_blood_pressure_review',
          title: 'Blood pressure and cardiovascular review',
          subtitle: 'Office or home BP plus risk discussion',
          reason: _hasCardiometabolicRisk(bundle)
              ? 'Risk factors or family history support a closer yearly review'
              : 'Annual cardiovascular prevention for adults',
          actionHint:
              'Discuss with your doctor and bring home readings if available',
          cadenceLabel: 'Yearly',
          status: _hasCardiometabolicRisk(bundle) ? 'recommended' : 'review',
          priority: _hasCardiometabolicRisk(bundle) ? 'high' : 'normal',
          category: 'cardiometabolic',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    if (age != null && age >= 35) {
      add(
        _item(
          code: 'annual_cardiology_review',
          title: 'Cardiologist review',
          subtitle: 'ECG and cardiovascular prevention discussion',
          reason: _hasCardiometabolicRisk(bundle)
              ? 'Cardiovascular risk factors justify a yearly cardiology discussion'
              : 'Age-based cardiovascular prevention discussion',
          actionHint:
              'Discuss whether ECG or specialist review is due this year',
          cadenceLabel: 'Yearly',
          status: _hasCardiometabolicRisk(bundle) ? 'recommended' : 'review',
          priority: _hasCardiometabolicRisk(bundle) ? 'high' : 'normal',
          category: 'cardiometabolic',
          kind: 'visit',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    final hasThyroid =
        _hasThyroidRisk(bundle) || (isFemale && age != null && age >= 40);
    if (hasThyroid) {
      add(
        _item(
          code: 'annual_thyroid_review',
          title: 'Thyroid review',
          subtitle: 'TSH or endocrinology discussion',
          reason: _thyroidReason(bundle, age, sex),
          actionHint:
              'Discuss with your clinician whether yearly TSH is useful',
          cadenceLabel: 'Yearly',
          status: 'review',
          priority: 'normal',
          category: 'endocrine',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    final hasAbdominal =
        _hasAbdominalRisk(bundle) ||
        (bundle.profile.smoker && age != null && age >= 60);
    if (hasAbdominal) {
      add(
        _item(
          code: 'annual_abdominal_ultrasound',
          title: 'Abdominal ultrasound',
          subtitle: 'Abdominal aorta and organ review',
          reason: _abdominalReason(bundle, age, sex),
          actionHint:
              'Discuss whether yearly imaging is appropriate for this profile',
          cadenceLabel: 'Yearly',
          status: 'review',
          priority: 'normal',
          category: 'imaging',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    if (age != null && age >= 40) {
      final hasEyeRisk =
          _containsAnyCondition(bundle, const [
            'diabetes',
            'glaucoma',
            'cataract',
            'retinopathy',
            'macular degeneration',
          ]) ||
          _containsAnyFamilyHistory(bundle.familyHistory, const [
            'glaucoma',
            'macular degeneration',
            'retinopathy',
          ]);
      add(
        _item(
          code: 'annual_eye_exam',
          title: 'Eye examination',
          subtitle: hasEyeRisk
              ? 'Vision, ocular pressure and retinal review'
              : 'Vision and ocular pressure review',
          reason: hasEyeRisk
              ? 'Diabetes or eye conditions increase the need for yearly eye review'
              : 'Age-based preventive eye follow-up',
          actionHint: 'Schedule an optometry or ophthalmology check',
          cadenceLabel: 'Yearly',
          status: hasEyeRisk ? 'recommended' : 'review',
          priority: hasEyeRisk ? 'high' : 'low',
          category: 'vision',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    if (age != null &&
        age >= policy.colorectalStartAge &&
        age <= policy.colorectalEndAge) {
      // Keep existing colorectal code for backward compatibility
      add(
        _item(
          code: 'annual_colorectal_screening_discussion',
          title: 'Colorectal screening',
          subtitle: 'FIT / fecal occult blood test pathway',
          reason: 'Age-based colorectal prevention step',
          actionHint:
              'Confirm timing with your clinician or local screening program',
          cadenceLabel: 'Every 2 years',
          status: 'recommended',
          priority: 'high',
          category: 'gastroenterology',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // -- Cancer screenings expanded --

    // Mammography
    for (final item in _buildMammographyItems(bundle, age, isFemale, policy)) {
      add(item);
    }

    // Cervical screening
    if (isFemale && age != null) {
      // HPV-DNA primary screening (≥ cervicalHpvStartAge)
      if (age >= policy.cervicalHpvStartAge && age <= policy.cervicalEndAge) {
        add(
          _item(
            code: 'cervical_hpv_screening',
            title: 'Cervical screening: HPV-DNA test',
            subtitle: null,
            reason: 'Age-based cervical prevention with HPV-DNA testing',
            actionHint:
                'Confirm timing with your clinician or local screening program',
            cadenceLabel: 'Every 5 years',
            status: 'recommended',
            priority: 'high',
            category: 'women_health',
            kind: 'screening',
            sourceType: 'profile',
            sourceId: bundle.profile.id,
          ),
        );
      }
      // Pap test (cervicalPapStartAge up to cervicalHpvStartAge-1)
      if (age >= policy.cervicalPapStartAge &&
          age < policy.cervicalHpvStartAge &&
          age <= policy.cervicalEndAge) {
        add(
          _item(
            code: 'cervical_pap_screening',
            title: 'Cervical screening: Pap test',
            subtitle: null,
            reason: 'Age-based cervical prevention with Pap testing',
            actionHint:
                'Confirm timing with your clinician or local screening program',
            cadenceLabel: 'Every 3 years',
            status: 'recommended',
            priority: 'high',
            category: 'women_health',
            kind: 'screening',
            sourceType: 'profile',
            sourceId: bundle.profile.id,
          ),
        );
      }
    }

    // Colorectal extended / high risk
    if (age != null &&
        age >= 70 &&
        age <= 74 &&
        policy.colorectalExtended70To74) {
      add(
        _item(
          code: 'colorectal_extended_discussion',
          title: 'Colorectal screening — extended range',
          subtitle: null,
          reason: 'Regional programs may extend FIT screening up to age 74',
          actionHint: 'Confirm availability with your local screening program',
          cadenceLabel: 'Regional program dependent',
          status: 'review',
          priority: 'normal',
          category: 'gastroenterology',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    if (_hasColorectalHighRisk(bundle)) {
      add(
        _item(
          code: 'colorectal_high_risk_discussion',
          title: 'Colorectal screening — high risk discussion',
          subtitle: null,
          reason:
              'Personal or family history suggests a high-risk colorectal profile',
          actionHint:
              'Discuss earlier or different screening pathways with your clinician',
          cadenceLabel: 'Risk dependent',
          status: 'review',
          priority: 'high',
          category: 'gastroenterology',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Lung cancer screening
    for (final item in _buildLungCancerItems(
      bundle,
      age,
      policy,
      referenceDate,
    )) {
      add(item);
    }

    // AAA screening
    for (final item in _buildAaaItems(bundle, age, isMale, policy)) {
      add(item);
    }

    // Bone health
    for (final item in _buildBoneHealthItems(bundle, age, isFemale, isMale)) {
      add(item);
    }

    // Infectious disease / lifetime checks
    for (final item in _buildInfectiousDiseaseItems(
      bundle,
      age,
      isFemale,
      isMale,
    )) {
      add(item);
    }

    // STI screening (existing)
    if (_hasStiRisk(bundle)) {
      add(
        _item(
          code: 'annual_sti_screening_discussion',
          title: 'STI screening discussion',
          subtitle: 'Sexual health prevention review',
          reason: 'Profile indicates a non-zero STI prevention discussion need',
          actionHint:
              'Discuss the correct test set and interval with the clinician',
          cadenceLabel: 'Yearly review',
          status: 'review',
          priority: 'normal',
          category: 'sexual_health',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Diabetes screening
    for (final item in _buildDiabetesScreeningItems(bundle, age)) {
      add(item);
    }

    return items;
  }

  List<PreventionRecommendationItem> _buildVisitsAndControls(
    ProfileBundle bundle,
    int? age,
    String sex,
    bool isFemale,
    bool isMale,
    DateTime referenceDate,
  ) {
    final seen = <String>{};
    final items = <PreventionRecommendationItem>[];

    void add(PreventionRecommendationItem item) {
      if (seen.add(item.code) &&
          !_isSuppressedByRecord(bundle, item.code, referenceDate)) {
        items.add(item);
      }
    }

    if (age != null && age >= 18) {
      add(
        _item(
          code: 'annual_bloodwork_review',
          title: 'Basic bloodwork review',
          subtitle: 'Metabolic and organ function discussion',
          reason: 'Age-based yearly prevention review',
          actionHint:
              'Check whether blood tests are due in your routine follow-up',
          cadenceLabel: 'Yearly',
          status: 'review',
          priority: 'normal',
          category: 'laboratory',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    if (bundle.profile.smoker || bundle.profile.formerSmoker) {
      add(
        _item(
          code: 'smoking_counseling',
          title: 'Smoking history review',
          subtitle: 'Risk reduction and lung health discussion',
          reason: bundle.profile.smoker
              ? 'Current smoking increases preventive follow-up needs'
              : 'Former smoking history still matters for prevention',
          actionHint:
              'Discuss cessation support, lung risk and follow-up interval',
          cadenceLabel: 'At each annual visit',
          status: 'review',
          priority: bundle.profile.smoker ? 'high' : 'normal',
          category: 'pulmonary',
          kind: 'visit',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    if (_hasCardiometabolicRisk(bundle)) {
      add(
        _item(
          code: 'metabolic_risk_followup',
          title: 'Cardiometabolic risk follow-up',
          subtitle: 'Lipids, glucose and blood pressure discussion',
          reason: 'Profile or family history suggests a tighter yearly review',
          actionHint: 'Bring recent values if available',
          cadenceLabel: 'Yearly',
          status: 'recommended',
          priority: 'high',
          category: 'cardiometabolic',
          kind: 'visit',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Cardiovascular risk review
    if (age != null && (age >= 40 || _hasCardiometabolicRisk(bundle))) {
      add(
        _item(
          code: 'cardiovascular_risk_review',
          title: 'Cardiovascular risk review',
          subtitle: 'Blood pressure, lipids, glucose and family history',
          reason: _hasCardiometabolicRisk(bundle)
              ? 'Risk factors support a structured yearly review'
              : 'Age-based cardiovascular prevention',
          actionHint: 'Bring recent home BP or lab values if available',
          cadenceLabel: 'Yearly review',
          status: _hasCardiometabolicRisk(bundle) ? 'recommended' : 'review',
          priority: _hasCardiometabolicRisk(bundle) ? 'high' : 'normal',
          category: 'cardiometabolic',
          kind: 'visit',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Lipid profile
    if (age != null && (age >= 40 || _hasCardiometabolicRisk(bundle))) {
      final hasKnownLipidRisk = _hasKnownLipidRisk(bundle);
      add(
        _item(
          code: 'lipid_profile_review',
          title: 'Lipid profile review',
          subtitle: null,
          reason: hasKnownLipidRisk
              ? 'Known dyslipidemia, diabetes, hypertension or smoking supports routine lipid review'
              : 'Age-based lipid prevention discussion',
          actionHint:
              'Discuss fasting or non-fasting lipid testing with your doctor',
          cadenceLabel: 'Risk dependent',
          status: hasKnownLipidRisk ? 'recommended' : 'review',
          priority: hasKnownLipidRisk ? 'high' : 'normal',
          category: 'cardiometabolic',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Basic bloodwork for chronic conditions
    if (_hasConditionOrMedication(bundle)) {
      add(
        _item(
          code: 'basic_bloodwork_review',
          title: 'Basic bloodwork review',
          subtitle: 'Blood count, kidney, liver and metabolic values',
          reason:
              'Chronic conditions or regular medications benefit from yearly lab review',
          actionHint: 'Discuss which tests are appropriate with your clinician',
          cadenceLabel: 'Yearly review',
          status: 'review',
          priority: 'normal',
          category: 'laboratory',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Fall risk review
    if (age != null && age >= 65) {
      final hasFalls =
          bundle.profile.fallsLastYear != null &&
          bundle.profile.fallsLastYear! > 0;
      final unsteady = bundle.profile.feelsUnsteady;
      add(
        _item(
          code: 'fall_risk_review',
          title: 'Fall risk review',
          subtitle: hasFalls || unsteady
              ? 'Previous falls or unsteadiness flagged'
              : 'Age-based fall prevention discussion',
          reason: hasFalls || unsteady
              ? 'Profile indicates increased fall risk'
              : 'Age-based fall prevention discussion',
          actionHint: hasFalls || unsteady
              ? 'Discuss balance, strength and home safety with your clinician'
              : 'Consider discussing fall prevention at your next visit',
          cadenceLabel: 'Yearly',
          status: hasFalls || unsteady ? 'recommended' : 'review',
          priority: hasFalls || unsteady ? 'high' : 'normal',
          category: 'geriatric',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Hearing discussion
    if (age != null && age >= 60) {
      add(
        _item(
          code: 'hearing_review',
          title: 'Hearing check discussion',
          subtitle: null,
          reason: 'Age-related hearing changes become more common after 60',
          actionHint:
              'Discuss hearing concerns or screening with your clinician',
          cadenceLabel: 'Risk dependent',
          status: 'review',
          priority: 'low',
          category: 'ent',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Dental check
    add(
      _item(
        code: 'dental_check_review',
        title: 'Dental check',
        subtitle: null,
        reason: 'Routine dental prevention for all ages',
        actionHint:
            'Schedule a dental check every 6-12 months or as recommended by your dentist',
        cadenceLabel: 'Every 6-12 months',
        status: 'review',
        priority: 'low',
        category: 'dental',
        kind: 'visit',
        sourceType: 'profile',
        sourceId: bundle.profile.id,
      ),
    );

    // Mental health check-in
    add(
      _item(
        code: 'mental_health_checkin',
        title: 'Mental health check-in',
        subtitle: null,
        reason: 'Routine mental health and well-being discussion',
        actionHint:
            'Discuss mood, stress, sleep and mental well-being with your clinician',
        cadenceLabel: 'At annual visit',
        status: 'review',
        priority: 'normal',
        category: 'mental_health',
        kind: 'screening',
        sourceType: 'profile',
        sourceId: bundle.profile.id,
      ),
    );

    return items;
  }

  List<PreventionRecommendationItem> _buildVaccines(
    ProfileBundle bundle,
    int? age,
    String sex,
    RegionalPreventionPolicy policy,
    DateTime referenceDate,
  ) {
    final seen = <String>{};
    final items = <PreventionRecommendationItem>[];

    void add(PreventionRecommendationItem item) {
      if (seen.add(item.code) &&
          !_isSuppressedByRecord(bundle, item.code, referenceDate)) {
        items.add(item);
      }
    }

    // Influenza
    if (_needsInfluenzaReview(bundle, age)) {
      add(
        _item(
          code: 'annual_influenza_review',
          title: 'Seasonal influenza vaccine review',
          subtitle: 'Check the current season coverage',
          reason: 'Yearly vaccine prevention for the active profile',
          actionHint: 'Book before the seasonal campaign ends',
          cadenceLabel: 'Yearly',
          status: 'recommended',
          priority: 'normal',
          category: 'vaccines',
          kind: 'vaccine',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // COVID booster
    if (_needsCovidReview(bundle)) {
      add(
        _item(
          code: 'covid_booster_review',
          title: 'COVID-19 booster review',
          subtitle: 'Check the most recent dose date',
          reason: 'Age or chronic conditions support periodic booster review',
          actionHint: 'Check local guidance for the next booster',
          cadenceLabel: 'Yearly review',
          status: 'review',
          priority: 'normal',
          category: 'vaccines',
          kind: 'vaccine',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // dTpa booster — adult review; keep as review unless an old record is known.
    if (age != null && age >= 18) {
      final dtpaStatus = _dtpaStatus(bundle, referenceDate);
      add(
        _item(
          code: 'dtpa_booster_review',
          title: 'dTpa booster review',
          subtitle: 'Tetanus-diphtheria-pertussis booster',
          reason: dtpaStatus.overdue
              ? 'Last tetanus booster was more than 10 years ago'
              : dtpaStatus.hasRecord
              ? 'Routine adult booster every 10 years'
              : 'No tetanus vaccination record found',
          actionHint:
              'Check your vaccination record and confirm timing with your clinician',
          cadenceLabel: 'Every 10 years',
          status: dtpaStatus.overdue ? 'recommended' : 'review',
          priority: dtpaStatus.overdue ? 'high' : 'normal',
          category: 'vaccines',
          kind: 'vaccine',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Pneumococcal — age 65+ or chronic risk conditions.
    if (age != null && age >= 18) {
      final hasChronicRisk =
          _containsAnyCondition(bundle, const [
            'diabetes',
            'copd',
            'emphysema',
            'chronic bronchitis',
            'heart disease',
            'heart failure',
            'kidney disease',
            'liver disease',
            'immunosuppress',
            'hiv',
            'asplenia',
            'sickle cell',
          ]) ||
          _hasCardiometabolicRisk(bundle);
      if (age >= 65 || hasChronicRisk) {
        add(
          _item(
            code: 'pneumococcal_vaccine_review',
            title: 'Pneumococcal vaccine review',
            subtitle: null,
            reason: hasChronicRisk
                ? 'Chronic conditions can support a pneumococcal vaccine review'
                : 'Age 65+ is a common pneumococcal vaccination threshold',
            actionHint: 'Discuss the appropriate schedule with your clinician',
            cadenceLabel: 'According to schedule',
            status: 'review',
            priority: hasChronicRisk ? 'high' : 'normal',
            category: 'vaccines',
            kind: 'vaccine',
            sourceType: 'profile',
            sourceId: bundle.profile.id,
          ),
        );
      }
    }

    // Herpes Zoster
    if (age != null && age >= 65) {
      add(
        _item(
          code: 'zoster_vaccine_review',
          title: 'Herpes zoster (shingles) vaccine review',
          subtitle: null,
          reason:
              'Age 65+ is the typical eligibility range for zoster vaccination',
          actionHint: 'Discuss timing with your clinician',
          cadenceLabel: 'According to schedule',
          status: 'review',
          priority: 'normal',
          category: 'vaccines',
          kind: 'vaccine',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // HPV vaccine (catch-up)
    if (age != null && age >= 9 && age <= 26) {
      add(
        _item(
          code: 'hpv_vaccine_review',
          title: 'HPV vaccine review',
          subtitle: null,
          reason:
              'HPV vaccination is recommended in adolescence and young adulthood',
          actionHint:
              'Check vaccination history and discuss catch-up if needed',
          cadenceLabel: 'According to schedule',
          status: 'review',
          priority: 'normal',
          category: 'vaccines',
          kind: 'vaccine',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    return items;
  }

  List<PreventionRecommendationItem> _buildVaccineRegistry(
    ProfileBundle bundle,
  ) {
    if (bundle.vaccinations.isEmpty) {
      return const [];
    }
    return [
      _item(
        code: 'registry_sync',
        title: 'Vaccination registry check',
        subtitle: 'Verify completed doses and due dates',
        reason: 'Local records can be compared with the regional registry',
        actionHint: 'Open the vaccination history and confirm missing doses',
        cadenceLabel: 'Yearly',
        status: 'review',
        priority: 'low',
        category: 'registry',
        kind: 'administrative',
        sourceType: 'profile',
        sourceId: bundle.profile.id,
      ),
    ];
  }

  List<PreventionRecommendationItem> _buildPregnancyItems(
    ProfileBundle bundle,
    int? age,
    String sex,
    DateTime referenceDate,
  ) {
    if (!bundle.profile.currentlyPregnant && !bundle.profile.tryingToConceive) {
      return const [];
    }

    final seen = <String>{};
    final items = <PreventionRecommendationItem>[];

    void add(PreventionRecommendationItem item) {
      if (seen.add(item.code) &&
          !_isSuppressedByRecord(bundle, item.code, referenceDate)) {
        items.add(item);
      }
    }

    add(
      _item(
        code: 'pregnancy_preconception_review',
        title: bundle.profile.currentlyPregnant
            ? 'Pregnancy follow-up'
            : 'Preconception review',
        subtitle: 'Obstetric and folic acid discussion',
        reason: bundle.profile.currentlyPregnant
            ? 'Current pregnancy flag is active'
            : 'Trying to conceive is active in the profile',
        actionHint:
            'Discuss timing of visits and supplements with the clinician',
        cadenceLabel: 'Yearly review',
        status: 'recommended',
        priority: 'high',
        category: 'maternal_health',
        kind: 'visit',
        sourceType: 'profile',
        sourceId: bundle.profile.id,
      ),
    );

    add(
      _item(
        code: 'preconception_folic_acid',
        title: 'Folic acid prevention discussion',
        subtitle: null,
        reason: bundle.profile.takingFolicAcid
            ? 'Folic acid is already recorded in the profile'
            : 'Folic acid is commonly reviewed before and during early pregnancy',
        actionHint: bundle.profile.takingFolicAcid
            ? 'Confirm the plan with your clinician'
            : 'Discuss timing with your clinician',
        cadenceLabel: 'At pregnancy/preconception review',
        status: 'review',
        priority: 'normal',
        category: 'maternal_health',
        kind: 'shared_decision',
        sourceType: 'profile',
        sourceId: bundle.profile.id,
      ),
    );

    add(
      _item(
        code: 'pregnancy_medication_review',
        title: 'Medication safety review',
        subtitle: null,
        reason: bundle.profile.currentlyPregnant
            ? 'Review current medications for pregnancy safety'
            : 'Review medications before conception',
        actionHint:
            'Discuss all current medications and supplements with your clinician',
        cadenceLabel: 'At next visit',
        status: 'recommended',
        priority: 'high',
        category: 'maternal_health',
        kind: 'review',
        sourceType: 'profile',
        sourceId: bundle.profile.id,
      ),
    );

    add(
      _item(
        code: 'pregnancy_vaccine_planning',
        title: 'Vaccine planning for pregnancy',
        subtitle: null,
        reason:
            'Influenza, dTpa and COVID-19 vaccines are commonly reviewed during pregnancy',
        actionHint:
            'Discuss vaccination timing and eligibility with your clinician',
        cadenceLabel: 'According to gestational stage',
        status: 'review',
        priority: 'normal',
        category: 'maternal_health',
        kind: 'vaccine',
        sourceType: 'profile',
        sourceId: bundle.profile.id,
      ),
    );

    return items;
  }

  List<PreventionRecommendationItem> _buildSharedDecisionItems(
    ProfileBundle bundle,
    int? age,
    String sex,
    bool isFemale,
    bool isMale,
    RegionalPreventionPolicy policy,
    DateTime referenceDate,
  ) {
    final seen = <String>{};
    final items = <PreventionRecommendationItem>[];

    void add(PreventionRecommendationItem item) {
      if (seen.add(item.code) &&
          !_isSuppressedByRecord(bundle, item.code, referenceDate)) {
        items.add(item);
      }
    }

    // Family history review (existing)
    if (bundle.familyHistory.isNotEmpty) {
      add(
        _item(
          code: 'family_history_review',
          title: 'Family history prevention review',
          subtitle: 'Targets for cardiometabolic and endocrine risk',
          reason: 'Family history changes which annual checks matter most',
          actionHint: 'Review the family history section with the clinician',
          cadenceLabel: 'At annual visit',
          status: 'review',
          priority: 'normal',
          category: 'shared_decision',
          kind: 'shared_decision',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // PSA shared decision (M)
    if (isMale && age != null && age >= 55 && age <= 69) {
      add(
        _item(
          code: 'psa_shared_decision',
          title: 'PSA screening discussion',
          subtitle: null,
          reason: 'PSA screening is an individual decision in this age range',
          actionHint:
              'Discuss benefits, false positives, overdiagnosis and personal risk with your doctor',
          cadenceLabel: 'Shared decision',
          status: 'review',
          priority: 'normal',
          category: 'men_health',
          kind: 'shared_decision',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    if (isMale && age != null && age >= 70) {
      add(
        _item(
          code: 'psa_not_routine_after_70',
          title: 'PSA screening — not routine after 70',
          subtitle: null,
          reason:
              'Routine PSA screening is usually not recommended after age 70',
          actionHint:
              'Discuss testing only if clinically indicated or based on individual risk',
          cadenceLabel: 'Not routine',
          status: 'review',
          priority: 'low',
          category: 'men_health',
          kind: 'shared_decision',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // PSA high-risk discussion for younger men with family history
    if (isMale &&
        age != null &&
        age < 55 &&
        _hasFamilyHistoryProstateRisk(bundle)) {
      add(
        _item(
          code: 'psa_high_risk_discussion',
          title: 'PSA screening — early discussion',
          subtitle: null,
          reason:
              'Family history may suggest discussing earlier PSA screening despite being under 55',
          actionHint:
              'Discuss personal risk, family history and testing timing with your clinician',
          cadenceLabel: 'Risk dependent',
          status: 'review',
          priority: 'normal',
          category: 'men_health',
          kind: 'shared_decision',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Breast high-risk discussion
    if (isFemale && _hasBreastHighRisk(bundle)) {
      add(
        _item(
          code: 'breast_high_risk_screening_discussion',
          title: 'Breast screening — high risk discussion',
          subtitle: null,
          reason:
              'Family or personal history suggests a higher-risk breast profile',
          actionHint:
              'Discuss screening frequency and modality with your clinician',
          cadenceLabel: 'Risk dependent',
          status: 'review',
          priority: 'high',
          category: 'women_health',
          kind: 'shared_decision',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Skin check discussion — not routinely recommended, flagged mostly
    // when there is relevant family history or personal risk.
    if (_containsAnyCondition(bundle, const [
          'skin cancer',
          'melanoma',
          'basal cell',
          'squamous cell',
          'mole',
          'sun damage',
        ]) ||
        _containsAnyFamilyHistory(bundle.familyHistory, const [
          'skin cancer',
          'melanoma',
          'skin',
        ])) {
      add(
        _item(
          code: 'skin_check_discussion',
          title: 'Skin check discussion',
          subtitle: null,
          reason:
              'Family history or personal skin condition may warrant a dermatology discussion',
          actionHint:
              'Discuss skin self-examination and dermatology referral with your clinician',
          cadenceLabel: 'Risk dependent',
          status: 'review',
          priority: 'low',
          category: 'dermatology',
          kind: 'shared_decision',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    return items;
  }

  List<PreventionRecommendationItem> _buildSeasonalChecks() {
    return [
      _item(
        code: 'seasonal_vaccine_review',
        title: 'Seasonal prevention review',
        subtitle: 'Flu, allergy and weather-related follow-up',
        reason: 'Seasonal prevention remains useful year-round',
        actionHint: 'Check the prevention center before the seasonal change',
        cadenceLabel: 'Seasonal',
        status: 'seasonal',
        priority: 'low',
        category: 'seasonal',
        kind: 'monitoring',
        sourceType: 'profile',
        sourceId: 'auto',
      ),
    ];
  }

  List<PreventionRecommendationItem> _buildFollowUpItems(
    ProfileBundle bundle,
    DateTime referenceDate,
  ) {
    final seen = <String>{};
    final items = <PreventionRecommendationItem>[];

    void add(PreventionRecommendationItem item) {
      if (seen.add(item.code) &&
          !_isSuppressedByRecord(bundle, item.code, referenceDate)) {
        items.add(item);
      }
    }

    if (bundle.medicalConditions.isNotEmpty) {
      add(
        _item(
          code: 'condition_followup',
          title: 'Condition follow-up',
          subtitle: 'Review active chronic problems',
          reason: 'Active conditions should be revisited yearly',
          actionHint: 'Open the profile and check open conditions',
          cadenceLabel: 'Yearly',
          status: 'recommended',
          priority: 'normal',
          category: 'follow_up',
          kind: 'follow_up',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    if (bundle.familyHistory.isNotEmpty ||
        bundle.medicalConditions.isNotEmpty) {
      add(
        _item(
          code: 'medication_review',
          title: 'Medication review',
          subtitle: null,
          reason:
              'Active conditions or family history make a medication review useful',
          actionHint: 'Bring your current medication list to your next visit',
          cadenceLabel: 'Yearly',
          status: 'review',
          priority: 'normal',
          category: 'follow_up',
          kind: 'review',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    return items;
  }

  // ---------------------------------------------------------------------------
  // Sub-builders called within section builders
  // ---------------------------------------------------------------------------

  List<PreventionRecommendationItem> _buildMammographyItems(
    ProfileBundle bundle,
    int? age,
    bool isFemale,
    RegionalPreventionPolicy policy,
  ) {
    if (!isFemale || age == null) {
      return const [];
    }

    final items = <PreventionRecommendationItem>[];

    // Core 50-69
    if (age >= policy.mammographyCoreStartAge &&
        age <= policy.mammographyCoreEndAge) {
      items.add(
        _item(
          code: 'mammography_screening',
          title: 'Mammography screening',
          subtitle: null,
          reason:
              'This profile matches a common screening eligibility range for mammography',
          actionHint:
              'Confirm timing with your clinician or local screening program',
          cadenceLabel: 'Every 2 years',
          status: 'recommended',
          priority: 'high',
          category: 'cancer_screening',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Extended 45-49
    if (age >= 45 && age <= 49 && policy.mammographyExtended45To49) {
      items.add(
        _item(
          code: 'mammography_extended_45_49_discussion',
          title: 'Mammography — extended range discussion',
          subtitle: null,
          reason:
              'Regional extension may apply for women aged 45-49; availability depends on the Region',
          actionHint: 'Check with your local screening program or clinician',
          cadenceLabel: 'Regional program dependent',
          status: 'review',
          priority: 'normal',
          category: 'cancer_screening',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Extended 70-74
    if (age >= 70 && age <= 74 && policy.mammographyExtended70To74) {
      items.add(
        _item(
          code: 'mammography_extended_70_74_discussion',
          title: 'Mammography — extended range discussion',
          subtitle: null,
          reason:
              'Regional extension may apply for women aged 70-74; availability depends on the Region',
          actionHint: 'Check with your local screening program or clinician',
          cadenceLabel: 'Regional program dependent',
          status: 'review',
          priority: 'normal',
          category: 'cancer_screening',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    return items;
  }

  List<PreventionRecommendationItem> _buildLungCancerItems(
    ProfileBundle bundle,
    int? age,
    RegionalPreventionPolicy policy,
    DateTime referenceDate,
  ) {
    if (age == null) {
      return const [];
    }

    final profile = bundle.profile;
    final items = <PreventionRecommendationItem>[];
    final inAgeRange =
        age >= policy.lungLdctStartAge && age <= policy.lungLdctEndAge;
    if (!inAgeRange || (!profile.smoker && !profile.formerSmoker)) {
      return items;
    }

    final hasPackYearRisk = _hasSmokingPackYearRisk(bundle);
    final hasPackYearData = profile.smokingPackYears != null;
    final hasQuitData = !profile.formerSmoker || profile.yearsSinceQuitting != null;
    final quitWithinWindow = _quitSmokingWithinYears(
      bundle,
      15,
      referenceDate,
    );

    if (hasPackYearRisk && (profile.smoker || quitWithinWindow)) {
      items.add(
        _item(
          code: 'lung_ldct_screening',
          title: 'Low-dose CT lung screening discussion',
          subtitle: null,
          reason:
              'Smoking history and age match common LDCT screening eligibility criteria',
          actionHint:
              'Discuss benefits and harms of annual LDCT screening with your clinician',
          cadenceLabel: 'Yearly',
          status: 'recommended',
          priority: 'high',
          category: 'cancer_screening',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    } else if (!hasPackYearData || !hasQuitData) {
      items.add(
        _item(
          code: 'lung_risk_data_review',
          title: 'Lung cancer risk — data review',
          subtitle: null,
          reason:
              'Smoking history is recorded but exposure details are incomplete for precise risk assessment',
          actionHint:
              'Ask your clinician whether pack-years and quit date should be recorded',
          cadenceLabel: 'At next visit',
          status: 'review',
          priority: 'normal',
          category: 'cancer_screening',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    return items;
  }

  List<PreventionRecommendationItem> _buildAaaItems(
    ProfileBundle bundle,
    int? age,
    bool isMale,
    RegionalPreventionPolicy policy,
  ) {
    if (age == null) {
      return const [];
    }

    final items = <PreventionRecommendationItem>[];
    final profile = bundle.profile;

    if (isMale &&
        age >= policy.aaaStartAge &&
        age <= policy.aaaEndAge &&
        (profile.smoker || profile.formerSmoker)) {
      items.add(
        _item(
          code: 'aaa_ultrasound_once',
          title: 'Abdominal aortic aneurysm screening',
          subtitle: 'One-time abdominal ultrasound',
          reason:
              'Male smoker aged 65-75 matches common AAA screening eligibility',
          actionHint:
              'Discuss a one-time abdominal ultrasound with your clinician',
          cadenceLabel: 'Once',
          status: 'recommended',
          priority: 'normal',
          category: 'vascular',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    } else if (isMale &&
        age >= policy.aaaStartAge &&
        age <= policy.aaaEndAge &&
        _hasFirstDegreeFamilyHistory(bundle, _aaaRiskTokens)) {
      items.add(
        _item(
          code: 'aaa_family_history_discussion',
          title: 'AAA screening — family history discussion',
          subtitle: null,
          reason:
              'Family history of aortic disease may warrant screening discussion',
          actionHint: 'Discuss risk and screening options with your clinician',
          cadenceLabel: 'Once',
          status: 'review',
          priority: 'normal',
          category: 'vascular',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    return items;
  }

  List<PreventionRecommendationItem> _buildBoneHealthItems(
    ProfileBundle bundle,
    int? age,
    bool isFemale,
    bool isMale,
  ) {
    final items = <PreventionRecommendationItem>[];

    // Backward-compatible item — only for postmenopausal / fragility risk
    // when the more specific `dexa_bone_density` (age >= 65) does NOT apply.
    if (isFemale &&
        age != null &&
        age < 65 &&
        (bundle.profile.postmenopausal || _hasFragilityRisk(bundle)) &&
        !(bundle.profile.postmenopausal && _hasFragilityRisk(bundle))) {
      items.add(
        _item(
          code: 'annual_bone_density_review',
          title: 'Bone density review',
          subtitle: 'DEXA or fracture risk discussion',
          reason: bundle.profile.postmenopausal
              ? 'Postmenopausal profile or fracture history supports bone review'
              : 'Age-based osteoporosis prevention step',
          actionHint: 'Discuss whether a DEXA scan is due',
          cadenceLabel: 'Yearly review',
          status: 'review',
          priority: 'normal',
          category: 'bone_health',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Specific: female 65+ DEXA recommended
    if (isFemale && age != null && age >= 65) {
      items.add(
        _item(
          code: 'dexa_bone_density',
          title: 'Bone density screening',
          subtitle: 'DEXA scan / osteoporosis prevention',
          reason:
              'Age 65+ is a common osteoporosis screening threshold for women',
          actionHint:
              'Confirm timing with your clinician or local screening program',
          cadenceLabel: 'Risk/result dependent',
          status: 'recommended',
          priority: 'normal',
          category: 'bone_health',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Early DEXA for postmenopausal female under 65 with risk
    if (isFemale &&
        age != null &&
        age < 65 &&
        bundle.profile.postmenopausal &&
        _hasFragilityRisk(bundle)) {
      items.add(
        _item(
          code: 'early_dexa_discussion',
          title: 'Early bone density discussion',
          subtitle: null,
          reason:
              'Postmenopausal profile with fragility risk factors may benefit from earlier DEXA',
          actionHint:
              'Discuss benefits and timing of DEXA screening with your clinician',
          cadenceLabel: 'Risk dependent',
          status: 'review',
          priority: _hasSignificantFractureRisk(bundle) ? 'high' : 'normal',
          category: 'bone_health',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Male bone density discussion
    if (isMale &&
        age != null &&
        age >= 65 &&
        (bundle.profile.smoker ||
            bundle.profile.formerSmoker ||
            _hasFragilityRisk(bundle) ||
            _containsAnyMedication(bundle, _boneRiskMedications))) {
      items.add(
        _item(
          code: 'male_bone_density_discussion',
          title: 'Bone density discussion',
          subtitle: null,
          reason:
              'Male profile with risk factors may benefit from bone density assessment',
          actionHint:
              'Discuss risk factors and DEXA screening with your clinician',
          cadenceLabel: 'Risk dependent',
          status: 'review',
          priority: 'normal',
          category: 'bone_health',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    return items;
  }

  List<PreventionRecommendationItem> _buildInfectiousDiseaseItems(
    ProfileBundle bundle,
    int? age,
    bool isFemale,
    bool isMale,
  ) {
    if (age == null) {
      return const [];
    }

    final items = <PreventionRecommendationItem>[];
    final hasActiveStiRisk = _hasStiRisk(bundle);

    // HIV once lifetime (15-65)
    if (age >= 15 && age <= 65) {
      final stiActive = hasActiveStiRisk;
      items.add(
        _item(
          code: 'hiv_once_lifetime',
          title: 'HIV screening',
          subtitle: null,
          reason: stiActive
              ? 'STI risk profile supports routine HIV testing'
              : 'At least once in adulthood; repeat if risk',
          actionHint: 'Discuss screening frequency with your clinician',
          cadenceLabel: stiActive
              ? 'Repeat according to risk'
              : 'At least once',
          status: stiActive ? 'recommended' : 'review',
          priority: 'normal',
          category: 'infectious_disease',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // HCV once lifetime (18-79)
    if (age >= 18 && age <= 79) {
      items.add(
        _item(
          code: 'hcv_once_lifetime',
          title: 'Hepatitis C screening',
          subtitle: null,
          reason: 'Once in adulthood for all adults',
          actionHint: 'Discuss whether you have been tested for Hepatitis C',
          cadenceLabel: 'Once in adulthood',
          status: 'review',
          priority: 'normal',
          category: 'infectious_disease',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // STI screening (expanded)
    if (hasActiveStiRisk) {
      items.add(
        _item(
          code: 'sti_screening_discussion',
          title: 'STI screening discussion',
          subtitle: null,
          reason: 'Sexual health profile indicates STI prevention discussion',
          actionHint:
              'Discuss the correct test set and interval with the clinician',
          cadenceLabel: 'Yearly or according to risk',
          status: 'review',
          priority: 'normal',
          category: 'sexual_health',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    // Chlamydia/gonorrhea for young sexually active females
    if (isFemale && age <= 24 && bundle.profile.sexuallyActive == true) {
      items.add(
        _item(
          code: 'young_woman_sti_screening',
          title: 'Chlamydia and gonorrhea screening discussion',
          subtitle: null,
          reason:
              'Young sexually active women may benefit from STI screening discussion',
          actionHint: 'Discuss screening with your clinician',
          cadenceLabel: 'Yearly or according to risk',
          status: 'review',
          priority: 'normal',
          category: 'sexual_health',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    return items;
  }

  List<PreventionRecommendationItem> _buildDiabetesScreeningItems(
    ProfileBundle bundle,
    int? age,
  ) {
    if (age == null) {
      return const [];
    }

    final items = <PreventionRecommendationItem>[];
    final hasBmiRisk = _hasObesityOrOverweight(bundle);
    final hasDiabetesRisk =
        _containsAnyCondition(bundle, const [
          'diabetes',
          'prediabetes',
          'metabolic',
        ]) ||
        _containsAnyFamilyHistory(bundle.familyHistory, const [
          'diabetes',
          'gestational diabetes',
        ]) ||
        _hasCardiometabolicRisk(bundle);

    if (age >= 35 && age <= 70 && (hasBmiRisk || hasDiabetesRisk)) {
      items.add(
        _item(
          code: 'diabetes_hba1c_screening',
          title: 'Diabetes / HbA1c screening',
          subtitle: null,
          reason: hasBmiRisk
              ? 'Age and BMI range commonly used for diabetes screening'
              : 'Risk factors support diabetes screening discussion',
          actionHint:
              'Discuss HbA1c or fasting glucose testing with your clinician',
          cadenceLabel: 'Risk dependent',
          status: 'recommended',
          priority: 'normal',
          category: 'cardiometabolic',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    } else if (age >= 18 && hasDiabetesRisk) {
      items.add(
        _item(
          code: 'diabetes_risk_discussion',
          title: 'Diabetes risk discussion',
          subtitle: null,
          reason: 'Risk factors suggest diabetes prevention discussion',
          actionHint:
              'Discuss your diabetes risk and screening needs with your clinician',
          cadenceLabel: 'Risk dependent',
          status: 'review',
          priority: 'normal',
          category: 'cardiometabolic',
          kind: 'screening',
          sourceType: 'profile',
          sourceId: bundle.profile.id,
        ),
      );
    }

    return items;
  }

  // ---------------------------------------------------------------------------
  // Risk helpers
  // ---------------------------------------------------------------------------

  bool _hasCardiometabolicRisk(ProfileBundle bundle) {
    final profile = bundle.profile;
    final familyHistory = bundle.familyHistory;
    return profile.smoker ||
        profile.formerSmoker ||
        _containsAnyCondition(bundle, const [
          'hypertension',
          'blood pressure',
          'diabetes',
          'prediabetes',
          'cholesterol',
          'dyslipidemia',
          'cardio',
          'heart',
          'vascular',
          'stroke',
          'myocardial',
          'infarction',
          'coronary',
        ]) ||
        _containsAnyFamilyHistory(familyHistory, const [
          'hypertension',
          'diabetes',
          'cholesterol',
          'dyslipidemia',
          'cardio',
          'heart',
          'stroke',
          'vascular',
          'myocardial',
          'coronary',
        ]);
  }

  bool _hasThyroidRisk(ProfileBundle bundle) {
    return _containsAnyCondition(bundle, const [
          'thyroid',
          'hypothyroid',
          'hyperthyroid',
          'hashimoto',
          'graves',
        ]) ||
        _containsAnyFamilyHistory(bundle.familyHistory, const [
          'thyroid',
          'hypothyroid',
          'hyperthyroid',
          'hashimoto',
          'graves',
        ]) ||
        _containsAnyMedication(bundle, const ['levothyroxine', 'thyroxine']);
  }

  bool _hasAbdominalRisk(ProfileBundle bundle) {
    return bundle.profile.smoker ||
        bundle.profile.formerSmoker ||
        _containsAnyFamilyHistory(bundle.familyHistory, const [
          'aneurysm',
          'aortic',
          'abdominal',
        ]) ||
        _containsAnyCondition(bundle, const [
          'abdominal',
          'liver',
          'hepat',
          'gallbladder',
        ]);
  }

  bool _hasStiRisk(ProfileBundle bundle) {
    final profile = bundle.profile;
    return profile.sexuallyActive == true &&
        (profile.newOrMultiplePartners ||
            profile.partnerWithSti ||
            profile.sexWithMen ||
            profile.stiOrExposureConcerns);
  }

  bool _hasFragilityRisk(ProfileBundle bundle) {
    final profile = bundle.profile;
    return profile.fragilityFractureHistory ||
        (profile.fallsLastYear != null && profile.fallsLastYear! > 0) ||
        profile.feelsUnsteady ||
        _containsAnyCondition(bundle, _boneConditionRiskTokens) ||
        _containsAnyFamilyHistory(
          bundle.familyHistory,
          _boneConditionRiskTokens,
        );
  }

  bool _hasSignificantFractureRisk(ProfileBundle bundle) {
    return bundle.profile.fragilityFractureHistory ||
        _containsAnyCondition(bundle, const [
          'osteoporosis',
          'osteopenia',
          'fragility fracture',
        ]);
  }

  bool _hasColorectalHighRisk(ProfileBundle bundle) {
    return _containsAnyCondition(bundle, _colonHighRiskTokens) ||
        _hasFirstDegreeFamilyHistory(bundle, _colonHighRiskTokens);
  }

  bool _hasBreastHighRisk(ProfileBundle bundle) {
    return _containsAnyCondition(bundle, _breastHighRiskTokens) ||
        _hasFirstDegreeFamilyHistory(bundle, _breastHighRiskTokens);
  }

  bool _hasFamilyHistoryProstateRisk(ProfileBundle bundle) {
    return _hasFirstDegreeFamilyHistory(bundle, const [
      'prostate',
      'prostate cancer',
    ]);
  }

  bool _hasKnownLipidRisk(ProfileBundle bundle) {
    return _containsAnyCondition(bundle, const [
          'diabetes',
          'hypertension',
          'cholesterol',
          'dyslipidemia',
          'cardio',
          'heart',
          'vascular',
          'stroke',
          'coronary',
        ]) ||
        _containsAnyFamilyHistory(bundle.familyHistory, const [
          'cholesterol',
          'dyslipidemia',
          'cardio',
          'heart',
          'stroke',
        ]) ||
        bundle.profile.smoker;
  }

  bool _hasConditionOrMedication(ProfileBundle bundle) {
    return bundle.medicalConditions.isNotEmpty || bundle.medications.isNotEmpty;
  }

bool _hasRecentRecord(
  ProfileBundle bundle,
  List<String> codes,
  DateTime referenceDate,
  Duration maxAge,
) {
  for (final record in bundle.preventionRecords) {
    if (codes.contains(record.code)) {
      final age = referenceDate.difference(record.performedAt);
      if (age <= maxAge) {
        return true;
      }
    }
  }
  return false;
}

bool _hasEverRecord(ProfileBundle bundle, List<String> codes) {
  return bundle.preventionRecords.any(
    (record) => codes.contains(record.code),
  );
}

  bool _hasEverRecord(ProfileBundle bundle, List<String> codes) {
    return bundle.preventionRecords.any((r) => codes.any((c) => r.code == c));
  }

  bool _isSuppressedByRecord(
    ProfileBundle bundle,
    String code,
    DateTime referenceDate,
  ) {
    if (bundle.preventionRecords.isEmpty) return false;
    final maxAge = _cadenceForCode(code);
    return _hasRecentRecord(bundle, [code], referenceDate, maxAge);
  }

  Duration _cadenceForCode(String code) {
    const cadences = <String, int>{
      'mammography_screening': 2,
      'mammography_extended_45_49_discussion': 2,
      'mammography_extended_70_74_discussion': 2,
      'cervical_pap_screening': 3,
      'cervical_hpv_screening': 5,
      'annual_colorectal_screening_discussion': 2,
      'colorectal_extended_discussion': 2,
      'colorectal_high_risk_discussion': 5,
      'dexa_bone_density': 2,
      'early_dexa_discussion': 2,
      'annual_bone_density_review': 2,
      'aaa_ultrasound_once': 100,
      'hiv_once_lifetime': 100,
      'hcv_once_lifetime': 100,
      'lung_ldct_screening': 1,
      'annual_influenza_review': 1,
      'covid_booster_review': 1,
      'dtpa_booster_review': 10,
      'pneumococcal_vaccine_review': 10,
      'zoster_vaccine_review': 10,
      'hpv_vaccine_review': 10,
      'psa_high_risk_discussion': 5,
      'psa_shared_decision': 5,
      'annual_blood_pressure_review': 1,
      'annual_general_visit': 1,
      'annual_eye_exam': 1,
      'annual_cardiology_review': 1,
      'annual_thyroid_review': 1,
      'annual_abdominal_ultrasound': 1,
      'fall_risk_review': 1,
      'hearing_review': 5,
      'metabolic_risk_followup': 1,
      'cardiovascular_risk_review': 1,
      'lipid_profile_review': 1,
      'annual_bloodwork_review': 1,
      'basic_bloodwork_review': 1,
      'diabetes_hba1c_screening': 1,
      'annual_sti_screening_discussion': 1,
      'sti_screening_discussion': 1,
      'lung_risk_data_review': 1,
      'aaa_family_history_discussion': 100,
      'male_bone_density_discussion': 2,
      'diabetes_risk_discussion': 1,
      'young_woman_sti_screening': 1,
      'breast_high_risk_screening_discussion': 1,
      'skin_check_discussion': 1,
      'preconception_folic_acid': 1,
      'pregnancy_medication_review': 1,
      'pregnancy_vaccine_planning': 1,
    };
    final years = cadences[code];
    if (years == null) return const Duration(days: 365 * 100);
    return Duration(days: 365 * years);
  }

  bool _hasFirstDegreeFamilyHistory(ProfileBundle bundle, List<String> tokens) {
    const firstDegree = [
      'father',
      'mother',
      'parent',
      'brother',
      'sister',
      'sibling',
      'child',
      'son',
      'daughter',
      'padre',
      'madre',
      'genitore',
      'fratello',
      'sorella',
      'figlio',
      'figlia',
    ];
    for (final item in bundle.familyHistory) {
      final relation = item.relation.toLowerCase().trim();
      if (!firstDegree.any((d) => relation.contains(d))) {
        continue;
      }
      final haystack = [
        item.relation,
        item.conditionName,
        item.notes,
      ].whereType<String>().join(' ').toLowerCase();
      if (tokens.any(haystack.contains)) {
        return true;
      }
    }
    return false;
  }

  bool _needsInfluenzaReview(ProfileBundle bundle, int? age) {
    if (age == null) {
      return true;
    }
    return age >= 60 ||
        bundle.profile.smoker ||
        _hasCardiometabolicRisk(bundle) ||
        bundle.medicalConditions.isNotEmpty ||
        bundle.profile.currentlyPregnant;
  }

  bool _needsCovidReview(ProfileBundle bundle) {
    return bundle.profile.smoker ||
        _hasCardiometabolicRisk(bundle) ||
        bundle.medicalConditions.isNotEmpty;
  }

  _DtpaStatus _dtpaStatus(ProfileBundle bundle, DateTime referenceDate) {
    // Find the most recent tetanus-containing vaccination with a date
    DateTime? lastAdministered;
    for (final v in bundle.vaccinations) {
      if (v.administeredOn != null &&
          (v.vaccineName.toLowerCase().contains('tetanus') ||
              v.vaccineName.toLowerCase().contains('dtpa') ||
              v.vaccineName.toLowerCase().contains('diphtheria') ||
              v.vaccineName.toLowerCase().contains('tdap'))) {
        if (lastAdministered == null ||
            v.administeredOn!.isAfter(lastAdministered)) {
          lastAdministered = v.administeredOn;
        }
      }
    }

    if (lastAdministered != null) {
      final yearsSinceBooster = _yearsSince(lastAdministered, referenceDate);
      return _DtpaStatus(
        hasRecord: true,
        overdue: yearsSinceBooster > 10,
        lastDate: lastAdministered,
        yearsSince: yearsSinceBooster,
      );
    }

    // Fallback: check if any vaccination record exists with tetanus keywords
    // even without a date — treat as unknown rather than overdue.
    final hasAnyTetanusRecord = bundle.vaccinations.any(
      (v) =>
          v.vaccineName.toLowerCase().contains('tetanus') ||
          v.vaccineName.toLowerCase().contains('dtpa') ||
          v.vaccineName.toLowerCase().contains('diphtheria'),
    );

    return _DtpaStatus(
      hasRecord: hasAnyTetanusRecord,
      overdue: false,
      lastDate: null,
      yearsSince: null,
    );
  }

  // ---------------------------------------------------------------------------
  // Value helpers
  // ---------------------------------------------------------------------------

  double? _bmi(PatientProfile profile) {
    if (profile.heightCm == null || profile.weightKg == null) {
      return null;
    }
    final heightM = profile.heightCm! / 100.0;
    if (heightM <= 0) {
      return null;
    }
    return profile.weightKg! / (heightM * heightM);
  }

  int? _ageOn(DateTime? birthDate, DateTime referenceDate) {
    if (birthDate == null) {
      return null;
    }
    var age = referenceDate.year - birthDate.year;
    final hadBirthdayThisYear =
        referenceDate.month > birthDate.month ||
        (referenceDate.month == birthDate.month &&
            referenceDate.day >= birthDate.day);
    if (!hadBirthdayThisYear) {
      age -= 1;
    }
    return age;
  }

  String _normalizedSex(String? biologicalSex) {
    final value = biologicalSex?.trim().toLowerCase();
    if (value == null || value.isEmpty) {
      return 'unknown';
    }
    if (value.contains('fem')) {
      return 'female';
    }
    if (value.contains('mal')) {
      return 'male';
    }
    return value;
  }

  int _yearsSince(DateTime from, DateTime to) {
    var years = to.year - from.year;
    if (to.month < from.month ||
        (to.month == from.month && to.day < from.day)) {
      years -= 1;
    }
    return years;
  }

  bool _hasObesityOrOverweight(ProfileBundle bundle) {
    final bmi = _bmi(bundle.profile);
    return bmi != null && bmi >= 25;
  }

  bool _hasSmokingPackYearRisk(ProfileBundle bundle, {double threshold = 20}) {
    final packYears = bundle.profile.smokingPackYears;
    return packYears != null && packYears >= threshold;
  }

  bool _quitSmokingWithinYears(
    ProfileBundle bundle,
    int years,
    DateTime referenceDate,
  ) {
    final profile = bundle.profile;
    if (!profile.formerSmoker) return false;
    if (profile.yearsSinceQuitting != null) {
      return profile.yearsSinceQuitting! <= years;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Text helpers
  // ---------------------------------------------------------------------------

  String _thyroidReason(ProfileBundle bundle, int? age, String sex) {
    if (_hasThyroidRisk(bundle)) {
      return 'Profile history or medication list suggests thyroid follow-up';
    }
    if (age != null && age >= 40 && sex == 'female') {
      return 'Age-based preventive thyroid discussion for the active profile';
    }
    return 'Yearly thyroid discussion to confirm whether testing is useful';
  }

  String _abdominalReason(ProfileBundle bundle, int? age, String sex) {
    if (_containsAnyFamilyHistory(bundle.familyHistory, const [
      'aneurysm',
      'aortic',
    ])) {
      return 'Family history supports abdominal/aortic prevention discussion';
    }
    if (bundle.profile.smoker || bundle.profile.formerSmoker) {
      return 'Smoking history can justify abdominal imaging discussion';
    }
    if (age != null && age >= 65) {
      return 'Age-based abdominal prevention discussion';
    }
    return 'Discuss whether abdominal imaging is useful for this profile';
  }

  String _regionName(String regionCode) {
    if (regionCode.toUpperCase() == 'IT') {
      return 'Italy';
    }
    return regionCode;
  }

  // ---------------------------------------------------------------------------
  // Token matching helpers
  // ---------------------------------------------------------------------------

  bool _containsAnyCondition(ProfileBundle bundle, List<String> tokens) {
    for (final condition in bundle.medicalConditions) {
      final haystack = [
        condition.name,
        condition.status,
        condition.notes,
      ].whereType<String>().join(' ').toLowerCase();
      if (tokens.any(haystack.contains)) {
        return true;
      }
    }
    return false;
  }

  bool _containsAnyFamilyHistory(
    List<FamilyHistoryItem> familyHistory,
    List<String> tokens,
  ) {
    for (final item in familyHistory) {
      final haystack = [
        item.relation,
        item.conditionName,
        item.notes,
      ].whereType<String>().join(' ').toLowerCase();
      if (tokens.any(haystack.contains)) {
        return true;
      }
    }
    return false;
  }

  bool _containsAnyMedication(ProfileBundle bundle, List<String> tokens) {
    for (final medication in bundle.medications) {
      final haystack = [
        medication.name,
        medication.dosage,
        medication.frequency,
        medication.route,
        medication.notes,
      ].whereType<String>().join(' ').toLowerCase();
      if (tokens.any(haystack.contains)) {
        return true;
      }
    }
    return false;
  }

  PreventionRecommendationItem _item({
    required String code,
    required String title,
    String? subtitle,
    String? reason,
    String? actionHint,
    String? cadenceLabel,
    required String status,
    required String priority,
    required String category,
    required String kind,
    String? sourceType,
    String? sourceId,
  }) {
    return PreventionRecommendationItem(
      code: code,
      title: title,
      subtitle: subtitle,
      reason: reason,
      actionHint: actionHint,
      cadenceLabel: cadenceLabel,
      status: status,
      priority: priority,
      category: category,
      kind: kind,
      sourceType: sourceType,
      sourceId: sourceId,
    );
  }

  // ---------------------------------------------------------------------------
  // Token lists
  // ---------------------------------------------------------------------------

  static const _boneRiskMedications = [
    'steroid',
    'prednisone',
    'cortisone',
    'dexamethasone',
  ];

  static const _boneConditionRiskTokens = [
    'osteoporosis',
    'osteopenia',
    'fracture',
    'fragility',
    'menopause',
  ];

  static const _colonHighRiskTokens = [
    'colorectal',
    'colon cancer',
    'bowel cancer',
    'polyps',
    'inflammatory bowel disease',
    'ulcerative colitis',
    'crohn',
    'familial adenomatous',
    'lynch',
  ];

  static const _breastHighRiskTokens = [
    'breast cancer',
    'brca',
    'ovarian cancer',
    'genetic mutation',
    'her2',
  ];

  static const _aaaRiskTokens = [
    'aneurysm',
    'aortic',
    'abdominal aortic aneurysm',
    'aaa',
  ];

  static const _pulmonaryRiskTokens = [
    'copd',
    'emphysema',
    'chronic bronchitis',
    'pulmonary',
    'lung disease',
  ];
}

class _DtpaStatus {
  final bool hasRecord;
  final bool overdue;
  final DateTime? lastDate;
  final int? yearsSince;

  const _DtpaStatus({
    required this.hasRecord,
    required this.overdue,
    this.lastDate,
    this.yearsSince,
  });
}
