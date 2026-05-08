# ClinDiary

ClinDiary is a privacy-first, local-first clinical diary mobile app. The current public repository is centered on the Flutter mobile implementation in `apps/mobile`, with local health journaling, an encrypted document vault, deterministic safety logic, and on-device Gemma-assisted summaries/document help.

## Current Status

This repository is the mobile-first public implementation.

- Main app: `apps/mobile`
- Current default mode: local-only/demo-local mobile app
- Production backend/private infrastructure: not included in this public workspace
- Backend/cloud integrations referenced by older docs are mocked, excluded, or replaced by local deterministic flows in the app
- Target mobile stack: Flutter 3.35+, Riverpod, GoRouter, Drift/SQLite, secure storage
- On-device AI target: Gemma 4 LiteRT-LM on Android, with model import/download/provisioning

The app is functional without a backend by default. `AppConfig.localOnlyMode` is enabled in the mobile code, so the app uses local/demo data and local repositories unless explicitly changed by future development.

## Implemented App Capabilities

- Local/demo auth flow, onboarding, profile and family-profile support
- Home dashboard with demo scenarios and clinical quick actions
- Daily journal, symptom entries, vitals, notes, timeline, history and calendar views
- Local encrypted document archive with folders, search, upload/import, review, file opening and local parsing
- Document Q&A using local document chunks, bundled embeddings support and on-device/fallback answer generation
- Gemma/AI center for daily, weekly, monthly and pre-visit style recaps, trend explanations and clinical question answering
- Android on-device generation through LiteRT-LM with GPU-first and CPU fallback runtime behavior
- Model management UI for importing, downloading, checking and removing `.litertlm` models
- Bundled local embedding model asset: `apps/mobile/assets/models/embeddinggemma-300m.tflite`
- Medication schedules, adherence logging and local reminder scheduling
- Notifications inbox and notification preferences
- Screening/prevention center, alerts, health dossier and reports
- Wearables integration through Health Connect / Apple Health via the `health` plugin and native Android settings bridge
- Local diagnostics for pending operations, request traces and sync/debug state
- Localization scaffolding for English and Italian

## Architecture

The mobile app follows a feature-first layout:

```text
apps/mobile/
  lib/
    app/                    # app bootstrap, routing, DI/providers, config, theme
    features/<feature>/     # data, domain and presentation layers by feature
    shared/widgets/         # shared UI components
  android/                  # native Android bridges for AI, embeddings and Health Connect
  assets/models/            # bundled model assets
  test/                     # unit and widget tests
```

Core implementation choices:

- State and dependency injection: Riverpod
- Routing: GoRouter
- Local persistence: Drift over SQLite
- Secure local secrets/session storage: `flutter_secure_storage`
- Native Android AI bridge: method channel `clindiary/on_device_ai`
- Native Android embeddings bridge: MediaPipe Text Embedder runtime where available
- Local notifications: `flutter_local_notifications` with timezone scheduling

## AI And Model Status

ClinDiary keeps deterministic clinical logic separate from generated narrative text.

- Red flags, screening, prevention and medication scheduling are deterministic app logic, not delegated to the model.
- AI outputs are assistive summaries/explanations and must not be treated as diagnosis, prescription, emergency triage or clinical decision automation.
- Android on-device text generation is implemented through LiteRT-LM in native Kotlin.
- The target model family is Gemma 4 in LiteRT-LM `.litertlm` format.
- The app can import a local `.litertlm` file, download the supported Gemma model from Hugging Face, or use a model provisioned onto the Android device.
- The Gemma `.litertlm` model is not bundled in the repository by default.
- The bundled `embeddinggemma-300m.tflite` asset supports local retrieval/document workflows.

Expected Android model location when provisioned manually:

```text
/sdcard/Android/data/it.clindiary.clindiary/files/models/
```

Preferred model filename used by the app/runtime:

```text
gemma-4-E2B-it.litertlm
```

## Storage And Privacy

ClinDiary is local-first by default.

- Health diary data is stored locally in Drift/SQLite.
- Documents are stored in a local encrypted vault.
- The document vault uses AES-GCM 256 encryption and a secure-storage backed key where available.
- Documents are opened through temporary decrypted copies when needed by the platform.
- Local document limits are enforced in the app: 80 documents, 10 MB per file and 200 MB total.
- No production backend credentials are required for the default mobile flow.
- No user health data is sent to external services by default.

## Quick Start

Use the repository scripts when possible because they encode local workstation defaults.

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1
```

macOS / Linux:

```bash
bash scripts/run_android_app.sh
```

Direct Flutter workflow:

```bash
cd apps/mobile
flutter pub get
flutter run
```

On this Windows workstation, the known Android SDK adb path is:

```text
C:\Users\Nicola\AppData\Local\Android\Sdk\platform-tools\adb.exe
```

## Model Setup

You can use the in-app model management screen to download/import a LiteRT-LM model. For manual Android provisioning, use:

```bash
bash scripts/push_android_litert_model.sh /path/to/gemma-4-E2B-it.litertlm
```

Then verify the model exists on device:

```bash
adb shell ls -lh /sdcard/Android/data/it.clindiary.clindiary/files/models
```

The model download path requires network access. Offline demos should pre-provision or import the `.litertlm` model before presenting on-device generation.

## Demo Path

Suggested local demo flow:

1. Run the mobile app in local-only mode.
2. Open the home dashboard and choose a demo scenario if needed.
3. Open the AI/Gemma or recap area.
4. Import, download or verify the on-device `.litertlm` model.
5. Generate a daily recap or document answer.
6. Show the provider/runtime proof card and confirm that deterministic safety logic remains separate from generated text.

## Testing

Run mobile analysis and tests from the app folder:

```bash
cd apps/mobile
flutter analyze
flutter test
```

The test suite includes coverage across auth/session flow, home/dashboard, daily journal, documents/vault behavior, insights/Gemma flows, timeline/history, notifications, wearables, devices, profile/family profiles, prevention/dossier screens, local database behavior and routing.

## Release Builds

Debug/release APK helper scripts are available at the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File build_demo_apk.ps1
```

```bash
bash build_demo_apk.sh
```

Recommended demo build flags (local-only hackathon flow):

```bash
flutter build apk --release \
  --dart-define=HACKATHON_DEMO_MODE=true \
  --dart-define=LOCAL_ONLY_MODE=true \
  --dart-define=API_BASE_URL=http://localhost:8000
```

See `RELEASE_APK_GUIDE.md` before producing a signed release. Treat any claim that the Gemma `.litertlm` model is bundled inside the APK as outdated unless the asset packaging has been explicitly changed.

## Repository Layout

```text
apps/
  mobile/                  # Flutter app and native mobile bridges
docs/
  architecture/            # architecture and implementation notes
  hackathon/               # public submission notes and mocked/excluded backend disclosure
  legal/                   # privacy, vault and legal notes
scripts/                   # run/model/device helper scripts
```

## Important Docs

- `apps/mobile/README.md`
- `docs/architecture/project-architecture-overview.md`
- `docs/architecture/actual-situation.md`
- `docs/hackathon/public-submission-playbook.md`
- `docs/hackathon/writeup-backend-mocked.md`
- `docs/legal/README.md`
- `docs/legal/local-vault-encryption-note.md`
- `RELEASE_APK_GUIDE.md`

Some older documentation may still mention a backend/Celery/PostgreSQL/MinIO/Regolo architecture. Those references should be read as historical/private-backend context unless matching source exists in this workspace.

## Safety Boundaries

- No diagnosis
- No prescription or dosage instructions
- No emergency triage delegated to the model
- No red-flag, screening or prevention decisions made by generated AI text
- AI summaries use only available local context and should remain cautious, explainable and non-diagnostic

## Known Limitations

- On-device LiteRT-LM generation is Android-specific in the current implementation.
- iOS support exists for the Flutter app, but the Gemma LiteRT-LM runtime path described here is Android-focused.
- The Gemma `.litertlm` model must be downloaded, imported or provisioned; it is not committed as a bundled repository asset.
- Wearables and Health Connect behavior should be validated on real devices for release confidence.
- Cloud backend, billing server, push/email delivery and external OCR/retrieval infrastructure are not part of the current public app implementation.
