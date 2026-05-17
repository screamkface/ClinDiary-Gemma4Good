# ClinDiary — Local-first Health Diary powered by Gemma 4

ClinDiary is a local-first Android health diary prototype built for the Gemma 4 Good Hackathon.

It helps people organize symptoms, notes, medication context, wellness trends, and clinical documents, then uses Gemma 4 running on-device to create cautious summaries and document explanations.

ClinDiary is not an AI doctor. It does not diagnose, prescribe, change dosages, or triage emergencies.

## Vision

Preparing for a medical appointment is often difficult because the useful context is spread across many small moments: symptoms, sleep, stress, medication notes, wellness changes, questions, and clinical reports.

ClinDiary explores a privacy-first way to keep that story organized locally. The goal is to help people arrive at appointments with clearer notes, better questions, and a more complete memory of what happened.

## Core demo flows

### Local Daily Recap

ClinDiary generates a cautious daily recap from local diary context. The recap is designed to be readable, non-diagnostic, and useful for appointment preparation.

### Ask Gemma

The app includes an Ask Gemma flow for questions about local diary context. Answers are framed as organization and explanation support, not medical advice.

### Ask about this file

ClinDiary includes a document area for synthetic clinical files and reports. From a document detail screen, the user can ask about the selected file and receive a grounded explanation based on the available document context.

## Why on-device Gemma matters

Health context is personal. ClinDiary demonstrates how Gemma 4 can support privacy-preserving summarization and document explanation directly on the Android device.

The local model runtime allows the app to use local context without requiring a remote AI request for the submitted demo path.

## Safety boundaries

ClinDiary uses conservative safety boundaries:

- no diagnosis;
- no prescriptions;
- no medication dosage changes;
- no emergency triage;
- no replacement for a clinician;
- document answers must be grounded in the selected document;
- missing or incomplete context should be stated clearly.

## Architecture overview

```text
Flutter UI
  -> Local health diary context
  -> Safety-aware prompt builder
  -> On-device Gemma service
  -> flutter_gemma + LiteRT-LM
  -> Local response
```

The model-facing layer is separated from deterministic app logic. Prevention reminders, profile state, document metadata, and safety messages remain deterministic app behavior, while Gemma is used for language generation over local context.

## Technical stack

- Flutter
- Riverpod
- Local persistence/cache
- Android release build
- flutter_gemma
- LiteRT-LM

## Local model runtime

ClinDiary targets Gemma 4 on-device through `flutter_gemma` and LiteRT-LM. The Android demo path is centered on local inference and local health diary context.

## Demo data

The hackathon demo uses synthetic local demo data only. It includes fictional diary entries, medication context, wellness trends, and clinical document examples.

No real patient data is included.

## Suggested evaluation flow

1. Open app.
2. Review local diary.
3. Check local Gemma status.
4. Generate recap.
5. Open document.
6. Ask about this file.
7. Review cautious answer.
8. Open prevention area.

## What this prototype demonstrates

ClinDiary demonstrates a local-first Android health diary, on-device Gemma 4, document Q&A, privacy-preserving local context, and a clear safety separation between deterministic health logic and generative language support.

## Repository structure

```text
apps/
  mobile/      Main Flutter Android app

docs/
  hackathon/   Submission documentation
  archive/     Historical notes not used in the main demo narrative

scripts/       Utility scripts, when relevant
```

Installation instructions for the submitted Android demo APK are available in [`docs/hackathon/INSTALLATION.md`](docs/hackathon/INSTALLATION.md).

## Privacy statement

ClinDiary is designed around a simple principle: personal health context should remain close to the user whenever possible.

In the hackathon demo path, Gemma inference runs locally on the Android device and uses synthetic local data for reproducibility.

## License

Original ClinDiary submission materials are licensed under Creative Commons Attribution 4.0 International (CC-BY 4.0).

Third-party dependencies, SDKs, models, and tools remain under their respective licenses.
