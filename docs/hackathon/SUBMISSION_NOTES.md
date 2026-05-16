# Submission notes

ClinDiary was built for the Gemma 4 Good Hackathon.

## Project summary

ClinDiary is a local-first mobile health diary that uses Gemma 4 on-device to
help users summarize and explain their own health context.

The app focuses on appointment preparation, daily health memory, and document
understanding.

ClinDiary is not an AI doctor. It does not diagnose, prescribe, change medication
dosages, or triage emergencies.

## Relevant hackathon tracks

ClinDiary is most aligned with:

- Main Track: overall social impact and technical execution
- Impact Track: Health & Sciences
- Special Technology Track: LiteRT
- Potentially local-first mobile / edge-focused recognition where applicable

## Gemma 4 usage

Gemma 4 is used as a local language layer for:

- daily recap generation;
- pre-visit style summaries;
- local health-context Q&A;
- selected-document explanation.

The model is not used for deterministic clinical rules.

## Local-first design

The local-first design is central to the project.

Health context is sensitive. ClinDiary demonstrates a workflow where the user's
daily notes, symptom context, medication context, and document context can remain
close to the device while Gemma helps explain that information in plain language.

## Deterministic vs generative logic

Deterministic app logic includes:

- prevention and screening reminders;
- safety boundaries;
- medication reminder logic;
- document metadata;
- profile state;
- local demo data seeding.

Gemma-powered language generation includes:

- daily recap;
- document explanation;
- question answering over local context.

This separation reduces the risk of treating the model as a clinical authority.

## Demo scope

The hackathon demo uses synthetic local data for reproducibility.

The demo may show:

- a local health diary;
- May 2026 synthetic health context;
- clinical documents/referti;
- Ask about this file;
- local Gemma runtime proof;
- daily recap / pre-visit summary;
- prevention reminders.

No real patient data is included.

## Repository compliance checklist

Before final submission, verify:

```text
[ ] LICENSE file is present.
[ ] README contains a short License section.
[ ] THIRD_PARTY_NOTICES.md is present.
[ ] Demo data is documented as synthetic.
[ ] No real patient data is included.
[ ] No .env files are committed.
[ ] No signing keys are committed.
[ ] No model binaries are committed.
[ ] No APK/AAB build artifacts are committed.
[ ] README is clean and submission-facing.
[ ] Build instructions are available.
[ ] The Android APK has been tested on a real device.
[ ] The video demonstrates local Gemma inference.
[ ] The Kaggle submission includes repository, writeup, video, and demo file as required.
```

## License note

Unless otherwise noted, the original ClinDiary hackathon submission materials are
licensed under CC-BY 4.0.

Third-party dependencies, SDKs, pretrained models, and tools remain under their
respective licenses.
