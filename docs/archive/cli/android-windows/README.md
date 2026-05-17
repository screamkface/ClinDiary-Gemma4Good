# ClinDiary CLI - Android + Backend su Windows

Questo runbook raccoglie i comandi pronti da copiare e incollare per avviare ClinDiary su Windows con telefono Android.

## Prerequisiti rapidi

```powershell
flutter doctor
flutter devices
adb devices
```

## Avvio consigliato

### 1. Avvio completo via USB

Questo avvia infrastruttura, backend, worker, beat e `flutter run` sul device Android collegato via USB.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --device-id 608f2ab2
```

### 2. Avvio completo via Wi-Fi LAN

Usa l'IP locale del PC invece di `adb reverse`.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --device-id 608f2ab2 --prefer-lan
```

### 3. Avvio solo backend

Utile se vuoi tenere backend, worker e beat attivi e aprire l'app Android manualmente.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --backend-only
```

### 4. Avvio backend senza seed demo

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --backend-only --skip-seed
```

### 5. Avvio completo lasciando i processi in background

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --device-id 608f2ab2 --keep-background
```

### 6. Avvio con OCR opzionale

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_android_app.ps1 --with-ocr
```

## Stop

### Fermare backend, worker e beat

```powershell
powershell -ExecutionPolicy Bypass -File scripts/stop_android_backend.ps1
```

### Fermare anche PostgreSQL, Redis e MinIO

```powershell
powershell -ExecutionPolicy Bypass -File scripts/stop_android_backend.ps1 --down-infra
```

## Comandi manuali utili

### Infrastruttura

```powershell
docker compose -f infra/compose/docker-compose.yml up -d postgres redis minio minio-init
```

### Backend

```powershell
cd apps/backend
.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Worker Celery

```powershell
cd apps/backend
.venv\Scripts\python.exe -m celery -A app.workers.celery_app.celery_app worker --loglevel info --pool solo
```

### Beat Celery

```powershell
cd apps/backend
.venv\Scripts\python.exe -m celery -A app.workers.celery_app.celery_app beat --loglevel info
```

### Mobile Android

```powershell
cd apps/mobile
flutter pub get
flutter run -d 608f2ab2
```

### Mobile Android con IP del PC

```powershell
cd apps/mobile
flutter pub get
flutter run -d 608f2ab2 --dart-define=API_BASE_URL=http://192.168.1.195:8000
```

## Verifiche veloci

```powershell
flutter devices
adb shell getprop ro.product.model
Invoke-RestMethod http://127.0.0.1:8000/health
```

## Note

- Sostituisci `608f2ab2` con il `device-id` del tuo telefono.
- Se usi `--prefer-lan`, aggiorna l'IP del PC nel comando manuale o nello script se cambia rete.
- Per il solo backend, puoi aprire l'app sul telefono manualmente dopo l'avvio.
- Per abilitare il login Google, imposta `GOOGLE_OAUTH_CLIENT_ID` nel `.env` backend: lo script Windows lo passa automaticamente a Flutter come `GOOGLE_AUTH_CLIENT_ID`.
- Al primo avvio dell'APK, ClinDiary scarica automaticamente `gemma-4-E2B-it.litertlm` da Hugging Face e lo salva nella directory modello dell'app su Android.
