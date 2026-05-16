# ClinDiary — Local-first Health Diary powered by Gemma 4

ClinDiary is a mobile health diary prototype built for the **Gemma 4 Good Hackathon**.

The app helps a user collect daily health context — symptoms, notes, medications, basic trends, clinical documents, and preventive reminders — and then uses **on-device Gemma 4 inference** to turn that local context into careful, readable summaries.

ClinDiary is **not an AI doctor**.
It does not diagnose, prescribe medication, change dosages, or triage emergencies.
Its purpose is to help users remember and explain their health story more clearly.

---

## Hackathon focus

The submitted hackathon build focuses on one main idea:

> **A private, local clinical memory layer that uses Gemma 4 on-device to explain and summarize personal health context.**

The most important demo flows are:

1. **Local Daily Recap**  
   Generate a daily health recap from local demo diary data.

2. **Ask Gemma about health context**  
   Ask questions about the local profile, diary, symptoms, and available context.

3. **Ask about this file**  
   Open a clinical document/referto and ask Gemma to explain it using the selected document context.

4. **Proof of local inference**  
   Show that the request uses the local Gemma runtime and that external cloud AI is bypassed.

---

## What the submitted APK actually does

The hackathon APK is intended to be built with:

```text
HACKATHON_DEMO_MODE=true
LOCAL_ONLY_MODE=true
```

In this mode:

- the app runs without requiring the ClinDiary backend;
- demo health data is local/mocked for reproducibility;
- Gemma inference runs on the Android device through `flutter_gemma` and LiteRT-LM;
- the app shows provider/runtime/backend proof cards;
- external cloud AI is not used for the local Gemma request;
- clinical safety rules remain deterministic and separate from the model.

This makes the demo stable and reproducible for judges.

---

## Why local Gemma matters

Health context is personal. A user may not want every symptom, document, note, and medication detail sent to a cloud model.

ClinDiary demonstrates a different pattern:

```text
Personal health data
        ↓
Local app context
        ↓
Gemma 4 on-device
        ↓
Private recap / explanation
```

Gemma is used as a **local explanation layer**, not as a diagnostic engine.

---

## Core features

### 1. Daily health diary

The app can represent daily check-ins with information such as:

- symptoms;
- notes;
- mood, stress, and sleep context;
- medication-related context;
- wearable-style summaries;
- timeline events.

In the hackathon APK, this data is demo/local data so the app can be reviewed without a backend account or private user data.

---

### 2. Local Gemma recap

ClinDiary can generate a careful daily recap using Gemma running on-device.

The recap is designed to be:

- readable;
- non-diagnostic;
- cautious;
- based only on available local context;
- useful before a medical appointment.

Example intent:

```text
Summarize what happened today in a way I can explain to my doctor.
```

---

### 3. Ask Gemma

The app includes a Gemma-centered chat/assistant flow.

The assistant can answer questions using available local context, for example:

```text
What changed compared to yesterday?
What should I mention at my next appointment?
Summarize my recent symptoms in simple terms.
```

The assistant is instructed to avoid diagnosis, prescriptions, dosage changes, and emergency triage.

---

### 4. Ask about this file

ClinDiary includes a document area for clinical files/referti.

From a document detail screen, the user can choose:

```text
Ask about this file
```

The app then passes the selected document context to Gemma, such as:

- extracted text;
- lab values, when available;
- imaging report text, when available;
- document metadata.

This lets the user ask questions like:

```text
Explain this report in simple words.
Which values are marked as abnormal?
What are the key points I should ask my doctor about?
```

Gemma must answer only from the selected document context. If the document text is incomplete or unavailable, the app should say so clearly.

---

## What is deterministic vs what uses Gemma

ClinDiary deliberately separates deterministic health logic from generative AI.

### Deterministic logic

These parts are rule-based and should not depend on Gemma:

- red flags and safety boundaries;
- prevention center recommendations;
- screening reminders;
- medication reminders;
- alert logic;
- profile state;
- document metadata and parsing status.

### Gemma logic

Gemma is used only for language generation tasks such as:

- daily recap;
- document explanation;
- question answering over local app context;
- pre-visit style summaries.

This separation is important because Gemma should explain context, not make clinical decisions.

---

## Safety boundaries

ClinDiary uses conservative medical-safety boundaries:

- no diagnosis;
- no prescriptions;
- no medication dosage changes;
- no emergency triage;
- no replacement for a clinician;
- no claims based on missing data;
- document answers must be grounded in the selected document;
- abnormal values can be mentioned only if they are present in the document context.

Suggested wording inside the app:

```text
ClinDiary is not a medical device. It helps organize and explain your own health context. Always consult a qualified clinician for diagnosis, treatment, or urgent symptoms.
```

---

## Technical stack

### Mobile

- Flutter
- Riverpod
- Drift / local cache
- Android release build
- `flutter_gemma`
- LiteRT-LM `.litertlm` model runtime

### Local Gemma runtime

The app targets:

```text
Gemma 4 E2B LiteRT-LM
```

The model is installed or imported through the app flow and then used through the local `flutter_gemma` runtime.

The APK does not need a cloud model API for the local Gemma request.

---

## Android support

The hackathon path is focused on Android.

Recommended device/build assumptions:

- Android real device;
- `arm64-v8a`;
- release APK;
- local Gemma model downloaded or imported;
- CPU/GPU backend selectable;
- GPU can be used as default when stable on the test device.

The local Gemma path is currently not the main iOS demo path.

---

## Build the hackathon APK

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

Install it on a connected Android device:

```bash
adb install -r apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

---

## Runtime verification

After installing the APK:

1. Open ClinDiary.
2. Open the local Gemma / AI settings screen.
3. Prepare, download, or import the Gemma `.litertlm` model.
4. Run the local test prompt.
5. Verify the proof card.

The app should show information similar to:

```text
Provider: on_device_litertlm
Runtime: flutter_gemma / LiteRT-LM
Model: gemma-4-E2B-it.litertlm
Backend: GPU or CPU
External cloud AI used: No
```

---

## Suggested judge demo path

A short demo can follow this sequence:

1. Open the app and show that ClinDiary is a health diary, not a generic chatbot.
2. Show local/demo health data.
3. Open the Gemma/local AI screen.
4. Show the local runtime proof card.
5. Run a short Gemma test prompt.
6. Generate a local daily recap.
7. Open a clinical document/referto.
8. Tap **Ask about this file**.
9. Ask Gemma to explain the document in simple terms.
10. Close by showing that prevention, alerts, and safety rules remain deterministic.

---

## Demo video narrative

A possible 2–3 minute story:

```text
Before a medical appointment, the hard part is often not one symptom.
It is remembering the whole story clearly.

ClinDiary is a local-first mobile diary for daily health context.
It is not an AI doctor. It is a private memory layer.

The app keeps daily check-ins, symptoms, medication context, documents, and trends together.

When the user asks for a recap, Gemma 4 runs locally on the Android device.
The answer is generated from local context and external cloud AI is bypassed.

The same approach works for documents:
the user opens a referto, taps "Ask about this file", and Gemma explains only what is present in that document.

ClinDiary keeps clinical rules separate from the model.
Alerts, prevention, and medication reminders remain deterministic.
Gemma only helps turn personal context into clearer language.
```

---

## What is real in this prototype

Implemented or represented in the hackathon APK:

- Flutter mobile app;
- local/demo health data;
- local Gemma runtime path;
- local daily recap generation;
- Gemma chat over local app context;
- document-focused question answering;
- proof card for local inference;
- safety-oriented prompt design;
- deterministic prevention/alert separation;
- Android release APK.

---

## What is mocked or simplified

For hackathon reproducibility, some parts are intentionally simplified:

- demo data is mocked/local;
- no real patient data is required;
- no production clinical backend is required for the submitted APK;
- billing/subscription behavior is not the focus;
- external notification infrastructure is not the focus;
- full clinical validation is out of scope;
- real OCR quality depends on document type and available extracted text;
- the app is not certified as a medical device.

This is intentional: the goal is to demonstrate a privacy-preserving local Gemma workflow, not a production healthcare deployment.

---

## Repository structure

```text
apps/
  mobile/      Flutter Android app
  backend/     Backend code kept for the broader ClinDiary prototype

docs/          Hackathon notes and technical documentation
infra/         Local infrastructure files
scripts/       Development and demo scripts
```

---

## Useful commands

Analyze the mobile app:

```bash
cd apps/mobile
flutter analyze
```

Run tests:

```bash
cd apps/mobile
flutter test
```

Build the release demo APK:

```bash
./build_demo_apk.sh
```

Inspect Android logs during Gemma inference:

```bash
adb logcat -c

adb logcat -d | grep -i -E "GemmaTest|flutter_gemma|gemma|litert|LiteRT|OpenCL|GPU|CPU|FATAL|Exception|SIGSEGV|OOM|OutOfMemory|failed|error"
```

---

## Known limitations

- The hackathon Gemma path is Android-focused.
- The local model may need to be downloaded or imported before first use.
- Large local models can be slow depending on the phone.
- GPU support depends on the device/runtime.
- Document answers depend on the available extracted text or structured document data.
- The app does not diagnose, prescribe, or replace medical care.
- The submitted build is a reproducible demo build, not a production healthcare deployment.

---

## Privacy statement for the demo

In the hackathon demo build:

```text
Gemma inference runs locally on the Android device.
Demo health data is local/mocked.
External cloud AI is bypassed for local Gemma requests.
```

This is the core idea of ClinDiary:
**use local AI to help users understand their own health context without turning every personal detail into a cloud request.**
