# Remaining Work

## Current App Work

### Completed
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

### Still Missing
- Review the remaining document review/manual-review screens for the same child-friendly visual language.
- Decide whether Ask Files history should also become a full chat transcript rather than expandable cards.
- Continue replacing hardcoded UI strings and hardcoded `en_US` / `it_IT` display formats across the rest of the app using the safe localization audit outputs.
- Fill the still-untranslated entries in `app_it.arb` / the safe workfiles; `flutter gen-l10n` still reports many Italian messages missing because only part of the safe export has been translated so far.
- Wire a runtime prompt registry to consume the generated `ai_catalog_*.json` files directly if you want prompt text to come entirely from generated catalogs instead of code-side branching.
- Continue replacing hardcoded UI strings in the next remaining screens beyond this slice, especially outside the four just-finished `documents` / `profile` screens.
- Validate exact alarm behavior on a real Android device after granting notification permission, especially across app restarts and locked-screen idle periods.
- Smoke test app lock on a physical Android device after a cold start, background/resume and settings toggle to confirm the biometric prompt only appears at startup.

### Known Bugs
- No known blocking bug from the vaccine back flow after the regression test.
- The notifications-entry crash caused by sorting an immutable empty symptom follow-up response list has been fixed; still worth smoke testing on device after notification taps and app resume.
- Full `flutter test` currently fails in unrelated existing tests: `history_mock_test.dart` lacks initialized `intl` locale data, and `phase3/on_device_prompt_builder_test.dart` hits unmocked `SharedPreferences` language storage.
- The original bulk-translated localization workfiles under `apps/mobile/build/localization/` are not safe to merge directly into ARB because they contain complex interpolated strings; use the filtered `build/localization_safe/` export instead.
- Medication reminder timing now uses exact-while-idle scheduling with fallback, but OEM battery restrictions can still delay notifications until verified on target devices.

### Next Recommended Step
- Run a device smoke test for Home navigation, smartwatch daily sync and medication reminders, then continue the bilingual rollout on the next highest-impact screens still listed by the safe localization audit.

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
