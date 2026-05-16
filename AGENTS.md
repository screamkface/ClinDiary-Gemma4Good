# ClinDiary Agent Guide

## Purpose

This file gives coding agents the current working context for the ClinDiary repository. Keep it aligned with `README.md` and the implemented source, not with older backend-oriented roadmap notes.

ClinDiary is a privacy-first, local-first clinical diary mobile app. The current public workspace is centered on the Flutter app in `apps/mobile`, with local health journaling, an encrypted document vault, deterministic safety logic, and on-device Gemma-assisted summaries/document help.

## Current Repository Status

- Main implementation: `apps/mobile`
- Default app mode: local-only/demo-local mobile flow
- Production backend/private infrastructure: not included in this public workspace
- Older references to `apps/backend`, Celery, PostgreSQL, MinIO, Regolo retrieval, server billing, server reports or push/email delivery should be treated as historical/private-backend context unless matching source exists in this checkout
- Backend/cloud integrations in the public repo are mocked, excluded, or replaced by local deterministic app flows
- Do not reintroduce backend setup instructions as the default path unless the backend source is restored

## Key Facts

- Flutter target: 3.35+; check `apps/mobile/pubspec.yaml` for Dart/package constraints
- Architecture: feature-first under `apps/mobile/lib/features/<feature-name>/`
- Feature layers: `data/`, `domain/`, `presentation/` where applicable
- State and dependency injection: Riverpod
- Routing: GoRouter
- Local persistence: Drift over SQLite
- Secure storage: `flutter_secure_storage`
- Local notifications: `flutter_local_notifications` with timezone scheduling
- Native Android AI bridge: LiteRT-LM via Kotlin method channel
- Native Android embeddings bridge: MediaPipe Text Embedder where available
- Wearables: Health Connect / Apple Health through the `health` plugin plus Android native settings bridge

## Important Paths

- Root README: `README.md`
- App root: `apps/mobile`
- Mobile source: `apps/mobile/lib`
- App bootstrap/config/router: `apps/mobile/lib/app`
- Features: `apps/mobile/lib/features`
- Shared widgets: `apps/mobile/lib/shared/widgets`
- Mobile tests: `apps/mobile/test`
- Android project: `apps/mobile/android`
- Android Kotlin bridges: `apps/mobile/android/app/src/main/kotlin/it/clindiary/clindiary`
- iOS project: `apps/mobile/ios`
- Bundled assets/models: `apps/mobile/assets/models`
- Architecture docs: `docs/architecture`
- Hackathon/public disclosure docs: `docs/hackathon`
- Legal/privacy docs: `docs/legal`
- Release guide: `RELEASE_APK_GUIDE.md`

## Implemented User-Facing Areas

- Local/demo auth, session gate, login/register screens and onboarding
- Home dashboard with demo scenarios and quick actions
- Daily journal, check-ins, symptoms, vitals and notes
- Timeline, history and calendar-style views
- Local encrypted document archive with folders, breadcrumbs, search, upload/import, review and local file opening
- Deterministic/local document parsing for supported lab-style content
- Document Q&A using local document chunks, local retrieval/heuristics, embeddings support and on-device/fallback answer generation
- Gemma/AI center with model status/proof, daily/weekly/monthly/pre-visit recaps, clinical question answering and trend explanations
- On-device AI via `flutter_gemma` package (Dart API over LiteRT-LM): import, download, status, text generation, and embeddings
- Medication schedules, adherence logging and local reminders
- Notifications inbox and preferences
- Screening/prevention center, alerts, health dossier and reports
- Wearables integration through Health Connect / Apple Health plugin support
- Local diagnostics for pending operations, request traces and sync/debug state
- Localization scaffolding for English and Italian

## Architecture Notes

Prefer the existing feature-first shape:

```text
apps/mobile/lib/
  app/                    # bootstrap, router, DI/providers, config, theme
  features/<feature>/
    data/                 # repositories, services, DTO/mapping, local data access
    domain/               # domain models/rules when useful
    presentation/         # screens, widgets and UI state
  shared/widgets/         # reusable UI components
```

When adding or changing code:

- Keep changes small and local to the relevant feature when possible
- Use existing Riverpod provider patterns instead of introducing new global state mechanisms
- Keep deterministic clinical/safety logic separate from AI-generated narrative text
- Prefer local repositories/services already present in the feature before creating new abstractions
- Avoid adding compatibility layers unless there is persisted data, shipped behavior, external consumers or an explicit request
- Preserve the current visual/design language unless the user explicitly asks for redesign work

## AI And Model Reality

The app supports on-device AI via the `flutter_gemma` package (Dart API over LiteRT-LM).

- Text generation and embeddings use `flutter_gemma` (`package:flutter_gemma`) instead of custom Kotlin method channels
- Runtime behavior is GPU-first with CPU fallback where supported
- Target model family: Gemma 4 in LiteRT-LM `.litertlm` format
- Preferred model filename: `gemma-4-E2B-it.litertlm`
- The Gemma `.litertlm` model is not committed as a bundled repository asset by default
- The app can import a `.litertlm` model, download it from the supported Hugging Face source, or use a manually provisioned device model
- The expected Android model artifact is app-owned by `flutter_gemma` under the app documents directory, typically `/data/data/it.clindiary.clindiary/app_flutter/gemma-4-E2B-it.litertlm` on Android; do not make startup depend on arbitrary `/sdcard` scans or manual model placement
- The bundled embedding asset is `apps/mobile/assets/models/embeddinggemma-300m.tflite` (note: the actual model used at runtime is Gecko-110m-en downloaded from Hugging Face; the older `embeddinggemma-300m` asset path is historical and the directory is currently empty)
- Local embeddings support document retrieval/Q&A flows; do not describe the current public repo as Regolo/PostgreSQL/reranker-backed

Safety boundaries:

- No diagnosis
- No prescription or dosage instructions
- No emergency triage delegated to AI
- No red-flag, screening or prevention decisions made by generated AI text
- AI summaries must remain cautious, explainable and non-diagnostic

## Data Storage And Privacy

- Health diary data is stored locally in Drift/SQLite inside the app sandbox
- Sensitive document content is stored in the local encrypted vault where applicable
- The document vault uses AES-GCM 256 encryption and a secure-storage backed key where available
- Documents may be opened through temporary decrypted copies when required by the platform
- Local document limits are enforced in the app: 80 documents, 10 MB per file and 200 MB total
- Secure/session values use `flutter_secure_storage` where available
- No production backend credentials are needed for the default mobile flow
- No user health data should be sent externally by default

## Build And Run

Use the helper scripts when possible because they encode local workstation assumptions.

Windows preferred path:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1
```

macOS / Linux:

```bash
bash scripts/run_android_app.sh
```

Direct Flutter path:

```bash
cd apps/mobile
flutter pub get
flutter run
```

Known adb path on this workstation:

```text
C:\Users\Nicola\AppData\Local\Android\Sdk\platform-tools\adb.exe
```

## Model Setup Commands

Manual Android provisioning is no longer the default bootstrap path; prefer in-app download/import so the artifact is copied into app-owned storage:

```bash
bash scripts/push_android_litert_model.sh /path/to/gemma-4-E2B-it.litertlm
```

Device verification:

```bash
adb shell run-as it.clindiary.clindiary ls -lh app_flutter
```

Offline demos should pre-provision or import the `.litertlm` model. In-app model download requires network access.

## Testing And Verification

Standard mobile verification:

```bash
cd apps/mobile
flutter analyze
flutter test
```

When changing Android native code, also run an Android build or app launch when feasible:

```bash
cd apps/mobile
flutter build apk --debug
```

Test coverage exists across auth/session flow, home/dashboard, daily journal, document vault, insights/Gemma flows, timeline/history, notifications, wearables, devices, profile/family profiles, prevention/dossier screens, local database behavior and routing.

## Release Notes

- APK helper scripts live at the repo root: `build_demo_apk.ps1` and `build_demo_apk.sh`
- Read `RELEASE_APK_GUIDE.md` before signing/releasing
- Treat claims that the Gemma `.litertlm` model is bundled inside the APK as outdated unless asset packaging has been explicitly changed
- Large model files should usually be downloaded, imported or provisioned rather than committed

## Development Workflow For Agents

- Examine the codebase before making assumptions
- Prefer `Glob` and `Grep` for search
- Prefer `Read` for file inspection
- Use `apply_patch` for manual edits
- Do not use shell commands to read/write files when dedicated tools are available
- Keep edits minimal and focused on the user request
- Do not revert unrelated user or agent changes in the worktree
- Do not commit unless the user explicitly asks for a commit
- If the worktree is dirty, modify only files needed for the task and mention unrelated changes only when relevant
- For frontend work, preserve established ClinDiary UI patterns unless asked to redesign

## Documentation Alignment Rules

When updating documentation:

- Default to describing the implemented mobile/local-first app
- Make backend/private/cloud capabilities explicit as absent, mocked, historical or future unless source exists in the workspace
- Do not claim server endpoints, Celery workers, PostgreSQL vector retrieval, MinIO storage, server billing or server reports are available in this public checkout without verifying source files
- Clarify that Gemma `.litertlm` is imported/downloaded/provisioned, not bundled by default
- Keep safety boundaries prominent for every AI-related section
- Keep `README.md`, `AGENTS.md`, `apps/mobile/README.md` and release docs consistent when changing project status

## Troubleshooting

- Android builds on Windows may require Developer Mode for symlink support
- If Flutter tooling fails, verify `C:\Users\Nicola\tools\flutter` and Android SDK paths
- If on-device AI reports no model, check the app model screen and the Android external files `models/` directory
- If a large model makes builds or repository operations slow, use device provisioning/import instead of asset bundling
- If Health Connect or wearable flows behave differently in tests vs device runs, validate on a real Android device

## Where To Look Next

- `README.md`
- `apps/mobile/README.md`
- `docs/architecture/project-architecture-overview.md`
- `docs/architecture/actual-situation.md`
- `docs/hackathon/public-submission-playbook.md`
- `docs/hackathon/writeup-backend-mocked.md`
- `docs/legal/README.md`
- `docs/legal/local-vault-encryption-note.md`
- `RELEASE_APK_GUIDE.md`

## Ownership

Primary repo maintainer: Nicola, the local workspace owner. For architecture, release or legal changes, consult the relevant docs and keep public documentation conservative and source-backed.

## Execution Rules

Before coding:

- Read this file.
- Read `REMAINING_WORK.md` if present.
- Understand the current architecture before editing.

Workflow:

- Work in small phases.
- Do not implement unrelated features.
- After each completed task, update `REMAINING_WORK.md` with:
  - what was completed
  - what is still missing
  - known bugs
  - next recommended step

Quality:

- Run lint/analyze/tests before saying the task is done.
- Prefer simple architecture over overengineering.
- Do not introduce new frameworks, databases, or services unless strictly necessary.

Safety:

- Ask before destructive commands.
- Never commit secrets.
- Never rewrite large parts of the app without explaining why.
- Treat project `opencode.json` and `.opencode/` as executable-trust surface: review MCP `command` entries before running OpenCode in unknown repositories.
