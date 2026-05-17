# Hackathon Submission Checklist

## APK Build

- Build command: `cd apps/mobile && flutter build apk --release`
- Current APK: `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`
- Current APK size: `308676094 bytes` (about 308.7 MB)
- Full verification command run in this pass: `flutter clean && flutter pub get && flutter analyze && flutter test && flutter build apk --release`

## Tested Environment

- Build host: Linux desktop from `/home/nicola/Documents/ClinDiary-gemma/apps/mobile`
- Android target detected: `2506BPN68G`, Android 16 / API 36, `android-arm64`
- Install status: blocked by device policy with `INSTALL_FAILED_USER_RESTRICTED`
- Required next action: enable/approve USB app install on the device or use an emulator/device that permits APK installation

## Model And Runtime

- Provider shown in UI: `Gemma local`
- Runtime shown in UI: `flutter_gemma (LiteRT-LM)`
- Model artifact: `gemma-4-E2B-it.litertlm`
- Model source: Hugging Face revision-pinned URL configured in `OnDeviceAiService`, or user import through the app model screen
- Expected model size after download/import: `2588147712` bytes
- Release runtime settings: 4096-token context, GPU first with CPU fallback, speculative decoding off by default
- First launch requires internet unless a valid `.litertlm` model is imported through the app-owned import flow
- After successful install/verification, generation runs locally through `flutter_gemma`; health content is not sent to an external server by the local recap path

## Demo Path

- Install the APK on Android.
- Launch ClinDiary and sign in with the demo/local flow.
- Open the AI tab or Home > `AI Recap`.
- Confirm the `Preparing local Gemma model` bootstrap card shows current step, progress, model, provider, runtime, and app-owned model path.
- Let setup download/install and verify the model, or open `Manage model` and import a valid `.litertlm` file.
- Open `Manage model` and run `Run test prompt`.
- Confirm the response is non-empty and the status card shows provider/model/runtime/latency.
- Open AI Recap with seeded demo data and generate the daily recap.
- Confirm the recap is non-empty, conservative, and framed as patterns/questions to discuss with a clinician.

## Safety Notes

- ClinDiary is not an AI doctor.
- Generated summaries must not diagnose, prescribe, change medication/dosage, or provide emergency triage.
- Demo narration should say “patterns to discuss with a clinician”, not “medical conclusions”.
- If local AI fails, the UI must show unavailable/failed state and not claim inference succeeded.

## Known Limitations

- Real-device install/inference is still pending because the connected Android device rejected `adb install`.
- The model is not bundled in the APK; judges need first-run network access or an imported `.litertlm` model.
- Release signing is sufficient for local APK build output, but should be reviewed if distributing outside the Kaggle/demo context.
- Italian localization is incomplete; the English demo path is the safest for recording.

## Kaggle Writeup And Video Must Include

- Local-first privacy: diary/document context remains on device for local recap flows.
- On-device Gemma usage: `flutter_gemma` with LiteRT-LM and `gemma-4-E2B-it.litertlm`.
- Bootstrap UX: show the model preparation card, retry path, and explicit unavailable state.
- Real inference proof: show the model screen test prompt or a daily recap with provider/model/runtime visible.
- Safety boundary: no diagnosis, no prescription, no doctor replacement claims.
