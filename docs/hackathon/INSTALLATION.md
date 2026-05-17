# ClinDiary Demo Installation

## Submitted artifact

The submitted Android demo APK is:

`ClinDiary-Gemma4Good-demo-arm64-v8a.apk`

## Requirements

- Android device
- arm64-v8a architecture
- Android SDK Platform Tools if installing via `adb`
- Sufficient free storage for the app and local model runtime

## Install

```bash
adb install -r ClinDiary-Gemma4Good-demo-arm64-v8a.apk
```

## Clean install

```bash
adb uninstall it.clindiary.clindiary
adb install -r ClinDiary-Gemma4Good-demo-arm64-v8a.apk
```

## Demo walkthrough

1. Open ClinDiary.
2. Use the synthetic local demo profile.
3. Open the local Gemma status screen.
4. Verify the on-device Gemma runtime.
5. Generate a local daily recap.
6. Open a clinical document.
7. Tap **Ask about this file**.
8. Ask: `Explain this report in simple words.`
9. Review the grounded, cautious response.
10. Open the prevention area to see deterministic reminders.

## Expected behavior

- The app runs as a local-first Android demo.
- The demo uses synthetic local health data.
- Gemma 4 runs on-device through `flutter_gemma` and LiteRT-LM.
- The app supports daily recap generation.
- The app supports selected-document explanations.
- No real patient data is included.

## Safety note

ClinDiary is a hackathon prototype and is not a medical device.

It does not:

- diagnose;
- prescribe medication;
- change medication dosages;
- triage emergencies;
- replace clinical care.

## Repository

https://github.com/screamkface/ClinDiary-Gemma4Good

## Demo video

https://www.youtube.com/shorts/W0eBKD5ZMtU
