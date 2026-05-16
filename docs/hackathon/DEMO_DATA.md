# Demo data

ClinDiary includes a synthetic local demo scenario for the Gemma 4 Good Hackathon.

The purpose of the demo data is to make the application reviewable without a real
backend account, real patient records, or private health information.

## Data policy

The demo data is:

- synthetic;
- local to the app demo path;
- created for demonstration and reproducibility;
- not based on real patient records;
- not intended for medical decision-making;
- not a substitute for clinical validation.

No real patient data is included.

## Demo scenario

The demo scenario represents a fictional adult user with local health diary data.

The scenario can include:

- daily check-ins;
- symptom notes;
- sleep, stress, and wellness context;
- medication adherence context;
- wearable-style summaries;
- timeline events;
- clinical document examples;
- extracted document text;
- prevention and screening examples.

The data is designed to demonstrate how local context can be summarized and
explained by Gemma 4 running on-device.

## May 2026 demo period

The main demo scenario is structured around May 2026.

The local demo may include:

- day-by-day health notes;
- variations in sleep, fatigue, stress, activity, and symptoms;
- medication adherence events;
- document/referto examples;
- pre-visit preparation context;
- prevention-related reminders.

This gives reviewers enough longitudinal context to test:

```text
Daily recap
Ask Gemma
Ask about this file
Pre-visit style summary
Prevention reminders
```

## Clinical documents

The demo documents are synthetic examples. They may include:

- report title;
- document type;
- exam date;
- extracted text;
- synthetic lab values;
- synthetic imaging-style report text;
- metadata needed by the app.

These examples are included only to demonstrate the selected-document question
answering flow.

When the user taps:

```text
Ask about this file
```

ClinDiary passes the selected document context to Gemma so the model can answer
using only that document context.

## Safety constraints

The demo data and prompts are designed around conservative safety rules.

ClinDiary should not:

- diagnose;
- prescribe medication;
- suggest dosage changes;
- triage emergencies;
- invent missing values;
- claim certainty from incomplete document text.

For document questions, answers should be grounded in the selected document
context. If the extracted text is incomplete or unavailable, the app should say so.

## Why synthetic data is used

Synthetic data is used because health data is sensitive. The hackathon demo should
be reproducible by reviewers without exposing real patient information.

The goal is to demonstrate the workflow:

```text
Local health context
        ↓
Safety-aware prompt
        ↓
Gemma 4 on-device
        ↓
Private explanation / recap
```

## Limitations

The synthetic demo scenario is not a clinical dataset and should not be used for
medical research, diagnosis, or treatment evaluation.

It is only a product and technical demonstration for the hackathon submission.
