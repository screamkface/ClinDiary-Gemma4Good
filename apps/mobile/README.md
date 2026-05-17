# ClinDiary Mobile

Flutter Android app for the ClinDiary Gemma 4 Good Hackathon submission.

This mobile app demonstrates:

- local synthetic health diary data;
- on-device Gemma 4 inference;
- daily recap generation;
- Ask Gemma;
- Ask about this file;
- prevention reminders and safety boundaries.

The submitted demo path is local-first and runs without a server component.

## Setup

```bash
flutter pub get
flutter analyze
flutter test
```

## Demo build

Use the root `build_demo_apk.sh` script or see `docs/hackathon/ANDROID_BUILD.md`.

The model binary is not included in this repository.
