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
- cache locale Drift e token storage sicuro

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

1. Installa dipendenze:

```bash
flutter pub get
```

2. Avvia l'app:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

Su Windows, dalla root del monorepo, puoi avviare backend e app Android insieme con:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1
```

Per usare l'app Android sul telefono via Wi-Fi locale senza dipendere da `adb reverse`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --device-id TUO_DEVICE_ID --prefer-lan
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --backend-only
powershell -ExecutionPolicy Bypass -File scripts/stop_android_backend.ps1
```

La build debug Android consente il traffico HTTP locale verso il backend di sviluppo del PC.

Per Android Emulator usa normalmente:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Test e analisi

```bash
flutter analyze
flutter test
```

## Dove modificare cosa

- nuova schermata/modulo: `lib/features/<feature>/`
- nuova route: `lib/app/router.dart`
- nuovo provider: `lib/app/providers.dart`
- nuova dipendenza applicativa: `lib/app/dependencies.dart`
- nuovo model mobile: `lib/features/<feature>/domain/`
- nuovo client API: `lib/features/<feature>/data/`
- nuovo widget condiviso: `lib/shared/widgets/`
