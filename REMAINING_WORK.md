# Remaining Work

## Current App Work

### Completed
- Fixed the Gemma Center no-answer state shown as an empty assistant bubble: Gemma 4 chat inference now uses the plugin's intended thinking/topK/topP/temperature settings, serializes on-device generations, closes each chat session after use, stops/resets the runtime on timeout or cancellation, and unwraps `TextResponse` content instead of using debug `toString()` output.
- Hardened Gemma Center UI streaming so empty model completions become a visible failure message, empty placeholders are not saved to history, and stopping before the first token removes the placeholder instead of leaving a blank bubble.
- Added widget regression coverage for empty streamed Gemma answers and re-verified the shared Gemma/voice prompt paths.
- Verified the Gemma inference fix with `flutter analyze`, `flutter analyze lib/features/insights/data/on_device_ai_service.dart lib/features/insights/presentation/gemma_center_screen.dart test/insights/gemma_center_screen_test.dart`, `flutter test test/insights/gemma_center_screen_test.dart test/insights/gemma_coach_service_test.dart`, `flutter test test/insights/gemma_center_screen_test.dart test/insights/gemma_coach_service_test.dart test/daily_journal/voice_check_in_assistant_test.dart test/phase3/on_device_prompt_builder_test.dart`, and `flutter build apk --debug`.
- Clarified Gemma Center NPU detection: the app now reports whether the Gemma LiteRT-LM NPU backend is actually usable on the device/runtime, not whether the phone merely contains NPU hardware, and it surfaces the last backend probe error in AI settings.
- Hardened Gemma Center local inference startup: on-device generation now re-arms the active `flutter_gemma` model before opening it after app restarts, and stalled chat generations surface a timeout error instead of hanging forever on an empty typing bubble.
- Fixed Gemma Center compact chat layout by shrinking the snapped chat height on smaller viewports, hiding prompt suggestions once a conversation starts, and making the welcome panel scroll safely instead of overflowing.
- Added widget regression coverage for the compact Gemma Center chat flow and re-verified the existing Gemma coach / on-device insights tests.
- Tightened the local lab parser so demographic/document metadata rows like date of birth, patient ID, address and report date are no longer promoted into parsed lab results, while real measurements still keep range-based abnormal detection.
- Reordered the document detail flow so structured lab/imaging output is shown before raw OCR text, and added a direct structured-results edit entrypoint from the lab results section.
- Reworked manual review to prioritize structured lab editing first and keep OCR text behind an explicit show/hide toggle instead of leading with raw text.
- Added regression coverage for metadata filtering in the local lab parser plus widget coverage for the structured-first document detail/review flow.
- Fixed `Ask about this file` so Gemma can answer even when the selected document is the only available local context; document-focused questions no longer fail just because profile/journal/dossier caches are empty.
- Fixed Documents manual review so saved structured lab/imaging data is persisted in the local vault and reloaded on subsequent reads instead of being lost after the form submission.
- Fixed Documents manual review hydration so lab/imaging drafts can be seeded again from the extracted OCR text when the review opens before structured rows are already attached.
- Fixed Ask Files streaming fallback copy so it no longer says that no documents were uploaded when documents exist but none match the current question.
- Fixed "Ask about this file" / Gemma focus so the selected document is now fetched and injected into the clinical-question prompt payload, including OCR text and parsed lab/imaging data.
- Verified the Documents fixes with `flutter analyze lib/features/documents lib/features/insights test/documents/local_document_vault_service_test.dart test/insights/gemma_coach_service_test.dart`, `flutter test test/documents/local_document_vault_service_test.dart test/insights/gemma_coach_service_test.dart` and `flutter test test/documents/documents_flow_test.dart`.
- Added a deterministic Prevention Center engine driven by age, sex, smoking history, pregnancy status, family history and active conditions, including yearly exam suggestions like cardiology, thyroid review and abdominal ultrasound.
- Wired the Prevention Center screen to show a dedicated annual-exams section from the local engine output.
- Fixed Android notification small icons so local reminders use a dedicated notification drawable instead of the launcher icon, which restores the app mark in the notification drawer.
- Fixed a release build regression in the screenings screen by replacing the unsupported `Icons.folder_upload_outlined` with `Icons.upload_file_outlined` for the upload-referto action.
- **flutter_gemma migration**: Sostituito il bridge Kotlin LiteRT-LM con `flutter_gemma 0.15.0`. Rimosso `OnDeviceGemmaRuntime.kt`, `OnDeviceEmbeddingRuntime.kt`, `AndroidModelDownloader.kt`, method channel `clindiary/on_device_ai`. Aggiunto speculative decoding (MTP), NPU backend, streaming, function calling per voice check-in, Gecko 110M auto-install per embeddings, thinking mode support. Refactored GemmaCenterScreen con streaming reale, pulsante stop, e sezione ragionamento collassabile. Semplificato bootstrap e notifiche download. Rimosse dipendenze Gradle `litertlm-android` e `tasks-text`.
- Fixed the vaccination add/edit flow crash when dismissing the form with back by moving it to a dedicated bottom sheet that owns its controllers safely.
- Added a regression test for closing the vaccine form with back.
- Redesigned Ask Files as a chat-style experience with message bubbles, typing animation, simple scope pills and sources shown below the answer.
- Removed the duplicate Ask Files form/card by moving the input directly into the chat panel.
- Added a glowing AI-style Ask Files entry button in the Documents archive.
- Updated Gemma Center so the chat section fits in the first viewport on entry and the supporting tools use the same softer visual language.
- Simplified the Documents archive, upload, detail and query history copy by removing repeated local/on-device/provider/model wording from the primary UI.
- Added a localization automation pipeline (`audit`, `merge-arb`, `build-ai-catalog`) plus PowerShell/bash wrappers and docs so bilingual rollout can be driven from generated JSON workfiles instead of duplicating Dart files.
- Repaired the localization pipeline after the first bulk merge produced invalid ICU/ARB entries; safe audit output is now generated separately under `apps/mobile/build/localization_safe`.
- Removed the forced-English bootstrap path so the saved app language now actually loads at startup.
- Added language-aware Ask Files and Gemma history handling so saved answers are separated by active app language.
- Added a "Past answers" section inside Ask Files so recent document answers can be reopened without recomputing the same query.
- Localized the highest-impact AI generation paths so Ask Files answers and Gemma prompt instructions follow the active app language.
- Added targeted EN/IT localization keys for the updated Ask Files and Gemma Center surfaces and regenerated Flutter l10n files.
- Merged the user-translated safe workfiles from `apps/mobile/build/localization_safe/` into ARB/catalog outputs and verified they compile after filtering the remaining non-ICU-safe fragment.
- Replaced more hardcoded Ask Files and Gemma Center UI copy with generated l10n getters and switched their visible date formatting to the active app language.
- Localized the main `History` screen structure (app bar, tabs, section titles, empty states, copy/regenerate feedback and date formatting) and removed its hardcoded `en_US` / `it_IT` display paths.
- Localized the main `Profile` header sections plus the vaccination history flow (titles, action labels, dialogs, hero card, form labels and visible vaccination status copy).
- Verified the latest `history` / `profile` changes with `flutter analyze`, `flutter test test/profile/vaccination_history_screen_test.dart` and `flutter test test/history_routing_test.dart`.
- Finished the remaining `history` dynamic labels by moving event/document counters plus wearable/check-up chips and regeneration feedback onto l10n getters instead of code-side EN/IT branching.
- Finished the deeper `profile` migration inside the main edit dialog, create allergy/condition/medication/family-history dialogs, clinical switcher labels, quick facts, context cards and shortcut chips.
- Localized the `notifications` screen end-to-end, including section titles, switch labels, counts, permission/sync feedback, priorities and test-delivery formatting, and removed its hardcoded `en_US` date formatting.
- Localized the `documents` manual review and upload screens, including form labels, document type choices, validation copy, CTA labels and review row labels.
- Regenerated Flutter l10n output and re-verified with `flutter analyze`, `flutter test test/history_routing_test.dart`, `flutter test test/history_screen_overflow_test.dart`, `flutter test test/profile/vaccination_history_screen_test.dart`, `flutter test test/profile/family_profiles_screen_test.dart` and `flutter test test/documents/documents_flow_test.dart`.
- Finished the next localization slice on `documents_screen.dart`, `document_detail_screen.dart`, `family_profiles_screen.dart` and `clinical_episodes_screen.dart`, including localized dialog/menu labels, status chips, helper copy, date formatting, counts and file/profile detail text.
- Added the missing EN/IT l10n keys for those four screens, regenerated Flutter l10n output, and updated the affected widget tests to mount app localizations so the localized screens still test correctly.
- Cleaned the Home screen by removing the local-sync pill, Recent check-ups card, Quick actions card, secondary tools card and duplicate demo/profile sections.
- Moved profile selection into the Today card and consolidated Home navigation into the existing "What do you need?" card with the same soft shortcut styling and medication/notification badges.
- Changed wearable bootstrap refresh to a daily automatic check instead of repeated 15-minute polling while the app is open.
- Invalidated AI insight summaries after symptom changes, symptom follow-up responses and check-up deletion so newly generated AI prompts read the latest local diary payload.
- Updated medication, check-in and symptom follow-up reminder scheduling to try exact while idle delivery first and fall back to inexact scheduling, and added the Android exact-alarm permission for local medication reminders.
- Fixed the notifications-entry crash when pending symptom follow-up storage is empty or unreadable by sorting a mutable copy of the response list.
- Added regression coverage for consuming empty symptom follow-up response storage and sorted pending response replay.
- Changed app lock so PIN/biometric unlock is required only at app start for the current process session, not after every lifecycle pause/inactive event or immediately after enabling the setting.
- Made biometrics the primary app-lock path by auto-starting the biometric prompt when available and keeping the 6-digit PIN as an on-screen fallback.
- Expanded the deterministic Prevention Center engine with 40+ new rules covering cancer screening, bone health, AAA, lung LDCT, infectious disease, cardiovascular/metabolic checks, expanded vaccines (dTpa, pneumococcal, zoster, HPV), pregnancy planning, fall risk, hearing, and medication review.
- Created `RegionalPreventionPolicy` class with Italy (IT) policy including extended mammography (45-49, 70-74), extended colorectal (70-74), and cervical HPV-DNA (30-64) / Pap (25-29) sub-ranges.
- Created `PreventionRecord` model (standalone, not yet wired to ProfileBundle).
- Refactored `PreventionCenterEngine.build()` into 9 private section builder methods and 6 sub-builders for maintainability.
- Added deduplication logic across all recommendation sections.
- Added BMI helper for diabetes screening (BMI >= 25 as trigger).
- Added risk token lists for colon high-risk, breast high-risk, AAA, and bone-risk medications.
- Documented the full ruleset in `docs/prevention_center_rules.md`.
- Added 42 unit tests covering backward compatibility, cancer screenings, AAA, lung LDCT, STI risk, pregnancy, family history, edge cases (null birthDate, null sex, empty bundle), vaccines, cardiovascular/metabolic, bone health, fall risk, dedup, infectious disease, regional policy, breast high risk, and medication review.
- Imported the conservative LLM Prevention Center patch from `clindiary_patch_files/` into the current engine without downgrading the richer regional policy already in the app.
- Tightened prevention safety rules: dTpa is adult-only, pneumococcal review now covers chronic-risk adults, LDCT requires complete age/pack-year/current-or-recent-smoking eligibility, incomplete smoking exposure only creates a data-review item, AAA/high-risk cancer family-history logic now uses first-degree relatives, and folic-acid copy avoids dosage/prescription language.
- Removed duplicate early bone-density output by preferring `early_dexa_discussion` over the legacy annual bone-density item when postmenopause and fragility risk are both present.
- Re-verified the imported Prevention Center patch with `flutter test test/prevention_center/prevention_center_engine_test.dart`, `flutter test test/home/prevention_dossier_screens_test.dart` and `flutter analyze`.
- Fixed Gemma streaming hangs by adding first-visible-token and full-generation deadlines, resetting the runtime when a stream stalls, and re-arming already-installed models without starting a network install from the prompt path.
- Added a deterministic Ask Files streaming fallback so document questions return cited local evidence if Gemma times out or errors instead of leaving the chat waiting indefinitely.
- Improved local lab parsing for uploaded blood-result PDFs/text by auto-promoting generic blood-result uploads to `lab_report`, recognizing more Italian/English lab terms, splitting dense one-line PDF table extraction into rows, and preserving OK/out-of-range chips in document details and manual review.
- Added regression coverage for dense lab table parsing, generic blood-result upload auto-promotion, and Ask Files timeout fallback.
- Verified the inference/document fixes with `flutter test test/documents/documents_flow_test.dart test/documents/local_lab_text_parser_test.dart test/documents/local_document_vault_service_test.dart test/insights/gemma_center_screen_test.dart test/insights/gemma_coach_service_test.dart` and `flutter analyze`.

### Still Missing — Prevention Center

- Continue wiring real UI/storage flows for `PreventionRecord` completion history beyond the current model-level suppression support.
- Add structured fields for `lastMammogramDate`, `lastPapDate`, `lastColonoscopyDate` to enable "next due" calculations.
- Add `hysterectomy` / `cervixPresent` flag to avoid cervical screening after hysterectomy.
- Add `gestationalAge` / `dueDate` for pregnancy-specific timing rules.
- Add structured `firstDegreeRelative` field to enable `_hasFirstDegreeFamilyHistory()`.
- Add `steroidUse` / `immunosuppressed` boolean flags for more precise bone and vaccine rules.
- Add known genetic mutation fields (BRCA, Lynch, FAP) for high-risk breast/colorectal rules.
- Add personal history of polyps for colorectal risk.
- Add `cvdRiskScore` (SCORE, Framingham) for cardiovascular risk stratification.
- Create region-specific `RegionalPreventionPolicy` files (JSON or Dart) for non-IT regions.
- Localize recommendation copy (currently all English) via Flutter l10n.
- Add guideline version metadata so rules can be attributed to specific guidelines/sources.

### Still Missing
- If you want a separate "hardware NPU present" indicator, add an Android-native hardware capability probe; the current app now intentionally reports runtime/backend usability for Gemma rather than chipset existence.
- Run a real Android smoke test of Gemma Center after a cold app restart with an already-installed `.litertlm` model, to confirm the new no-network activation and stream-deadline path fixes the no-response state on device hardware.
- Smoke test the restored structured lab parsing/editing flow on a real Android device with real PDF/photo referti, especially OCR edge cases and the new edit-results entrypoint from document details.
- Smoke test the updated Documents flows on a real Android device with real lab/imaging files to validate OCR timing, manual review prefill, Ask Files retrieval quality and document-focused Gemma answers end-to-end.
- Review the remaining document review/manual-review screens for the same child-friendly visual language.
- Decide whether Ask Files history should also become a full chat transcript rather than expandable cards.
- Continue replacing hardcoded UI strings and hardcoded `en_US` / `it_IT` display formats across the rest of the app using the safe localization audit outputs.
- Fill the still-untranslated entries in `app_it.arb` / the safe workfiles; `flutter gen-l10n` still reports many Italian messages missing because only part of the safe export has been translated so far.
- Wire a runtime prompt registry to consume the generated `ai_catalog_*.json` files directly if you want prompt text to come entirely from generated catalogs instead of code-side branching.
- Continue replacing hardcoded UI strings in the next remaining screens beyond this slice, especially outside the four just-finished `documents` / `profile` screens.
- Validate exact alarm behavior on a real Android device after granting notification permission, especially across app restarts and locked-screen idle periods.
- Smoke test app lock on a physical Android device after a cold start, background/resume and settings toggle to confirm the biometric prompt only appears at startup.

### Known Bugs
- Gemma Center's NPU status is now accurate for Gemma runtime usability, but it is still not a pure hardware inventory check; a device can contain an NPU and still fail the Gemma backend probe if the required dispatch/runtime path is unavailable.
- Gemma Center now has stream deadlines and runtime reset for stalled generations, but the fix still needs a real-device cold-start validation because `flutter_gemma` model activation and LiteRT-LM backend behavior are device/plugin-managed.
- No known blocking regression from the structured lab-results restore; still worth validating with real-world OCR outputs because the parser is intentionally heuristic.
- No known blocking bug from the vaccine back flow after the regression test.
- The notifications-entry crash caused by sorting an immutable empty symptom follow-up response list has been fixed; still worth smoke testing on device after notification taps and app resume.
- The original bulk-translated localization workfiles under `apps/mobile/build/localization/` are not safe to merge directly into ARB because they contain complex interpolated strings; use the filtered `build/localization_safe/` export instead.
- Medication reminder timing now uses exact-while-idle scheduling with fallback, but OEM battery restrictions can still delay notifications until verified on target devices.

### Fixed
- Full `flutter test` now passes: 7 previously failing tests fixed.
  1. `auth/login_screen_test` — rimosso check su password prefillata (non più preimpostata)
  2. `auth/session_gate_screen_test` — mock demo mode ora restituisce `fakeSession`
  3-5. `phase3/on_device_prompt_builder_test` — aggiunto mock per `app_display_settings` cache key
  6. `phase3/phase3_screens_test` — allineate stringhe attese al widget reale (`AI Recap`, `Private local`, `Cloud esterno usato: No`)
  7. `test/phase3/on_device_insights_screen_test` — allineate stringhe attese (`On-device proof`, `Modello:`, `Local-only request:`)

### Next Recommended Step
- Run a real-device Gemma Center smoke test after a cold app restart with the installed model already on disk, specifically checking first response, timeout recovery, stop/retry, CPU/GPU switch, then validate the restored structured lab-results flow with real PDF/photo referti and continue the broader bilingual rollout.

## OpenCode Agent Skills Integration (May 9)

### Completed
- **dart-lang/skills**: Installed 9 official Dart agent skills to `.agents/skills/`
  - dart-add-unit-test
  - dart-build-cli-app
  - dart-collect-coverage
  - dart-fix-runtime-errors
  - dart-generate-test-mocks
  - dart-migrate-to-checks-package
  - dart-resolve-package-conflicts
  - dart-run-static-analysis
  - dart-use-pattern-matching
  
- **flutter/skills**: Installed 10 official Flutter agent skills to `~/.agents/skills/` (global)
  - flutter-add-integration-test
  - flutter-add-widget-preview
  - flutter-add-widget-test
  - flutter-apply-architecture-best-practices
  - flutter-build-responsive-layout
  - flutter-fix-layout-issues
  - flutter-implement-json-serialization
  - flutter-setup-declarative-routing
  - flutter-setup-localization
  - flutter-use-http-package

- **find-skills**: Meta-skill for discovering and suggesting available skills (installed globally)
- **caveman**: Added `juliusbrussee/caveman` skill to `.agents/skills/caveman` for ultra-compressed response mode

### Installation Notes
- Dart skills installed to project scope (`.agents/skills/`) - committed with project
- Flutter skills installed to global scope (`~/.agents/skills/`) - shared across all OpenCode projects
- All skills passed security assessments (Safe Gen/0 Socket alerts/Low Snyk risk, except flutter-use-http-package: High Risk)
- Skills are automatically discovered and loaded by OpenCode when running in the project

### Testing
- Created `.opencode/commands/test-dart-skills.md` for verifying skill installation and usage
- Skills available for invocation through OpenCode agents and commands

### Known Behavior
- OpenCode loads skills from both `.agents/skills/` (project) and `~/.agents/skills/` (global)
- Skills run with full agent permissions as documented in installation summary

## Completed (Previous)
- OpenCode project configuration scaffolded.
- Custom OpenCode subagents added (review, architect).
- Custom OpenCode slash commands added (continue, check, review).
- OpenCode CLI installed globally and verified (`opencode --version`, `opencode models --refresh`, `opencode mcp list`).
- Project `opencode.jsonc` hardened with repo-specific safe command allowlist.
- Serena MCP template added in disabled mode and Serena analysis subagent created.
- MCP OAuth attempts executed for Context7 and GitHub from CLI.

## Missing
- Add any missing provider logins and verify available models.
- Provide `CONTEXT7_API_KEY` environment variable (currently not set) so Context7 auth is persistent.
- Decide GitHub MCP auth mode (current endpoint reports incompatible OAuth dynamic registration).
- Validate project checks run cleanly in current environment.

## Known Issues
- `opencode mcp auth context7` reports success but `opencode mcp auth ls` still reports unauthenticated without `CONTEXT7_API_KEY` set.
- `opencode mcp auth github` fails with: `Incompatible auth server: does not support dynamic client registration`.

## Next Recommended Step
- Set `CONTEXT7_API_KEY`, re-run `opencode mcp list`, and optionally enable GitHub MCP only when needed.

## Video Submission Work (May 15)

### Completed
- Created `docs/video/FEATURE_INVENTORY.md` with source-backed demoable features, unsafe claims to avoid, required screen recordings, real-life footage and safe AI B-roll guidance.
- Created `docs/video/CAPCUT_SCRIPT_GEMMA4GOOD.md` with an English 180-second CapCut script, short Italian grounding note, early demo opening, shot ratio target and safety copy.
- Created `docs/video/REMOTION_OUTLINE_GEMMA4GOOD.md` with a matching 30 FPS / 5400-frame Remotion structure and QA checklist.
- Revised the video package to foreground the implemented Gemma 4 voice check-in flow: speech transcript review, Send to Gemma, filled daily metrics and recognized symptom drafts with severity, duration and body location.
- Created `docs/video/CAPCUT_CAPTIONS_GEMMA4GOOD.srt` with upload-ready CapCut captions for the revised voiceover, using the earlier short-caption `.srt` pacing as the reference.
- Performed a targeted code review of the video-critical flows and patched safe demo risks: clamped Gemma voice scores to 0-10, removed ambiguous fever duration metadata, made Ask Files combine semantic and keyword ranking, preserved streamed Ask Files answers in result objects, added dossier export fallback from the visible demo snapshot, improved on-device model status proof metadata, and removed the forced Italian medication pause date picker.
- Verified the video-critical changes with `flutter analyze`, `flutter test test/daily_journal/voice_check_in_draft_test.dart test/daily_journal/voice_check_in_assistant_test.dart test/documents/documents_flow_test.dart test/home/prevention_dossier_screens_test.dart test/phase3/on_device_prompt_builder_test.dart test/phase3/on_device_insights_screen_test.dart test/notifications/local_medication_reminder_service_test.dart`, plus a separate medication reminder test run.

### Still Missing
- Record the actual app clips listed in the feature inventory using seeded or fictional demo data.
- Capture the voice check-in flow carefully: speak in English, review/edit transcript, send to Gemma, verify generated fields/symptom chips, then save.
- Capture safe real-life footage with all labels, names and notifications blurred or unreadable.
- Decide whether optional Wearables and Dossier clips should replace another app scene or remain outside the final 180-second edit.
- Tighten the `.srt` timing after recording the final voiceover, because current timings are a paced draft aligned to the script rather than waveform-synced captions.
- Smoke test on a physical Android device with the Gemma `.litertlm` model installed before recording, especially voice capture, model proof, Ask Files streaming and Share sheet export.

### Known Bugs
- No known documentation blockers. The video still needs real device/app capture verification before submission.
- No blocking code issue found in static analysis or targeted widget/unit tests. Device-specific behavior still depends on microphone permission, model availability, Android share sheet and local file permissions.

### Next Recommended Step
- Record the required app screen clips in the order defined by `docs/video/CAPCUT_SCRIPT_GEMMA4GOOD.md`, then assemble a first CapCut rough cut under 180 seconds.
