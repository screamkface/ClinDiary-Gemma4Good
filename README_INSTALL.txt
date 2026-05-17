ClinDiary — Gemma 4 Good Demo Installation

File:
ClinDiary-Gemma4Good-demo-arm64-v8a.apk

Recommended device:
- Android device
- arm64-v8a architecture
- Sufficient free storage for the app and local model runtime
- Internet connection may be needed only if the model download/import flow is used

Install with adb:
adb install -r ClinDiary-Gemma4Good-demo-arm64-v8a.apk

Clean install:
adb uninstall it.clindiary.clindiary
adb install -r ClinDiary-Gemma4Good-demo-arm64-v8a.apk

How to review the demo:
1. Open ClinDiary.
2. Use the synthetic local demo profile.
3. Open the local Gemma / AI status screen.
4. Verify the local Gemma runtime status.
5. Generate a daily recap.
6. Open a clinical document.
7. Tap "Ask about this file".
8. Ask a question such as: "Explain this report in simple words."
9. Review the cautious answer.
10. Open the prevention area to see deterministic reminders.

Expected behavior:
- The app runs as a local-first Android demo.
- The demo uses synthetic local health data.
- Gemma 4 runs on-device through flutter_gemma and LiteRT-LM.
- The app can generate daily recaps and selected-document explanations.
- The app does not require real patient data.

Safety note:
ClinDiary is a hackathon prototype. It is not a medical device. It does not diagnose, prescribe medication, change dosages, triage emergencies, or replace clinical care.

Repository:
https://github.com/screamkface/Clin-Diary---Gemma

Demo video:
https://www.youtube.com/shorts/W0eBKD5ZMtU
