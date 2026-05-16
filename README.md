# ClinDiary — Local-first Health Diary powered by Gemma 4

ClinDiary is a mobile health diary prototype built for the **Gemma 4 Good Hackathon**.

The app helps people organize daily health context — symptoms, notes, medication context, trends, and clinical documents — and uses **Gemma 4 running on-device** to turn that information into careful, readable summaries.

ClinDiary is **not an AI doctor**. It does not diagnose, prescribe medication, change dosages, or triage emergencies. Its purpose is to help users remember their own health story more clearly and prepare better conversations with clinicians.

---

## Vision

Before a medical appointment, the difficult part is often not one symptom. It is remembering the whole story:

- what happened over the last days or weeks;
- which symptoms changed;
- whether medications were taken consistently;
- what a clinical report said;
- which questions should be discussed with a doctor.

ClinDiary explores a privacy-first approach: keep personal health context on the device and use local AI to explain it in plain language.

```text
Daily health context
        ↓
Local ClinDiary memory layer
        ↓
Gemma 4 on-device
        ↓
Private recap / document explanation
```

---

## Core idea

ClinDiary uses Gemma 4 as a **local explanation layer**.

Gemma is not used to make clinical decisions. Instead, it helps transform user-owned context into clearer language:

- daily summaries;
- pre-visit summaries;
- document explanations;
- cautious answers over local app context.

The app keeps deterministic health logic separate from generative AI.

---

## Main demo flows

### 1. Local Daily Recap

ClinDiary can generate a daily recap from local diary context.

The recap is designed to be:

- readable;
- cautious;
- non-diagnostic;
- based only on available local context;
- useful before a medical appointment.

Example user intent:

```text
Summarize what happened today in a way I can explain to my doctor.
```

---

### 2. Ask Gemma

The app includes a Gemma-centered assistant flow that can answer questions using local context available in the app.

Example questions:

```text
What changed compared to yesterday?
What should I mention at my next appointment?
Summarize my recent symptoms in simple terms.
```

The assistant is instructed to avoid diagnosis, prescriptions, dosage changes, or emergency triage.

---

### 3. Ask about this file

ClinDiary includes a document area for clinical files and reports.

From a document detail screen, the user can choose:

```text
Ask about this file
```

The app then passes the selected document context to Gemma, such as:

- extracted report text;
- lab values, when available;
- imaging report text, when available;
- document metadata.

This allows the user to ask questions like:

```text
Explain this report in simple words.
Which values are marked as abnormal?
What are the key points I should ask my doctor about?
```

Gemma must answer only from the selected document context. If the document text is incomplete, the app should say so clearly.

---

## Why on-device Gemma matters

Health context is personal. A user may not want symptoms, medication notes, clinical documents, and appointment preparation data sent to a remote model.

ClinDiary demonstrates how a local Gemma 4 runtime can support:

- privacy-preserving summarization;
- reduced dependency on connectivity;
- safer handling of sensitive health context;
- transparent proof that AI processing can happen on the device.

The local model path is part of the product concept, not just an implementation detail.

---

## Safety boundaries

ClinDiary uses conservative safety boundaries:

- no diagnosis;
- no prescriptions;
- no medication dosage changes;
- no emergency triage;
- no replacement for a clinician;
- no claims based on missing data;
- document answers must be grounded in the selected document;
- abnormal values can be mentioned only if they are present in the document context.

Suggested in-app safety message:

```text
ClinDiary is not a medical device. It helps organize and explain your own health context. Always consult a qualified clinician for diagnosis, treatment, or urgent symptoms.
```

---

## Architecture overview

ClinDiary is built as a Flutter Android app with a local-first demo path.

```text
Flutter UI
  ↓
Riverpod providers and feature services
  ↓
Local health diary context
  ↓
Safety-aware prompt builder
  ↓
On-device Gemma service
  ↓
flutter_gemma + LiteRT-LM
  ↓
Gemma 4 local response
```

The model-facing layer is intentionally separated from deterministic app logic.

### Deterministic app logic

These features are rule-based and do not depend on Gemma:

- prevention and screening reminders;
- red-flag and safety boundaries;
- medication reminder logic;
- document metadata and parsing state;
- profile state;
- safety copy and disclaimers.

### Gemma-powered language layer

Gemma is used for:

- daily recap generation;
- pre-visit style summaries;
- document explanation;
- question answering over local context.

---

## Technical stack

### Mobile

- Flutter
- Riverpod
- Local persistence/cache
- Android release build
- `flutter_gemma`
- LiteRT-LM `.litertlm` runtime

### Local model runtime

ClinDiary targets:

```text
Gemma 4 E2B LiteRT-LM
```

The Android app can run Gemma locally through the `flutter_gemma` runtime, with CPU/GPU backend selection depending on the device.

---

## Demo data

The hackathon demo uses synthetic local health data so reviewers can explore the app without using real patient information.

The demo scenario includes:

- daily check-ins;
- symptom and note history;
- medication context;
- wearable-style trend summaries;
- timeline events;
- clinical documents with extracted context;
- prevention and screening examples.

No real patient data is included.

---

## Suggested evaluation flow

To understand the project quickly:

1. Open the app and view the local demo health diary.
2. Review daily check-ins and trend context.
3. Open the local Gemma/AI status screen.
4. Verify that Gemma is running locally.
5. Generate a daily recap.
6. Open a clinical document.
7. Tap **Ask about this file**.
8. Ask Gemma to explain the report in simple words.
9. Review the cautious response and safety boundaries.
10. Open the prevention area to see deterministic reminders separate from Gemma.

---

## What this prototype demonstrates

ClinDiary demonstrates:

- a local-first mobile health diary;
- on-device Gemma 4 inference;
- privacy-preserving daily recap generation;
- selected-document question answering;
- clear separation between deterministic health logic and generative language;
- conservative medical safety boundaries;
- a reproducible Android demo experience.

The larger vision is not to replace clinicians. The goal is to help people arrive better prepared, with clearer notes, better questions, and a more complete memory of what happened.

---

## Repository structure

```text
apps/
  mobile/      Flutter Android app
  backend/     Backend prototype code for the broader ClinDiary project

docs/          Hackathon and technical documentation
infra/         Local infrastructure files
scripts/       Development scripts
```

---

## Privacy statement

ClinDiary is designed around a simple principle:

> Personal health context should remain close to the user whenever possible.

In the hackathon demo path, Gemma inference runs locally on the Android device and uses synthetic local data for reproducibility.

**ClinDiary uses local AI to help users understand their own health context without turning every personal detail into a cloud request.**
