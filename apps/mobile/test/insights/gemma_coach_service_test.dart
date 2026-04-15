import 'package:clindiary/features/alerts/data/alerts_repository.dart';
import 'package:clindiary/features/daily_journal/data/daily_journal_repository.dart';
import 'package:clindiary/features/dossier/data/dossier_repository.dart';
import 'package:clindiary/features/documents/data/documents_repository.dart';
import 'package:clindiary/features/insights/data/gemma_coach_service.dart';
import 'package:clindiary/features/insights/data/on_device_ai_service.dart';
import 'package:clindiary/features/insights/data/on_device_prompt_builder.dart';
import 'package:clindiary/features/insights/domain/on_device_text_prompt.dart';
import 'package:clindiary/features/dossier/domain/health_dossier.dart';
import 'package:clindiary/features/medications/data/medications_repository.dart';
import 'package:clindiary/features/profile/domain/profile_bundle.dart';
import 'package:clindiary/features/profile/data/profile_repository.dart';
import 'package:clindiary/features/timeline/data/timeline_repository.dart';
import 'package:clindiary/features/wearables/data/wearables_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockOnDeviceAiService extends Mock implements OnDeviceAiService {}

class MockOnDevicePromptBuilder extends Mock implements OnDevicePromptBuilder {}

class MockDocumentsRepository extends Mock implements DocumentsRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockDailyJournalRepository extends Mock
    implements DailyJournalRepository {}

class MockAlertsRepository extends Mock implements AlertsRepository {}

class MockMedicationsRepository extends Mock implements MedicationsRepository {}

class MockTimelineRepository extends Mock implements TimelineRepository {}

class MockWearablesRepository extends Mock implements WearablesRepository {}

class MockDossierRepository extends Mock implements DossierRepository {}

class MockProfileBundle extends Mock implements ProfileBundle {}

class MockHealthDossier extends Mock implements HealthDossier {}

void main() {
  test(
    'answerQuestion warms the clinical cache and retries when the local prompt is initially missing',
    () async {
      final aiService = MockOnDeviceAiService();
      final promptBuilder = MockOnDevicePromptBuilder();
      final documentsRepository = MockDocumentsRepository();
      final profileRepository = MockProfileRepository();
      final dailyJournalRepository = MockDailyJournalRepository();
      final alertsRepository = MockAlertsRepository();
      final medicationsRepository = MockMedicationsRepository();
      final timelineRepository = MockTimelineRepository();
      final wearablesRepository = MockWearablesRepository();
      final dossierRepository = MockDossierRepository();

      const question =
          'Come sta andando il mio quadro clinico negli ultimi giorni?';
      final referenceDate = DateTime.utc(2026, 4, 5);
      const systemPrompt = 'system';
      const userPrompt = 'user';
      final prompt = OnDeviceTextPrompt(
        contextType: 'clinical_question',
        periodStart: referenceDate,
        periodEnd: referenceDate,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        providerName: 'on_device_litertlm',
        suggestedModelFamily: 'Gemma 4',
        isCloudBypassedForThisRequest: true,
      );

      var promptBuildCalls = 0;
      when(
        () => promptBuilder.buildClinicalQuestionPrompt(
          question: question,
          referenceDate: referenceDate,
        ),
      ).thenAnswer((_) async {
        promptBuildCalls += 1;
        if (promptBuildCalls == 1) {
          return null;
        }
        return prompt;
      });

      when(
        () => profileRepository.fetchProfile(),
      ).thenAnswer((_) async => MockProfileBundle());
      when(
        () => dossierRepository.fetchDossier(),
      ).thenAnswer((_) async => MockHealthDossier());
      when(
        () => dailyJournalRepository.fetchEntries(),
      ).thenAnswer((_) async => const []);
      when(
        () => alertsRepository.fetchAlerts(),
      ).thenAnswer((_) async => const []);
      when(
        () => medicationsRepository.fetchLogs(),
      ).thenAnswer((_) async => const []);
      when(
        () => timelineRepository.fetchEvents(),
      ).thenAnswer((_) async => const []);
      when(
        () => wearablesRepository.fetchDailySummaries(),
      ).thenAnswer((_) async => const []);
      when(
        () => aiService.generateText(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
        ),
      ).thenAnswer((_) async => 'Risposta di Gemma');

      final service = GemmaCoachService(
        onDeviceAiService: aiService,
        onDevicePromptBuilder: promptBuilder,
        documentsRepository: documentsRepository,
        profileRepository: profileRepository,
        dailyJournalRepository: dailyJournalRepository,
        alertsRepository: alertsRepository,
        medicationsRepository: medicationsRepository,
        timelineRepository: timelineRepository,
        wearablesRepository: wearablesRepository,
        dossierRepository: dossierRepository,
      );

      final answer = await service.answerQuestion(
        question: question,
        referenceDate: referenceDate,
      );

      expect(answer, 'Risposta di Gemma');
      expect(promptBuildCalls, 2);
      verify(() => profileRepository.fetchProfile()).called(1);
      verify(() => dossierRepository.fetchDossier()).called(1);
      verify(() => dailyJournalRepository.fetchEntries()).called(1);
      verify(() => alertsRepository.fetchAlerts()).called(1);
      verify(() => medicationsRepository.fetchLogs()).called(1);
      verify(() => timelineRepository.fetchEvents()).called(1);
      verify(() => wearablesRepository.fetchDailySummaries()).called(1);
      verify(
        () => aiService.generateText(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
        ),
      ).called(1);
    },
  );
}
