# Android demo build

This document describes how to build the ClinDiary Android demo APK for the
Gemma 4 Good Hackathon.

## Purpose

The demo APK is intended to show the local-first Gemma workflow:

```text
Local app context
        ↓
On-device Gemma 4
        ↓
Private recap / explanation
```

The build is designed to be reproducible for reviewers and does not require real
patient data.

## Requirements

Recommended environment:

- Flutter stable
- Dart SDK bundled with Flutter
- Android SDK
- Android build tools
- Android real device
- arm64-v8a Android device for the local Gemma path

## Build command

From the repository root:

```bash
./build_demo_apk.sh
```

Equivalent manual build:

```bash
cd apps/mobile

flutter clean
flutter pub get

flutter build apk --release \
  --dart-define=HACKATHON_DEMO_MODE=true \
  --dart-define=LOCAL_ONLY_MODE=true
```

The APK is generated at:

```text
apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

## Install on Android device

```bash
adb install -r apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

For a clean test, uninstall any previous installation first:

```bash
adb uninstall it.clindiary.clindiary
adb install -r apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

## Runtime verification

After installing the app:

1. Open ClinDiary.
2. Open the local Gemma / AI status screen.
3. Confirm that the local model status is ready.
4. Run a short local test prompt if needed.
5. Generate a daily recap.
6. Open a clinical document.
7. Use **Ask about this file**.
8. Confirm that the response is grounded in the selected document context.

The app should show local inference information such as:

```text
Provider: on_device_litertlm
Runtime: flutter_gemma / LiteRT-LM
Model: Gemma 4 E2B LiteRT-LM
Backend: CPU or GPU
Remote AI request used: No
```

## Notes

The Android demo path is focused on local Gemma inference.

The local model and third-party runtime components remain under their respective
licenses and terms.

Do not commit generated APKs, model binaries, signing keys, `.env` files, or
local build outputs to the repository.
