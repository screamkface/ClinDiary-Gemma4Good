# ClinDiary Gemma 4 Good Feature Inventory

This inventory is for the video submission package. It only uses features that are visible in the current public mobile workspace and avoids backend, clinical, regulatory or real-patient claims that are not supported by source.

## Core Positioning

ClinDiary is not an AI doctor. It is a private memory layer for daily health context.

Use the app as a local-first assistant that helps a person collect daily symptoms, documents, medications, wearable context and cautious Gemma-assisted summaries before a conversation with a clinician.

## Confirmed Demoable Features

| Area | Confirmed behavior | Source evidence | Safe video wording | Avoid saying |
| --- | --- | --- | --- | --- |
| Local-first app flow | Demo/auth bypass and local mobile flow are present. | `apps/mobile/lib/app/router.dart`, `apps/mobile/README.md` | "The demo runs on the mobile app with local-first data flows." | "Production backend is live" or "hospital integration" |
| Privacy and safety onboarding | The onboarding screen states local diary data, encrypted vault and no AI diagnosis. | `apps/mobile/lib/features/onboarding/presentation/onboarding_screen.dart` | "The app explains that AI summaries do not diagnose, prescribe or triage." | "AI replaces clinical judgement" |
| Voice check-in with Gemma | The user can speak in English, review/edit the transcript, send it to Gemma and receive a draft check-in. Gemma can fill sleep, sleep quality, energy, mood, stress, appetite, hydration, general pain, notes and recognized symptoms. | `apps/mobile/lib/features/daily_journal/presentation/daily_check_in_screen.dart`, `apps/mobile/lib/features/daily_journal/data/voice_check_in_assistant.dart`, `apps/mobile/test/daily_journal/voice_check_in_draft_test.dart` | "The user can speak, review the transcript, and let Gemma draft the check-in from local context." | "Gemma always fills every field automatically" |
| Symptom logging | Manual symptom entry supports suggested/custom symptoms, severity, duration, body location, headache details and notes. Voice/Gemma symptom drafts support symptom code, severity 0-10, duration, body location and metadata notes. | `apps/mobile/lib/features/daily_journal/presentation/symptom_entry_screen.dart`, `apps/mobile/lib/features/daily_journal/domain/voice_check_in_draft.dart` | "Symptoms can be saved with severity, duration and body location, either manually or from a reviewed Gemma voice draft." | "Automatic diagnosis" |
| Medication context and reminders | Medication schedules, adherence status, notes and local reminders are implemented. | `apps/mobile/lib/features/medications/presentation/medications_screen.dart`, `apps/mobile/lib/app/core/notifications/local_medication_reminder_service.dart` | "Medication context and reminders stay in the local diary." | "The app prescribes medication or dosage changes" |
| Encrypted document vault | Documents are stored in a local encrypted vault; PDF text extraction is supported; file/photo import UI exists. | `apps/mobile/lib/features/documents/data/local_document_vault_cipher.dart`, `apps/mobile/lib/features/documents/data/local_document_vault_service.dart`, `apps/mobile/lib/features/documents/presentation/documents_screen.dart` | "Documents can be kept in an encrypted local vault." | "Every image is OCR'd automatically" |
| Ask Files | The document Q&A flow ranks local document chunks, streams answers and shows cited snippets/sources. | `apps/mobile/lib/features/documents/data/documents_repository.dart`, `apps/mobile/lib/features/documents/presentation/document_query_screen.dart` | "Ask Files answers from local document context and shows sources." | "The answer is guaranteed clinically complete" |
| On-device Gemma service | The mobile app uses `flutter_gemma` for local generation and embeddings support; model import/download/status flows exist. | `apps/mobile/lib/features/insights/data/on_device_ai_service.dart`, `apps/mobile/lib/features/insights/presentation/on_device_model_screen.dart` | "Gemma can run on-device after the model is available." | "The model is bundled in the APK by default" |
| On-device proof | Prompt builder and insights UI expose provider/runtime/model/cloud-used proof. | `apps/mobile/lib/features/insights/data/on_device_prompt_builder.dart`, `apps/mobile/lib/features/insights/presentation/insights_screen.dart` | "The recap includes a local proof card showing whether cloud was bypassed." | "No external service is ever used in every possible build" |
| Recaps | Daily, weekly, monthly and pre-visit recap modes exist with cautious prompt instructions. | `apps/mobile/lib/features/insights/presentation/insights_screen.dart`, `apps/mobile/lib/features/insights/data/on_device_prompt_builder.dart` | "Gemma helps summarize local context cautiously for review." | "Gemma diagnoses or triages" |
| Gemma Center | Chat-style Gemma screen and AI engine settings are implemented. | `apps/mobile/lib/features/insights/presentation/gemma_center_screen.dart` | "The Gemma Center lets the user ask for explanations from their local context." | "Medical chatbot gives treatment plans" |
| Deterministic Prevention Center | Rule-based prevention recommendations use profile factors and Italy policy. | `apps/mobile/lib/features/prevention_center/domain/prevention_center_engine.dart`, `apps/mobile/lib/features/prevention_center/domain/prevention_center_policy.dart`, `apps/mobile/test/prevention_center/prevention_center_engine_test.dart` | "Prevention suggestions are deterministic reminders to discuss with a doctor." | "AI decides screening eligibility" |
| Wearable context | Permissioned Health Connect / Apple Health collection exists on supported platforms for activity, sleep and heart metrics. | `apps/mobile/lib/features/wearables/data/wearable_health_service_impl_io.dart`, `apps/mobile/lib/features/wearables/presentation/wearables_screen.dart` | "Supported devices can contribute wearable summaries when permission is granted." | "Always-on automatic background wearable sync" |
| Dossier and reports | Local narrative reports and dossier/emergency PDF/JSON export flows exist. | `apps/mobile/lib/features/reports/data/reports_repository.dart`, `apps/mobile/lib/features/dossier/data/dossier_repository.dart`, `apps/mobile/lib/features/dossier/presentation/health_dossier_screen.dart` | "The app can package selected local context into shareable dossier-style exports." | "Clinician portal" or "EHR upload" |
| Localization scaffolding | English and Italian localization scaffolding exists. | `apps/mobile/lib/l10n`, `apps/mobile/README.md` | "The app is being prepared for English and Italian use." | "Complete production localization everywhere" |

## Claims To Keep Out Of The Video

- Do not claim diagnosis, prescription, dosage advice or emergency triage.
- Do not claim doctor approval workflows, clinician dashboards or hospital/EHR integration.
- Do not claim regulatory certification or clinical decision support approval.
- Do not claim real patient data is used in the demo.
- Do not claim automatic OCR for medication bottles or all photos.
- Do not claim the Gemma `.litertlm` model is bundled in the APK by default.
- Do not claim automatic background wearable sync unless it is shown and verified on device.
- Do not claim daily recap PDF export; only dossier/emergency PDF and JSON export are confirmed.
- Do not claim voice capture is fully automatic without user review. The implemented flow records speech, shows an editable transcript and then sends it to Gemma.
- Do not claim Gemma always fills every field. Missing fields can remain null and unclear symptoms can trigger clarification.

## Screen Recordings Needed

1. Home screen opening on seeded demo data.
2. Daily check-in voice flow: tap Speak, show editable transcript, tap Send to Gemma, show filled metrics and detected symptom chips.
3. Save a reviewed Gemma symptom draft showing severity out of 10, duration/body location when available, or show manual symptom entry as backup.
4. Medications screen showing schedule/adherence context and reminders.
5. Documents archive showing folders, upload/take photo options and Ask Files button.
6. Ask Files chat showing an answer with sources/cited snippets.
7. On-device model screen showing import/download/status controls.
8. Insights daily recap showing the on-device proof card and cautious summary.
9. Prevention Center showing deterministic sections and safety copy.
10. Wearables screen showing permissioned summaries if available.
11. Health Dossier screen showing PDF/JSON export actions.

## Real-Life Footage Needed

- Person at home trying to remember symptoms before an appointment.
- Phone next to paper notes, medication box without readable patient details and water glass.
- Person preparing a folder for a doctor visit.
- Over-shoulder phone shot using demo data only.

## Safe AI B-Roll Needed

- Abstract on-device chip animation.
- Local phone storage animation.
- "Cloud used: No" style proof badge, only when paired with the actual app proof screen.
- Lock/vault animation for local documents.

## Demo Data Rule

Use seeded demo data or freshly created fictional data only. Blur names, dates of birth, medication labels, document filenames and any accidental device notifications if they could identify a real person.
