import 'dart:convert';

import 'package:clindiary/app/core/storage/local_database.dart';
import 'package:clindiary/app/core/storage/profile_scoped_cache.dart';
import 'package:clindiary/features/alerts/domain/clinical_alert.dart';
import 'package:clindiary/features/daily_journal/domain/daily_entry.dart';
import 'package:clindiary/features/insights/domain/on_device_recap_prompt.dart';
import 'package:clindiary/features/medications/domain/medication_adherence.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/features/timeline/domain/timeline_event.dart';
import 'package:clindiary/features/wearables/domain/wearable_day_summary.dart';

class OnDevicePromptBuilder {
  OnDevicePromptBuilder({required LocalDatabase localDatabase})
    : _localDatabase = localDatabase;

  final LocalDatabase _localDatabase;

  Future<OnDeviceRecapPrompt?> buildDailyRecapPrompt({
    required DateTime referenceDate,
  }) async {
    final profileBundle = await _readProfileBundle();
    final entries = await _readDailyEntries();
    final alerts = await _readAlerts();
    final medicationLogs = await _readMedicationLogs();
    final wearableSummaries = await _readWearableSummaries();
    final timelineEvents = await _readTimelineEvents();

    final targetDay = _dateOnly(referenceDate);
    final entriesForDay = entries
        .where((entry) => _sameDay(entry.entryDate, targetDay))
        .toList()
      ..sort((a, b) => a.entryDate.compareTo(b.entryDate));
    final relevantLogs = medicationLogs.where((item) {
      final scheduledDay = _dateOnly(item.scheduledAt);
      return _sameDay(scheduledDay, targetDay);
    }).toList();
    final relevantWearables = wearableSummaries
        .where((item) => _sameDay(item.summaryDate, targetDay))
        .toList();
    final relevantTimeline = timelineEvents
        .where((item) => _sameDay(item.eventDate, targetDay))
        .toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    final openAlerts = alerts.where((item) => !item.isResolved).toList();

    final hasLocalContext =
        profileBundle != null ||
        entriesForDay.isNotEmpty ||
        relevantLogs.isNotEmpty ||
        relevantWearables.isNotEmpty ||
        relevantTimeline.isNotEmpty ||
        openAlerts.isNotEmpty;
    if (!hasLocalContext) {
      return null;
    }

    final dataConsidered = <String>[
      '${entriesForDay.length} check-up locali',
      '${entriesForDay.fold<int>(0, (total, entry) => total + entry.symptoms.length)} sintomi',
      '${entriesForDay.fold<int>(0, (total, entry) => total + entry.vitals.length)} parametri vitali',
      '${relevantLogs.length} log terapia',
      '${relevantWearables.length} riepiloghi wearable',
      '${relevantTimeline.length} eventi timeline',
      '${openAlerts.length} alert aperti',
    ];

    final patientSnapshot = _patientSnapshot(profileBundle);
    final activeConditions =
        profileBundle?.medicalConditions.map((item) => item.name).toList() ??
        const <String>[];
    final allergies =
        profileBundle?.allergies.map((item) => item.allergen).toList() ??
        const <String>[];
    final familyHistory =
        profileBundle?.familyHistory
            .map((item) => '${item.relation}: ${item.conditionName}')
            .toList() ??
        const <String>[];
    final medications =
        profileBundle?.medications
            .where((item) => item.active)
            .map(_medicationLine)
            .toList() ??
        const <String>[];
    final medicationAdherence = relevantLogs.map(_medicationLogLine).toList();
    final wearableLines = relevantWearables.map((item) => item.toDiagnosticText()).toList();
    final journalEntries = entriesForDay.map(_serializeEntry).toList();
    final observations = _buildObservations(entriesForDay, relevantWearables, relevantTimeline);
    final followUpReasons = _buildFollowUpReasons(entriesForDay, relevantWearables, openAlerts);
    final missingData = _buildMissingData(
      entriesForDay: entriesForDay,
      relevantWearables: relevantWearables,
      relevantLogs: relevantLogs,
      profileBundle: profileBundle,
    );
    final timelineLines = relevantTimeline.map(_timelineLine).toList();
    final clinicalEpisodes =
        profileBundle?.clinicalEpisodes.map(_clinicalEpisodeLine).toList() ??
        const <String>[];

    final payload = <String, Object?>{
      'summary_type': 'daily',
      'summary_label': 'riassunto giornaliero on-device',
      'period_start': targetDay.toIso8601String().split('T').first,
      'period_end': targetDay.toIso8601String().split('T').first,
      'data_considered': dataConsidered,
      'patient_snapshot': patientSnapshot,
      'active_conditions': activeConditions,
      'allergies': allergies,
      'family_history': familyHistory,
      'medications': medications,
      'medication_adherence': medicationAdherence,
      'wearable_daily_summaries': wearableLines,
      'device_measurement_summaries': const <String>[],
      'journal_entries': journalEntries,
      'observations': observations,
      'recent_lab_results': const <String>[],
      'recent_imaging_reports': const <String>[],
      'recent_documents': timelineLines,
      'prior_daily_summaries': const <String>[],
      'clinical_episodes': clinicalEpisodes,
      'open_alerts': openAlerts.take(5).map((item) => '${item.severity}: ${item.title}').toList(),
      'follow_up_reasons': followUpReasons,
      'missing_data': missingData,
    };

    return OnDeviceRecapPrompt(
      summaryType: 'daily',
      periodStart: targetDay,
      periodEnd: targetDay,
      systemPrompt: _systemPrompt(),
      userPrompt: _userPrompt(payload),
      providerName: 'on_device_litertlm',
      suggestedModelFamily: 'Gemma 4',
      isCloudBypassedForThisRequest: true,
    );
  }

  Future<ProfileBundle?> _readProfileBundle() async {
    final cached = await readProfileScopedCache(_localDatabase, 'profile_bundle');
    if (cached == null) {
      return null;
    }
    final decoded = jsonDecode(cached) as Map<String, dynamic>;
    return ProfileBundle.fromJson(decoded);
  }

  Future<List<DailyEntry>> _readDailyEntries() async {
    final cached = await readProfileScopedCache(_localDatabase, 'daily_entries');
    if (cached == null) {
      return const <DailyEntry>[];
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map((item) => DailyEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ClinicalAlert>> _readAlerts() async {
    final cached = await readProfileScopedCache(_localDatabase, 'alerts_list');
    if (cached == null) {
      return const <ClinicalAlert>[];
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map((item) => ClinicalAlert.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MedicationLogItem>> _readMedicationLogs() async {
    final cached = await readProfileScopedCache(
      _localDatabase,
      'medication_logs',
    );
    if (cached == null) {
      return const <MedicationLogItem>[];
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map((item) => MedicationLogItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<WearableDaySummary>> _readWearableSummaries() async {
    for (final days in const [30, 14, 7]) {
      final cached = await readProfileScopedCache(
        _localDatabase,
        'wearables_recent_$days',
      );
      if (cached == null) {
        continue;
      }
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .map(
            (item) =>
                WearableDaySummary.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
    return const <WearableDaySummary>[];
  }

  Future<List<TimelineEventItem>> _readTimelineEvents() async {
    final cached = await readProfileScopedCache(
      _localDatabase,
      'timeline_events',
    );
    if (cached == null) {
      return const <TimelineEventItem>[];
    }
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded
        .map((item) => TimelineEventItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

List<String> _patientSnapshot(ProfileBundle? bundle) {
  if (bundle == null) {
    return const <String>[];
  }
  final profile = bundle.profile;
  final snapshot = <String>[];
  final demographics = <String>[];
  if (profile.birthDate != null) {
    demographics.add('${_ageFromBirthDate(profile.birthDate!)} anni');
  }
  if (profile.biologicalSex != null && profile.biologicalSex!.trim().isNotEmpty) {
    demographics.add('sesso biologico ${profile.biologicalSex}');
  }
  if (demographics.isNotEmpty) {
    snapshot.add('${profile.displayName}: ${demographics.join(', ')}');
  } else {
    snapshot.add(profile.displayName);
  }
  snapshot.add(profile.smoker ? 'fumatore' : 'non fumatore');
  if (profile.heightCm != null) {
    snapshot.add('altezza ${profile.heightCm!.toStringAsFixed(0)} cm');
  }
  if (profile.weightKg != null) {
    snapshot.add('peso ${profile.weightKg!.toStringAsFixed(1)} kg');
  }
  if (profile.exerciseHabits != null && profile.exerciseHabits!.trim().isNotEmpty) {
    snapshot.add('attivita abituale: ${profile.exerciseHabits}');
  }
  if (profile.sleepPattern != null && profile.sleepPattern!.trim().isNotEmpty) {
    snapshot.add('sonno abituale: ${profile.sleepPattern}');
  }
  return snapshot;
}

String _medicationLine(MedicationItem item) {
  final parts = <String>[item.name];
  if (item.dosage != null && item.dosage!.trim().isNotEmpty) {
    parts.add(item.dosage!.trim());
  }
  if (item.frequency != null && item.frequency!.trim().isNotEmpty) {
    parts.add(item.frequency!.trim());
  }
  return parts.join(' - ');
}

String _medicationLogLine(MedicationLogItem item) {
  final takenLabel = switch (item.status) {
    'taken' => 'assunta',
    'missed' => 'mancata',
    'skipped' => 'saltata',
    _ => item.status,
  };
  return '${item.medicationName}: $takenLabel alle ${item.scheduledAt.toLocal().toIso8601String().substring(11, 16)}';
}

List<String> _buildObservations(
  List<DailyEntry> entries,
  List<WearableDaySummary> wearables,
  List<TimelineEventItem> timeline,
) {
  final items = <String>[];
  if (entries.isEmpty) {
    items.add('Nel giorno selezionato non risultano check-up completi salvati in locale.');
  } else {
    final symptomLabels = <String, int>{};
    for (final entry in entries) {
      if (entry.energyLevel != null) {
        items.add('Energia riferita ${entry.energyLevel}/10.');
      }
      if (entry.stressLevel != null) {
        items.add('Stress riferito ${entry.stressLevel}/10.');
      }
      if (entry.generalPain != null) {
        items.add('Dolore generale ${entry.generalPain}/10.');
      }
      for (final symptom in entry.symptoms) {
        symptomLabels.update(
          symptom.symptomCode.replaceAll('_', ' '),
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      for (final vital in entry.vitals.take(4)) {
        items.add(
          'Parametro ${vital.type}: ${vital.value}${vital.unit == null ? '' : ' ${vital.unit}'}',
        );
      }
      if (entry.sleepHours != null) {
        items.add('Sonno riportato ${entry.sleepHours!.toStringAsFixed(1)} ore.');
      }
    }
    if (symptomLabels.isNotEmpty) {
      final top = symptomLabels.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      items.add(
        'Sintomi piu presenti: ${top.take(4).map((item) => '${item.key} (${item.value})').join(', ')}.',
      );
    }
  }

  for (final wearable in wearables) {
    if (wearable.stepsCount != null) {
      items.add('Wearable: ${wearable.stepsCount} passi.');
    }
    if (wearable.sleepMinutes != null) {
      items.add(
        'Wearable: sonno ${(wearable.sleepMinutes! / 60).toStringAsFixed(1)} ore.',
      );
    }
    if (wearable.heartRateAvgBpm != null) {
      items.add('Wearable: FC media ${wearable.heartRateAvgBpm!.toStringAsFixed(0)} bpm.');
    }
  }

  if (timeline.isNotEmpty) {
    items.add(
      'Timeline del giorno con ${timeline.length} eventi registrati.',
    );
  }
  return items.take(10).toList();
}

List<String> _buildFollowUpReasons(
  List<DailyEntry> entries,
  List<WearableDaySummary> wearables,
  List<ClinicalAlert> openAlerts,
) {
  final reasons = <String>[];
  final hasHighBurden = entries.any(
    (entry) =>
        (entry.generalPain ?? 0) >= 7 ||
        entry.symptoms.any((symptom) => (symptom.severity ?? 0) >= 7),
  );
  if (hasHighBurden) {
    reasons.add(
      'Nel giorno selezionato risultano sintomi o dolore auto-riferiti intensi: se persistono o peggiorano, confrontati con il medico.',
    );
  }
  final veryLowSleep = wearables.any(
    (item) => item.sleepMinutes != null && item.sleepMinutes! < 240,
  );
  if (veryLowSleep) {
    reasons.add(
      'I dati wearable mostrano sonno molto ridotto nella giornata: se il pattern continua, e utile segnalarlo al medico.',
    );
  }
  if (openAlerts.isNotEmpty) {
    reasons.add(
      'Sono presenti alert deterministici aperti: vanno riportati al medico senza reinterpretarli automaticamente.',
    );
  }
  if (reasons.isEmpty) {
    reasons.add(
      'Se i sintomi persistono, peggiorano o compaiono nuovi segnali rilevanti, porta il riepilogo al medico.',
    );
  }
  return reasons;
}

List<String> _buildMissingData({
  required List<DailyEntry> entriesForDay,
  required List<WearableDaySummary> relevantWearables,
  required List<MedicationLogItem> relevantLogs,
  required ProfileBundle? profileBundle,
}) {
  final missing = <String>[];
  if (profileBundle == null) {
    missing.add('Profilo clinico non disponibile nella cache locale.');
  }
  if (entriesForDay.isEmpty) {
    missing.add('Nessun check-up locale registrato per il giorno selezionato.');
  }
  if (relevantWearables.isEmpty) {
    missing.add('Nessun dato wearable locale disponibile per il giorno selezionato.');
  }
  if (relevantLogs.isEmpty) {
    missing.add('Nessun log terapia locale disponibile per il giorno selezionato.');
  }
  return missing;
}

Map<String, Object?> _serializeEntry(DailyEntry entry) {
  return {
    'date': entry.entryDate.toIso8601String().split('T').first,
    'sleep_hours': entry.sleepHours,
    'sleep_quality': entry.sleepQuality,
    'energy_level': entry.energyLevel,
    'mood_level': entry.moodLevel,
    'stress_level': entry.stressLevel,
    'general_pain': entry.generalPain,
    'general_notes': entry.generalNotes,
    'symptoms': entry.symptoms
        .map(
          (item) => {
            'code': item.symptomCode,
            'severity': item.severity,
            'duration_minutes': item.durationMinutes,
            'body_location': item.bodyLocation,
          },
        )
        .toList(),
    'vitals': entry.vitals
        .map(
          (item) => {
            'type': item.type,
            'value': item.value,
            'unit': item.unit,
          },
        )
        .toList(),
  };
}

String _timelineLine(TimelineEventItem item) {
  return '${item.eventDate.toIso8601String().split('T').first} - ${item.title}: ${item.description}';
}

String _clinicalEpisodeLine(ClinicalEpisodeItem item) {
  final parts = <String>[item.title];
  if (item.status != null && item.status!.trim().isNotEmpty) {
    parts.add(item.status!.trim());
  }
  if (item.summary != null && item.summary!.trim().isNotEmpty) {
    parts.add(item.summary!.trim());
  }
  return parts.join(' - ');
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year && left.month == right.month && left.day == right.day;

int _ageFromBirthDate(DateTime birthDate) {
  final now = DateTime.now();
  var age = now.year - birthDate.year;
  final birthdayThisYear = DateTime(now.year, birthDate.month, birthDate.day);
  if (birthdayThisYear.isAfter(now)) {
    age -= 1;
  }
  return age;
}

String _systemPrompt() {
  return "Segui rigorosamente le istruzioni dell'utente. Usa esclusivamente i dati presenti nel payload JSON senza aggiungere informazioni esterne.";
}

String _userPrompt(Map<String, Object?> payload) {
  final serialized = const JsonEncoder.withIndent('  ').convert(payload);
  return "Genera un riepilogo clinico prudente usando ESCLUSIVAMENTE i dati presenti nel payload JSON.\n\n"
      "OBIETTIVO\n"
      "Produrre un riepilogo chiaro, prudente e utile per il paziente e per il medico, evidenziando:\n"
      "- andamento temporale dei sintomi e dei parametri\n"
      "- eventuali pattern o correlazioni osservabili nei dati\n"
      "- esami o documenti recenti rilevanti\n"
      "- condizioni in cui e opportuno parlare con il medico\n\n"
      "VINCOLI GENERALI\n"
      "- Non inventare dati mancanti\n"
      "- Non formulare diagnosi\n"
      "- Non formulare prescrizioni\n"
      "- Non attribuire cause certe\n"
      "- Non usare linguaggio allarmistico\n"
      "- Se un dato non e presente o non e sufficiente, dichiararlo esplicitamente\n"
      "- Se esistono alert aperti, riportali fedelmente senza reinterpretarli\n"
      "- Le correlazioni devono essere descritte solo come osservazioni nei dati, non come causalita\n\n"
      "STRUTTURA OBBLIGATORIA DEL RISULTATO\n"
      "1. Periodo considerato e contesto del paziente\n"
      "2. Andamento osservato nel diario e nei dati registrati\n"
      "3. Eventi o documenti recenti rilevanti\n"
      "4. Quando e perche parlare con il medico\n"
      "5. Chiusura che ricorda esplicitamente che il testo non e una diagnosi o prescrizione\n\n"
      "OUTPUT\n"
      "Restituisci solo il riepilogo finale, in italiano, seguendo esattamente la struttura obbligatoria.\n\n"
      "DATI STRUTTURATI:\n$serialized";
}
