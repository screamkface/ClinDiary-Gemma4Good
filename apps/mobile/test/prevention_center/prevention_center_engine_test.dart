import 'package:clindiary/features/prevention_center/domain/prevention_center_engine.dart';
import 'package:clindiary/features/prevention_center/domain/prevention_record.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final refDate = DateTime.utc(2026, 5, 14, 9);
  final engine = PreventionCenterEngine();

  ProfileBundle _bundle({
    required String id,
    required String firstName,
    required String lastName,
    required DateTime? birthDate,
    required String biologicalSex,
    bool smoker = false,
    bool formerSmoker = false,
    double? smokingPackYears,
    int? yearsSinceQuitting,
    bool postmenopausal = false,
    bool fragilityFractureHistory = false,
    int? fallsLastYear,
    bool feelsUnsteady = false,
    bool? sexuallyActive,
    bool newOrMultiplePartners = false,
    bool partnerWithSti = false,
    bool sexWithMen = false,
    bool stiOrExposureConcerns = false,
    bool tryingToConceive = false,
    bool currentlyPregnant = false,
    bool takingFolicAcid = false,
    double? heightCm,
    double? weightKg,
    List<MedicalConditionItem> medicalConditions = const [],
    List<MedicationItem> medications = const [],
    List<FamilyHistoryItem> familyHistory = const [],
    List<VaccinationRecordItem> vaccinations = const [],
    List<ClinicalEpisodeItem> clinicalEpisodes = const [],
  }) {
    return ProfileBundle(
      profile: PatientProfile(
        id: id,
        userId: 'user-1',
        isPrimary: true,
        firstName: firstName,
        lastName: lastName,
        birthDate: birthDate,
        biologicalSex: biologicalSex,
        smoker: smoker,
        formerSmoker: formerSmoker,
        smokingPackYears: smokingPackYears,
        yearsSinceQuitting: yearsSinceQuitting,
        postmenopausal: postmenopausal,
        fragilityFractureHistory: fragilityFractureHistory,
        fallsLastYear: fallsLastYear,
        feelsUnsteady: feelsUnsteady,
        sexuallyActive: sexuallyActive,
        newOrMultiplePartners: newOrMultiplePartners,
        partnerWithSti: partnerWithSti,
        sexWithMen: sexWithMen,
        stiOrExposureConcerns: stiOrExposureConcerns,
        tryingToConceive: tryingToConceive,
        currentlyPregnant: currentlyPregnant,
        takingFolicAcid: takingFolicAcid,
        heightCm: heightCm,
        weightKg: weightKg,
      ),
      onboarding: const OnboardingStatus(healthDataConsent: true),
      allergies: const [],
      medicalConditions: medicalConditions,
      medications: medications,
      familyHistory: familyHistory,
      vaccinations: vaccinations,
      clinicalEpisodes: clinicalEpisodes,
    );
  }

  Set<String> _codes(List<dynamic> items) {
    return items.map((e) => (e as dynamic).code as String).toSet();
  }

  group('Backward compatibility', () {
    test('keeps existing item codes for a 68-year-old female profile', () {
      final bundle = ProfileBundle(
        profile: PatientProfile(
          id: 'profile-1',
          userId: 'user-1',
          isPrimary: true,
          firstName: 'Anna',
          lastName: 'Rossi',
          birthDate: DateTime.utc(1958, 5, 14),
          biologicalSex: 'female',
          smoker: false,
          formerSmoker: true,
          smokingPackYears: 8,
          yearsSinceQuitting: 20,
          postmenopausal: true,
          fragilityFractureHistory: false,
          fallsLastYear: 1,
          feelsUnsteady: false,
          sexuallyActive: false,
          newOrMultiplePartners: false,
          partnerWithSti: false,
          sexWithMen: false,
          stiOrExposureConcerns: false,
          tryingToConceive: false,
          currentlyPregnant: false,
          takingFolicAcid: false,
        ),
        onboarding: const OnboardingStatus(healthDataConsent: true),
        allergies: const [],
        medicalConditions: const [
          MedicalConditionItem(
            id: 'cond-1',
            name: 'Hypertension',
            status: 'active',
          ),
        ],
        medications: const [],
        familyHistory: const [
          FamilyHistoryItem(
            id: 'fam-1',
            relation: 'Mother',
            conditionName: 'Thyroid disease',
          ),
          FamilyHistoryItem(
            id: 'fam-2',
            relation: 'Father',
            conditionName: 'Aortic aneurysm',
          ),
        ],
        vaccinations: const [],
        clinicalEpisodes: const [],
      );

      final center = engine.build(bundle, generatedAt: refDate);

      expect(center.age, 68);
      expect(center.annualVisit, isNotNull);
      expect(_codes(center.annualExams), contains('annual_cardiology_review'));
      expect(_codes(center.annualExams), contains('annual_thyroid_review'));
      expect(
        _codes(center.annualExams),
        contains('annual_abdominal_ultrasound'),
      );
      expect(_codes(center.annualExams), contains('dexa_bone_density'));
      expect(
        _codes(center.annualExams),
        contains('annual_colorectal_screening_discussion'),
      );
      expect(
        _codes(center.annualExams),
        isNot(contains('annual_cervical_screening_discussion')),
      );
    });
  });

  group('Cancro screenings', () {
    test('Female age 52 in Italy: mammography, cervical HPV, colorectal', () {
      final bundle = _bundle(
        id: 'p1',
        firstName: 'Maria',
        lastName: 'Bianchi',
        birthDate: DateTime.utc(1974, 3, 10),
        biologicalSex: 'female',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);

      expect(center.age, 52);
      expect(codes, contains('mammography_screening'));
      expect(codes, contains('cervical_hpv_screening'));
      expect(codes, contains('annual_colorectal_screening_discussion'));
      expect(codes, isNot(contains('psa_shared_decision')));
      expect(codes, isNot(contains('psa_not_routine_after_70')));
      expect(codes, isNot(contains('mammography_extended_45_49_discussion')));
      expect(codes, isNot(contains('mammography_extended_70_74_discussion')));
    });

    test('Female age 47 in Italy: mammography extended discussion', () {
      final bundle = _bundle(
        id: 'p2',
        firstName: 'Sofia',
        lastName: 'Verdi',
        birthDate: DateTime.utc(1979, 3, 10),
        biologicalSex: 'female',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);

      expect(center.age, 47);
      expect(codes, contains('mammography_extended_45_49_discussion'));
      expect(codes, isNot(contains('mammography_screening')));
      expect(codes, contains('cervical_hpv_screening'));
    });

    test('Female age 47 in default region without extended mammography', () {
      final bundle = _bundle(
        id: 'p2b',
        firstName: 'Sofia',
        lastName: 'Verdi',
        birthDate: DateTime.utc(1979, 3, 10),
        biologicalSex: 'female',
      );
      final center = engine.build(
        bundle,
        regionCode: 'DE',
        generatedAt: refDate,
      );
      final codes = _codes(center.annualExams);
      // DE (Germany) is not a configured region → default policy, no extension
      expect(codes, isNot(contains('mammography_extended_45_49_discussion')));
    });

    test('Female age 66: DEXA, mammography core, colorectal', () {
      final bundle = _bundle(
        id: 'p3',
        firstName: 'Giulia',
        lastName: 'Neri',
        birthDate: DateTime.utc(1960, 3, 10),
        biologicalSex: 'female',
        postmenopausal: true,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);

      expect(center.age, 66);
      expect(codes, contains('dexa_bone_density'));
      expect(codes, isNot(contains('annual_bone_density_review')));
      expect(codes, contains('mammography_screening'));
      expect(codes, contains('annual_colorectal_screening_discussion'));
    });

    test(
      'Male age 60: colorectal, PSA shared decision, no female screenings',
      () {
        final bundle = _bundle(
          id: 'p4',
          firstName: 'Marco',
          lastName: 'Rossi',
          birthDate: DateTime.utc(1966, 3, 10),
          biologicalSex: 'male',
        );
        final center = engine.build(bundle, generatedAt: refDate);
        final examCodes = _codes(center.annualExams);
        final decisionCodes = _codes(center.sharedDecisions);

        expect(center.age, 60);
        expect(examCodes, contains('annual_colorectal_screening_discussion'));
        expect(decisionCodes, contains('psa_shared_decision'));
        expect(examCodes, isNot(contains('mammography_screening')));
        expect(examCodes, isNot(contains('cervical_hpv_screening')));
        expect(examCodes, isNot(contains('cervical_pap_screening')));
      },
    );

    test('Male age 72: PSA not routine, colorectal extended (IT)', () {
      final bundle = _bundle(
        id: 'p5',
        firstName: 'Luigi',
        lastName: 'Gialli',
        birthDate: DateTime.utc(1954, 3, 10),
        biologicalSex: 'male',
      );
      final center = engine.build(
        bundle,
        regionCode: 'IT',
        generatedAt: refDate,
      );
      final examCodes = _codes(center.annualExams);
      final decisionCodes = _codes(center.sharedDecisions);

      expect(center.age, 72);
      expect(decisionCodes, contains('psa_not_routine_after_70'));
      expect(decisionCodes, isNot(contains('psa_shared_decision')));
      expect(examCodes, contains('colorectal_extended_discussion'));
      expect(
        examCodes,
        isNot(contains('annual_colorectal_screening_discussion')),
      ); // age > 69
    });
  });

  group('AAA screening', () {
    test('Male age 68 current smoker: AAA ultrasound recommended', () {
      final bundle = _bundle(
        id: 'p6',
        firstName: 'Paolo',
        lastName: 'Blu',
        birthDate: DateTime.utc(1958, 3, 10),
        biologicalSex: 'male',
        smoker: true,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);

      expect(center.age, 68);
      expect(codes, contains('aaa_ultrasound_once'));
    });

    test('Male age 68 former smoker: AAA ultrasound recommended', () {
      final bundle = _bundle(
        id: 'p6b',
        firstName: 'Paolo',
        lastName: 'Blu',
        birthDate: DateTime.utc(1958, 3, 10),
        biologicalSex: 'male',
        formerSmoker: true,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(_codes(center.annualExams), contains('aaa_ultrasound_once'));
    });

    test('Male age 68 never smoker: no AAA item', () {
      final bundle = _bundle(
        id: 'p6c',
        firstName: 'Paolo',
        lastName: 'Blu',
        birthDate: DateTime.utc(1958, 3, 10),
        biologicalSex: 'male',
        smoker: false,
        formerSmoker: false,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(
        _codes(center.annualExams),
        isNot(contains('aaa_ultrasound_once')),
      );
    });
  });

  group('Lung cancer / LDCT', () {
    test('Age 55 smoker with 20+ pack-years: LDCT recommended', () {
      final bundle = _bundle(
        id: 'p7',
        firstName: 'Carlo',
        lastName: 'Fumi',
        birthDate: DateTime.utc(1971, 3, 10),
        biologicalSex: 'male',
        smoker: true,
        smokingPackYears: 25,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);

      expect(center.age, 55);
      expect(codes, contains('lung_ldct_screening'));
      expect(codes, isNot(contains('lung_risk_data_review')));
    });

    test(
      'Age 55 former smoker quit within 15 years with 20+ pack-years: LDCT',
      () {
        final bundle = _bundle(
          id: 'p7b',
          firstName: 'Carlo',
          lastName: 'Fumi',
          birthDate: DateTime.utc(1971, 3, 10),
          biologicalSex: 'male',
          formerSmoker: true,
          smokingPackYears: 30,
          yearsSinceQuitting: 5,
        );
        final center = engine.build(bundle, generatedAt: refDate);
        expect(_codes(center.annualExams), contains('lung_ldct_screening'));
      },
    );

    test('Adult smoker without pack-year field: lung risk data review', () {
      final bundle = _bundle(
        id: 'p8',
        firstName: 'Anna',
        lastName: 'Fuma',
        birthDate: DateTime.utc(1970, 3, 10),
        biologicalSex: 'female',
        smoker: true,
        smokingPackYears: null,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);

      expect(center.age, 56);
      expect(codes, contains('lung_risk_data_review'));
      expect(codes, isNot(contains('lung_ldct_screening')));
    });

    test('Non-smoker: no lung items', () {
      final bundle = _bundle(
        id: 'p8b',
        firstName: 'Elena',
        lastName: 'Sana',
        birthDate: DateTime.utc(1970, 3, 10),
        biologicalSex: 'female',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(
        _codes(center.annualExams),
        isNot(contains('lung_ldct_screening')),
      );
      expect(
        _codes(center.annualExams),
        isNot(contains('lung_risk_data_review')),
      );
    });
  });

  group('STI risk', () {
    test('STI risk active: STI screening discussion', () {
      final bundle = _bundle(
        id: 'p9',
        firstName: 'Laura',
        lastName: 'Sensi',
        birthDate: DateTime.utc(1998, 3, 10),
        biologicalSex: 'female',
        sexuallyActive: true,
        newOrMultiplePartners: true,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);

      expect(codes, contains('annual_sti_screening_discussion'));
      expect(codes, contains('sti_screening_discussion'));
      expect(codes, contains('hiv_once_lifetime'));
      expect(codes, contains('hcv_once_lifetime'));
    });

    test('No STI risk: no STI discussion items', () {
      final bundle = _bundle(
        id: 'p9b',
        firstName: 'Laura',
        lastName: 'Sensi',
        birthDate: DateTime.utc(1998, 3, 10),
        biologicalSex: 'female',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(
        _codes(center.annualExams),
        isNot(contains('annual_sti_screening_discussion')),
      );
      expect(
        _codes(center.annualExams),
        isNot(contains('sti_screening_discussion')),
      );
    });

    test('Female 24 or younger sexually active: chlamydia screening', () {
      final bundle = _bundle(
        id: 'p9c',
        firstName: 'Giovanna',
        lastName: 'Giovane',
        birthDate: DateTime.utc(2002, 6, 15),
        biologicalSex: 'female',
        sexuallyActive: true,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(center.age, 23);
      expect(_codes(center.annualExams), contains('young_woman_sti_screening'));
    });
  });

  group('Pregnancy and preconception', () {
    test('Pregnant profile: pregnancy items high priority', () {
      final bundle = _bundle(
        id: 'p10',
        firstName: 'Mamma',
        lastName: 'Felice',
        birthDate: DateTime.utc(1995, 3, 10),
        biologicalSex: 'female',
        currentlyPregnant: true,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.pregnancyAndPreconception);
      final items = center.pregnancyAndPreconception;

      expect(codes, contains('pregnancy_preconception_review'));
      expect(codes, contains('preconception_folic_acid'));
      expect(codes, contains('pregnancy_medication_review'));
      expect(codes, contains('pregnancy_vaccine_planning'));
      expect(
        items.every((i) => i.status == 'recommended' || i.status == 'review'),
        isTrue,
      );
    });

    test('Trying to conceive: preconception review', () {
      final bundle = _bundle(
        id: 'p10b',
        firstName: 'Speranza',
        lastName: 'Futura',
        birthDate: DateTime.utc(1993, 3, 10),
        biologicalSex: 'female',
        tryingToConceive: true,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(
        _codes(center.pregnancyAndPreconception),
        contains('pregnancy_preconception_review'),
      );
    });

    test('Not pregnant, not trying: empty pregnancy section', () {
      final bundle = _bundle(
        id: 'p10c',
        firstName: 'Normale',
        lastName: 'Persona',
        birthDate: DateTime.utc(1993, 3, 10),
        biologicalSex: 'female',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(center.pregnancyAndPreconception, isEmpty);
    });
  });

  group('Family history', () {
    test('User with family history: family history review appears', () {
      final bundle = _bundle(
        id: 'p11',
        firstName: 'Storia',
        lastName: 'Familiare',
        birthDate: DateTime.utc(1985, 3, 10),
        biologicalSex: 'female',
        familyHistory: const [
          FamilyHistoryItem(
            id: 'fh-1',
            relation: 'Mother',
            conditionName: 'Diabetes',
          ),
        ],
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(_codes(center.sharedDecisions), contains('family_history_review'));
    });
  });

  group('Edge cases', () {
    test('No birthDate: engine does not crash', () {
      final bundle = _bundle(
        id: 'p12',
        firstName: 'Senza',
        lastName: 'Data',
        birthDate: null,
        biologicalSex: 'female',
      );
      expect(() => engine.build(bundle, generatedAt: refDate), returnsNormally);
    });

    test('No birthDate: still has general registry items', () {
      final bundle = _bundle(
        id: 'p12b',
        firstName: 'Senza',
        lastName: 'Data',
        birthDate: null,
        biologicalSex: 'male',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(center.age, isNull);
      expect(center.annualVisit, isNotNull);
      expect(center.overview.seasonalChecks, greaterThan(0));
    });

    test('Null biological sex does not crash', () {
      final bundle = _bundle(
        id: 'p12c',
        firstName: 'Senza',
        lastName: 'Sesso',
        birthDate: DateTime.utc(1990, 1, 1),
        biologicalSex: '',
      );
      expect(() => engine.build(bundle, generatedAt: refDate), returnsNormally);
    });

    test('Empty profile bundle does not crash', () {
      final bundle = ProfileBundle(
        profile: PatientProfile(
          id: 'empty',
          userId: 'u1',
          isPrimary: true,
          smoker: false,
        ),
        onboarding: const OnboardingStatus(healthDataConsent: false),
        allergies: const [],
        medicalConditions: const [],
        medications: const [],
        familyHistory: const [],
        vaccinations: const [],
        clinicalEpisodes: const [],
      );
      expect(() => engine.build(bundle, generatedAt: refDate), returnsNormally);
    });
  });

  group('Vaccine recommendations', () {
    test('Older adult: influenza, dTpa, pneumococcal, zoster', () {
      final bundle = _bundle(
        id: 'v1',
        firstName: 'Anziano',
        lastName: 'Paziente',
        birthDate: DateTime.utc(1956, 3, 10),
        biologicalSex: 'male',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.vaccines);

      expect(center.age, 70);
      expect(codes, contains('annual_influenza_review'));
      expect(codes, contains('dtpa_booster_review'));
      expect(codes, contains('pneumococcal_vaccine_review'));
      expect(codes, contains('zoster_vaccine_review'));
    });

    test('Young adult: no pneumococcal or zoster, no HPV (over 26)', () {
      final bundle = _bundle(
        id: 'v2',
        firstName: 'Giovane',
        lastName: 'Adulto',
        birthDate: DateTime.utc(1996, 3, 10),
        biologicalSex: 'male',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.vaccines);

      expect(center.age, 30);
      expect(codes, contains('dtpa_booster_review'));
      expect(
        codes,
        isNot(contains('annual_influenza_review')),
      ); // no risk factors
      expect(codes, isNot(contains('pneumococcal_vaccine_review')));
      expect(codes, isNot(contains('zoster_vaccine_review')));
      expect(codes, isNot(contains('hpv_vaccine_review'))); // over 26
    });
  });

  group('Cardiovascular and metabolic', () {
    test('Adult 40+ with risk: CV risk review recommended', () {
      final bundle = _bundle(
        id: 'cv1',
        firstName: 'Rischio',
        lastName: 'Cardio',
        birthDate: DateTime.utc(1980, 3, 10),
        biologicalSex: 'male',
        smoker: true,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.visitsAndControls);

      expect(center.age, 46);
      expect(codes, contains('cardiovascular_risk_review'));
      expect(codes, contains('lipid_profile_review'));
      expect(codes, contains('metabolic_risk_followup'));
    });

    test('Diabetes risk: HbA1c screening appears', () {
      final bundle = _bundle(
        id: 'dm1',
        firstName: 'Diabeta',
        lastName: 'Rischio',
        birthDate: DateTime.utc(1980, 3, 10),
        biologicalSex: 'female',
        weightKg: 85,
        heightCm: 165,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);

      // BMI = 85 / (1.65^2) ≈ 31.2 >= 25
      expect(codes, contains('diabetes_hba1c_screening'));
    });
  });

  group('Bone health', () {
    test('Female 65+: DEXA recommended', () {
      final bundle = _bundle(
        id: 'b1',
        firstName: 'Ossea',
        lastName: 'Salute',
        birthDate: DateTime.utc(1961, 3, 10),
        biologicalSex: 'female',
        postmenopausal: true,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);

      expect(center.age, 65);
      expect(codes, contains('dexa_bone_density'));
      expect(codes, isNot(contains('annual_bone_density_review')));
    });

    test('Female 60 with fragility fracture: early DEXA discussion', () {
      final bundle = _bundle(
        id: 'b2',
        firstName: 'Fragile',
        lastName: 'Ossa',
        birthDate: DateTime.utc(1966, 3, 10),
        biologicalSex: 'female',
        postmenopausal: true,
        fragilityFractureHistory: true,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);

      expect(center.age, 60);
      expect(codes, contains('early_dexa_discussion'));
      expect(codes, contains('annual_bone_density_review'));
    });

    test('Male 70 smoker: male bone density discussion', () {
      final bundle = _bundle(
        id: 'b3',
        firstName: 'Uomo',
        lastName: 'Fumatore',
        birthDate: DateTime.utc(1956, 3, 10),
        biologicalSex: 'male',
        smoker: true,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);

      expect(center.age, 70);
      expect(codes, contains('male_bone_density_discussion'));
    });
  });

  group('Fall risk', () {
    test('Age 65+ with no falls: fall risk review appears', () {
      final bundle = _bundle(
        id: 'f1',
        firstName: 'Caduta',
        lastName: 'Rischio',
        birthDate: DateTime.utc(1956, 3, 10),
        biologicalSex: 'female',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(_codes(center.visitsAndControls), contains('fall_risk_review'));
    });

    test('Age 65+ with falls: fall risk review recommended high priority', () {
      final bundle = _bundle(
        id: 'f2',
        firstName: 'Caduta',
        lastName: 'Avvenuta',
        birthDate: DateTime.utc(1956, 3, 10),
        biologicalSex: 'female',
        fallsLastYear: 2,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final items = center.visitsAndControls.where(
        (i) => i.code == 'fall_risk_review',
      );
      expect(items.length, 1);
      expect(items.first.status, 'recommended');
      expect(items.first.priority, 'high');
    });
  });

  group('Dedup prevention', () {
    test('No duplicate codes across annualExams', () {
      final bundle = _bundle(
        id: 'd1',
        firstName: 'Duplicato',
        lastName: 'Test',
        birthDate: DateTime.utc(1960, 3, 10),
        biologicalSex: 'female',
        postmenopausal: true,
        smoker: true,
        smokingPackYears: 25,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = center.annualExams.map((e) => e.code).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('No duplicate codes across sharedDecisions', () {
      final bundle = _bundle(
        id: 'd2',
        firstName: 'Duplicato',
        lastName: 'Decisioni',
        birthDate: DateTime.utc(1966, 3, 10),
        biologicalSex: 'male',
        familyHistory: const [
          FamilyHistoryItem(
            id: 'fh-1',
            relation: 'Father',
            conditionName: 'Cancer',
          ),
        ],
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = center.sharedDecisions.map((e) => e.code).toList();
      expect(codes.toSet().length, codes.length);
    });
  });

  group('Infectious disease / lifetime checks', () {
    test('Adult 30: HIV and HCV review items', () {
      final bundle = _bundle(
        id: 'inf1',
        firstName: 'Infect',
        lastName: 'Test',
        birthDate: DateTime.utc(1996, 3, 10),
        biologicalSex: 'male',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);

      expect(center.age, 30);
      expect(codes, contains('hiv_once_lifetime'));
      expect(codes, contains('hcv_once_lifetime'));
    });

    test('Adult 80: no HIV or HCV review', () {
      final bundle = _bundle(
        id: 'inf2',
        firstName: 'Over',
        lastName: 'Eighty',
        birthDate: DateTime.utc(1946, 3, 10),
        biologicalSex: 'male',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);

      expect(center.age, 80);
      expect(codes, isNot(contains('hiv_once_lifetime'))); // > 65
      expect(codes, isNot(contains('hcv_once_lifetime'))); // > 79
    });
  });

  group('Regional policy', () {
    test('Italy extends colorectal to 74', () {
      final bundle = _bundle(
        id: 'r1',
        firstName: 'Italiano',
        lastName: 'Test',
        birthDate: DateTime.utc(1954, 3, 10),
        biologicalSex: 'male',
      );
      final center = engine.build(
        bundle,
        regionCode: 'IT',
        generatedAt: refDate,
      );
      expect(
        _codes(center.annualExams),
        contains('colorectal_extended_discussion'),
      );
    });

    test('Default non-Italy region does not extend colorectal to 74', () {
      final bundle = _bundle(
        id: 'r2',
        firstName: 'Default',
        lastName: 'Region',
        birthDate: DateTime.utc(1954, 3, 10),
        biologicalSex: 'male',
      );
      final center = engine.build(
        bundle,
        regionCode: 'DE',
        generatedAt: refDate,
      );
      expect(
        _codes(center.annualExams),
        isNot(contains('colorectal_extended_discussion')),
      );
    });

    test('US region: mammography core 50-74, cervical Pap 21-29', () {
      final bundle52 = _bundle(
        id: 'us1',
        firstName: 'USA',
        lastName: 'Mamma',
        birthDate: DateTime.utc(1974, 3, 10),
        biologicalSex: 'female',
      );
      final center52 = engine.build(
        bundle52,
        regionCode: 'US',
        generatedAt: refDate,
      );
      final codes52 = _codes(center52.annualExams);
      expect(center52.age, 52);
      expect(codes52, contains('mammography_screening'));
      expect(codes52, contains('cervical_hpv_screening')); // 52 >= 30 → HPV

      final bundle23 = _bundle(
        id: 'us2',
        firstName: 'USA',
        lastName: 'PAP',
        birthDate: DateTime.utc(2003, 3, 10),
        biologicalSex: 'female',
        sexuallyActive: true,
      );
      final center23 = engine.build(
        bundle23,
        regionCode: 'US',
        generatedAt: refDate,
      );
      final codes23 = _codes(center23.annualExams);
      expect(center23.age, 23);
      expect(codes23, contains('cervical_pap_screening')); // 23 < 30 → Pap
    });

    test('UK region: colorectal starts at 60, cervical HPV from 25', () {
      final bundle55 = _bundle(
        id: 'uk1',
        firstName: 'UK',
        lastName: 'FIT',
        birthDate: DateTime.utc(1971, 3, 10),
        biologicalSex: 'male',
      );
      final center55 = engine.build(
        bundle55,
        regionCode: 'UK',
        generatedAt: refDate,
      );
      final codes55 = _codes(center55.annualExams);
      expect(center55.age, 55);
      // UK colorectal starts at 60, so no colorectal yet
      expect(
        codes55,
        isNot(contains('annual_colorectal_screening_discussion')),
      );

      // At age 65, colorectal should be active
      final bundle65 = _bundle(
        id: 'uk2',
        firstName: 'UK',
        lastName: 'FIT65',
        birthDate: DateTime.utc(1961, 3, 10),
        biologicalSex: 'male',
      );
      final center65 = engine.build(
        bundle65,
        regionCode: 'UK',
        generatedAt: refDate,
      );
      expect(center65.age, 65);
      expect(
        _codes(center65.annualExams),
        contains('annual_colorectal_screening_discussion'),
      );

      // UK cervical: HPV primary from 25
      final bundleW = _bundle(
        id: 'uk3',
        firstName: 'UK',
        lastName: 'Cervix',
        birthDate: DateTime.utc(1996, 3, 10),
        biologicalSex: 'female',
      );
      final centerW = engine.build(
        bundleW,
        regionCode: 'UK',
        generatedAt: refDate,
      );
      final codesW = _codes(centerW.annualExams);
      expect(centerW.age, 30);
      expect(codesW, contains('cervical_hpv_screening')); // HPV primary from 25
      expect(codesW, isNot(contains('cervical_pap_screening'))); // No Pap in UK
    });
  });

  group('Breast high risk', () {
    test('Family history of breast cancer: high risk discussion', () {
      final bundle = _bundle(
        id: 'br1',
        firstName: 'Rischio',
        lastName: 'Mammella',
        birthDate: DateTime.utc(1990, 3, 10),
        biologicalSex: 'female',
        familyHistory: const [
          FamilyHistoryItem(
            id: 'fh-br',
            relation: 'Mother',
            conditionName: 'Breast cancer',
          ),
        ],
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(
        _codes(center.sharedDecisions),
        contains('breast_high_risk_screening_discussion'),
      );
    });
  });

  group('Medication review follow-up', () {
    test('Profile with conditions: medication review item appears', () {
      final bundle = _bundle(
        id: 'mr1',
        firstName: 'Farmaci',
        lastName: 'Test',
        birthDate: DateTime.utc(1970, 3, 10),
        biologicalSex: 'male',
        medicalConditions: const [
          MedicalConditionItem(id: 'c1', name: 'Hypertension'),
        ],
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(_codes(center.followUpReminders), contains('medication_review'));
    });
  });

  group('Dental check', () {
    test('Dental check appears for all adult ages', () {
      final bundle = _bundle(
        id: 'de1',
        firstName: 'Denti',
        lastName: 'Sani',
        birthDate: DateTime.utc(1990, 3, 10),
        biologicalSex: 'male',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(_codes(center.visitsAndControls), contains('dental_check_review'));
    });
  });

  group('Mental health check-in', () {
    test('Mental health check-in appears for all ages', () {
      final bundle = _bundle(
        id: 'mh1',
        firstName: 'Mente',
        lastName: 'Sana',
        birthDate: DateTime.utc(1990, 3, 10),
        biologicalSex: 'female',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(
        _codes(center.visitsAndControls),
        contains('mental_health_checkin'),
      );
    });
  });

  group('Skin check discussion', () {
    test('Skin check appears with skin cancer family history', () {
      final bundle = _bundle(
        id: 'sk1',
        firstName: 'Pelle',
        lastName: 'Controllo',
        birthDate: DateTime.utc(1990, 3, 10),
        biologicalSex: 'female',
        familyHistory: const [
          FamilyHistoryItem(
            id: 'fh-sk',
            relation: 'Father',
            conditionName: 'Skin cancer',
          ),
        ],
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(_codes(center.sharedDecisions), contains('skin_check_discussion'));
    });

    test('Skin check does not appear without risk', () {
      final bundle = _bundle(
        id: 'sk2',
        firstName: 'Pelle',
        lastName: 'Sana',
        birthDate: DateTime.utc(1990, 3, 10),
        biologicalSex: 'female',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(
        _codes(center.sharedDecisions),
        isNot(contains('skin_check_discussion')),
      );
    });
  });

  group('dTpa booster date logic', () {
    test('Recent tetanus vaccine within 10 years: review not recommended', () {
      final bundle = _bundle(
        id: 'dt1',
        firstName: 'Tetanus',
        lastName: 'Recent',
        birthDate: DateTime.utc(1980, 3, 10),
        biologicalSex: 'male',
        vaccinations: [
          VaccinationRecordItem(
            id: 'vax-dt',
            vaccineName: 'dTpa',
            administeredOn: DateTime.utc(2020, 1, 1),
          ),
        ],
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final dtpa = center.vaccines.firstWhere(
        (i) => i.code == 'dtpa_booster_review',
      );
      expect(dtpa.status, 'review');
      expect(dtpa.priority, 'normal');
    });

    test('Old tetanus vaccine >10 years ago: recommended high priority', () {
      final bundle = _bundle(
        id: 'dt2',
        firstName: 'Tetanus',
        lastName: 'Old',
        birthDate: DateTime.utc(1980, 3, 10),
        biologicalSex: 'male',
        vaccinations: [
          VaccinationRecordItem(
            id: 'vax-dt',
            vaccineName: 'dTpa',
            administeredOn: DateTime.utc(2010, 1, 1),
          ),
        ],
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final dtpa = center.vaccines.firstWhere(
        (i) => i.code == 'dtpa_booster_review',
      );
      expect(dtpa.status, 'recommended');
      expect(dtpa.priority, 'high');
    });
  });

  group('Bone risk condition detection', () {
    test('Osteoporosis condition triggers annual_bone_density_review', () {
      final bundle = _bundle(
        id: 'bo1',
        firstName: 'Osso',
        lastName: 'Debole',
        birthDate: DateTime.utc(1970, 3, 10),
        biologicalSex: 'female',
        postmenopausal: true,
        medicalConditions: const [
          MedicalConditionItem(id: 'c-ost', name: 'Osteoporosis'),
        ],
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.annualExams);
      expect(codes, contains('annual_bone_density_review'));
    });

    test('Osteopenia family history triggers bone density review', () {
      final bundle = _bundle(
        id: 'bo2',
        firstName: 'Famiglia',
        lastName: 'Ossea',
        birthDate: DateTime.utc(1970, 3, 10),
        biologicalSex: 'female',
        postmenopausal: true,
        familyHistory: const [
          FamilyHistoryItem(
            id: 'fh-bo',
            relation: 'Mother',
            conditionName: 'Osteopenia',
          ),
        ],
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(
        _codes(center.annualExams),
        contains('annual_bone_density_review'),
      );
    });
  });

  group('PreventionRecords in ProfileBundle', () {
    test('Default preventionRecords is empty', () {
      final bundle = _bundle(
        id: 'pr1',
        firstName: 'Record',
        lastName: 'Test',
        birthDate: DateTime.utc(1990, 3, 10),
        biologicalSex: 'female',
      );
      expect(bundle.preventionRecords, isEmpty);
    });
  });

  group('Helper: _hasSmokingPackYearRisk and _quitSmokingWithinYears', () {
    test('Smoker with pack years triggers LDCT (via build)', () {
      final bundle = _bundle(
        id: 'hl1',
        firstName: 'Helper',
        lastName: 'LDCT',
        birthDate: DateTime.utc(1970, 3, 10),
        biologicalSex: 'male',
        smoker: true,
        smokingPackYears: 25,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(_codes(center.annualExams), contains('lung_ldct_screening'));
    });

    test('Former smoker quit within 15 years with 20+ pack years', () {
      final bundle = _bundle(
        id: 'hl2',
        firstName: 'Ex',
        lastName: 'Smoker',
        birthDate: DateTime.utc(1970, 3, 10),
        biologicalSex: 'male',
        formerSmoker: true,
        smokingPackYears: 30,
        yearsSinceQuitting: 5,
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(_codes(center.annualExams), contains('lung_ldct_screening'));
    });
  });

  group('Prevention history records', () {
    test('PreventionRecords in bundle do not crash engine', () {
      final bundle = ProfileBundle(
        profile: PatientProfile(
          id: 'ph1',
          userId: 'u1',
          isPrimary: true,
          smoker: false,
          birthDate: DateTime.utc(1990, 3, 10),
          biologicalSex: 'female',
        ),
        onboarding: const OnboardingStatus(healthDataConsent: true),
        allergies: const [],
        medicalConditions: const [],
        medications: const [],
        familyHistory: const [],
        vaccinations: const [],
        clinicalEpisodes: const [],
        preventionRecords: [
          PreventionRecord(
            code: 'mammography_screening',
            performedAt: DateTime(2024, 1, 15).toUtc(),
          ),
        ],
      );
      expect(() => engine.build(bundle, generatedAt: refDate), returnsNormally);
    });
  });

  group('Cardiometabolic token expansion', () {
    test('Prediabetes condition triggers cardiometabolic risk', () {
      final bundle = _bundle(
        id: 'cm1',
        firstName: 'Prediabetico',
        lastName: 'Test',
        birthDate: DateTime.utc(1980, 3, 10),
        biologicalSex: 'male',
        smoker: false,
        formerSmoker: false,
        medicalConditions: const [
          MedicalConditionItem(id: 'c-pd', name: 'Prediabetes'),
        ],
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(
        _codes(center.visitsAndControls),
        contains('metabolic_risk_followup'),
      );
    });
  });

  group('First-degree family history', () {
    test(
      'First-degree relation with colon cancer triggers colorectal high risk',
      () {
        final bundle = _bundle(
          id: 'fd1',
          firstName: 'Famiglia',
          lastName: 'PrimoGrado',
          birthDate: DateTime.utc(1970, 3, 10),
          biologicalSex: 'male',
          familyHistory: const [
            FamilyHistoryItem(
              id: 'fh-fd',
              relation: 'Father',
              conditionName: 'Colon cancer',
            ),
          ],
        );
        final center = engine.build(bundle, generatedAt: refDate);
        expect(
          _codes(center.annualExams),
          contains('colorectal_high_risk_discussion'),
        );
      },
    );
  });

  group('PreventionRecord suppression', () {
    test(
      'Recent mammography record suppresses new mammography recommendation',
      () {
        final bundle = ProfileBundle(
          profile: PatientProfile(
            id: 'sp1',
            userId: 'u1',
            isPrimary: true,
            firstName: 'Suppress',
            lastName: 'Mammo',
            birthDate: DateTime.utc(1970, 3, 10),
            biologicalSex: 'female',
            smoker: false,
          ),
          onboarding: const OnboardingStatus(healthDataConsent: true),
          allergies: const [],
          medicalConditions: const [],
          medications: const [],
          familyHistory: const [],
          vaccinations: const [],
          clinicalEpisodes: const [],
          preventionRecords: [
            PreventionRecord(
              code: 'mammography_screening',
              performedAt: DateTime.utc(2025, 1, 15),
            ),
          ],
        );
        final center = engine.build(bundle, generatedAt: refDate);
        expect(
          _codes(center.annualExams),
          isNot(contains('mammography_screening')),
        );
      },
    );

    test('Old mammography record (3+ years ago) does not suppress', () {
      final bundle = ProfileBundle(
        profile: PatientProfile(
          id: 'sp2',
          userId: 'u1',
          isPrimary: true,
          firstName: 'Old',
          lastName: 'Mammo',
          birthDate: DateTime.utc(1970, 3, 10),
          biologicalSex: 'female',
          smoker: false,
        ),
        onboarding: const OnboardingStatus(healthDataConsent: true),
        allergies: const [],
        medicalConditions: const [],
        medications: const [],
        familyHistory: const [],
        vaccinations: const [],
        clinicalEpisodes: const [],
        preventionRecords: [
          PreventionRecord(
            code: 'mammography_screening',
            performedAt: DateTime.utc(2022, 1, 15),
          ),
        ],
      );
      final center = engine.build(bundle, generatedAt: refDate);
      expect(_codes(center.annualExams), contains('mammography_screening'));
    });
  });

  group('PSA high-risk family history', () {
    test(
      'Younger male with prostate cancer family history gets early discussion',
      () {
        final bundle = _bundle(
          id: 'psa-hr',
          firstName: 'Famiglia',
          lastName: 'Prostata',
          birthDate: DateTime.utc(1985, 3, 10),
          biologicalSex: 'male',
          familyHistory: const [
            FamilyHistoryItem(
              id: 'fh-psa',
              relation: 'Father',
              conditionName: 'Prostate cancer',
            ),
          ],
        );
        final center = engine.build(bundle, generatedAt: refDate);
        final codes = _codes(center.sharedDecisions);
        expect(center.age, 41);
        expect(codes, contains('psa_high_risk_discussion'));
      },
    );

    test('No family history: no early PSA discussion for under 55', () {
      final bundle = _bundle(
        id: 'psa-no',
        firstName: 'NoFamiglia',
        lastName: 'Prostata',
        birthDate: DateTime.utc(1985, 3, 10),
        biologicalSex: 'male',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final codes = _codes(center.sharedDecisions);
      expect(codes, isNot(contains('psa_high_risk_discussion')));
    });
  });

  group('Eye exam with risk detection', () {
    test('Diabetic profile: eye exam recommended high priority', () {
      final bundle = _bundle(
        id: 'eye1',
        firstName: 'Diabetico',
        lastName: 'Occhi',
        birthDate: DateTime.utc(1970, 3, 10),
        biologicalSex: 'male',
        medicalConditions: const [
          MedicalConditionItem(id: 'c-dm', name: 'Diabetes'),
        ],
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final eye = center.annualExams.firstWhere(
        (i) => i.code == 'annual_eye_exam',
      );
      expect(eye.status, 'recommended');
      expect(eye.priority, 'high');
    });

    test('Healthy adult: eye exam review low priority', () {
      final bundle = _bundle(
        id: 'eye2',
        firstName: 'Sano',
        lastName: 'Occhi',
        birthDate: DateTime.utc(1970, 3, 10),
        biologicalSex: 'male',
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final eye = center.annualExams.firstWhere(
        (i) => i.code == 'annual_eye_exam',
      );
      expect(eye.status, 'review');
      expect(eye.priority, 'low');
    });
  });

  group('Pneumococcal priority', () {
    test('Older adult with chronic risk: pneumococcal priority high', () {
      final bundle = _bundle(
        id: 'pneu1',
        firstName: 'Cronico',
        lastName: 'Polmone',
        birthDate: DateTime.utc(1956, 3, 10),
        biologicalSex: 'male',
        medicalConditions: const [
          MedicalConditionItem(id: 'c-copd', name: 'COPD'),
        ],
      );
      final center = engine.build(bundle, generatedAt: refDate);
      final pneu = center.vaccines.firstWhere(
        (i) => i.code == 'pneumococcal_vaccine_review',
      );
      expect(pneu.priority, 'high');
    });
  });
}
