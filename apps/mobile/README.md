# ClinDiary Mobile

App Flutter di ClinDiary.

Copre attualmente:

- auth e onboarding
- home dashboard
- diario giornaliero e symptom detail
- timeline clinica
- documenti clinici con review manuale
- insights, alerts e reports
- screenings, farmaci/aderenza e notifiche
- vault documentale locale cifrato, cache Drift e token storage sicuro
- AI on-device via flutter_gemma su LiteRT-LM (NPU/GPU, speculative decoding, streaming, function calling, thinking mode, embeddings)

## Stack

- Flutter
- Riverpod
- GoRouter
- Drift

## Struttura tecnica

- `lib/main.dart`: entrypoint app
- `lib/app/`: router, provider globali, config, tema, DI
- `lib/features/`: feature-first modules
- `lib/shared/widgets/`: componenti condivisi
- `test/`: widget/provider/repository test

Ogni feature e organizzata in:

- `data/`: repository client
- `domain/`: model lato mobile
- `presentation/`: schermate e UI logic

## Avvio locale

La configurazione pubblica corrente e local-first: non richiede un backend per il flusso mobile standard.

1. Installa dipendenze:

```bash
flutter pub get
```

2. Avvia l'app:

```bash
flutter run
```

Su Windows, dalla root del monorepo, puoi usare lo script Android helper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1
```

Per forzare esplicitamente la modalita locale puoi usare:

```bash
flutter run --dart-define=LOCAL_ONLY_MODE=true
```

Il modello Gemma `.litertlm` va importato, scaricato o provisionato sul device; non e incluso di default nel repository.

Per disattivare la modalita locale in esperimenti futuri, serve codice/infrastruttura backend reale e configurata:

```bash
flutter run --dart-define=LOCAL_ONLY_MODE=false
```

## Test e analisi

```bash
flutter analyze
flutter test
```

## Build demo APK (local-only)

Dalla root repository:

```powershell
powershell -ExecutionPolicy Bypass -File build_demo_apk.ps1
```

Oppure build manuale da `apps/mobile`:

```bash
flutter build apk --release \
  --dart-define=HACKATHON_DEMO_MODE=true \
  --dart-define=LOCAL_ONLY_MODE=true \
  --dart-define=API_BASE_URL=http://localhost:8000
```

## Dove modificare cosa

- nuova schermata/modulo: `lib/features/<feature>/`
- nuova route: `lib/app/router.dart`
- nuovo provider: `lib/app/providers.dart`
- nuova dipendenza applicativa: `lib/app/dependencies.dart`
- nuovo model mobile: `lib/features/<feature>/domain/`
- nuovo client API: `lib/features/<feature>/data/`
- nuovo widget condiviso: `lib/shared/widgets/`
