# Remotion Outline - ClinDiary Gemma 4 Good

This outline mirrors the CapCut script for a programmatic 180-second version. Use captured app recordings and safe abstract B-roll only. Do not synthesize fake clinical claims or fake patient records.

## Composition

- Composition name: `ClinDiaryGemma4GoodSubmission`
- Duration: 5400 frames
- FPS: 30
- Size: 1920x1080
- Duration in seconds: 180
- Ratio target by duration: 108 seconds app, 45 seconds real-life, 27 seconds AI B-roll

## Visual System

- Background: warm off-white or soft clinical gradient matching the app tone.
- Accent colors: muted teal, soft blue, gentle coral for warnings only.
- Font direction: use the app/default sans stack or Inter if available.
- Footer for AI scenes: `No diagnosis | No prescription | No emergency triage`.
- All screen recordings should sit inside a phone frame with rounded corners and subtle shadow.

## Suggested Components

- `ClinDiaryGemma4GoodSubmission`: top-level composition and scene timeline.
- `Scene`: wraps each timed segment with title, shot type and transition.
- `PhoneFrame`: displays app screen recordings with safe zoom/pan controls.
- `RealLifeFrame`: displays live footage with optional blur overlays.
- `AiBrollFrame`: displays abstract local-device/Gemma animations.
- `ProofBadge`: shows provider/runtime/cloud-used labels only when grounded by actual app capture.
- `SafetyFooter`: persistent safety disclaimer for AI-related scenes.
- `CaptionLine`: timed voiceover captions.
- `RatioMeter`: optional internal QA overlay, disabled for final export.

## Timeline Data

```ts
export const scenes = [
  {
    id: 'scattered-context',
    type: 'real',
    start: 0,
    duration: 360,
    asset: 'real_notes_phone_calendar.mp4',
    title: 'Health context gets scattered.',
    caption:
      'Before an appointment, the hard part is often not one symptom. It is remembering the whole story clearly.',
  },
  {
    id: 'home-demo',
    type: 'app',
    start: 360,
    duration: 450,
    asset: 'app_home_navigation.mp4',
    title: 'ClinDiary: private health memory',
    caption:
      'ClinDiary is a local-first mobile diary for daily health context. It is not an AI doctor. It is a private memory layer.',
  },
  {
    id: 'check-in-symptoms',
    type: 'app',
    start: 810,
    duration: 540,
    asset: 'app_daily_voice_checkin_gemma.mp4',
    title: 'Speak, review, send to Gemma',
    caption:
      'The user can start with voice. They speak in English, review the transcript and send it to Gemma. Gemma drafts daily metrics, notes and recognized symptoms with severity, duration and body location.',
  },
  {
    id: 'medication-context',
    type: 'real',
    start: 1350,
    duration: 390,
    asset: 'real_medication_context_no_labels.mp4',
    title: 'Context, not prescriptions',
    caption:
      'Medication context can be tracked too, but ClinDiary does not prescribe or suggest dosage changes.',
  },
  {
    id: 'documents-vault',
    type: 'app',
    start: 1740,
    duration: 510,
    asset: 'app_medications_documents_vault.mp4',
    title: 'Local reminders. Encrypted vault.',
    caption:
      'Medication schedules and local reminders stay with the diary. Documents can be stored in an encrypted local vault on the device.',
  },
  {
    id: 'ask-files',
    type: 'app',
    start: 2250,
    duration: 480,
    asset: 'app_ask_files_sources.mp4',
    title: 'Ask Files uses local document context',
    caption:
      'Ask Files searches local document context and shows sources, so the answer is grounded in what was actually saved.',
  },
  {
    id: 'gemma-local-broll',
    type: 'ai',
    start: 2730,
    duration: 540,
    asset: 'broll_on_device_gemma_chip.mp4',
    title: 'On-device Gemma assistance',
    caption:
      'When the model is available, Gemma can help summarize and explain context on-device, with cautious instructions and safety boundaries.',
  },
  {
    id: 'proof-card',
    type: 'app',
    start: 3270,
    duration: 510,
    asset: 'app_model_status_insights_proof.mp4',
    title: 'Provider: on-device. Cloud used: No.',
    caption:
      'The app exposes proof of the active AI path, including provider, runtime, model and whether cloud was used for the request.',
  },
  {
    id: 'recaps',
    type: 'app',
    start: 3780,
    duration: 480,
    asset: 'app_recaps_previsit.mp4',
    title: 'Recaps for review, not diagnosis',
    caption:
      'Daily, weekly, monthly and pre-visit recaps help turn local entries into a readable summary for the user to review.',
  },
  {
    id: 'rules-vs-ai',
    type: 'ai',
    start: 4260,
    duration: 270,
    asset: 'broll_rules_separate_from_ai.mp4',
    title: 'Rules stay separate from AI text',
    caption:
      'Safety logic stays deterministic. Generated text never decides emergencies, diagnosis or treatment.',
  },
  {
    id: 'prevention-center',
    type: 'app',
    start: 4530,
    duration: 270,
    asset: 'app_prevention_center.mp4',
    title: 'Deterministic prevention reminders',
    caption:
      'The Prevention Center uses rule-based reminders based on profile context, designed as discussion prompts with a clinician.',
  },
  {
    id: 'closing-memory-layer',
    type: 'real',
    start: 4800,
    duration: 600,
    asset: 'real_prepare_for_visit_closing.mp4',
    title: 'ClinDiary: private context before care',
    caption:
      'The goal is simple: less forgotten context, more prepared conversations and privacy by default. ClinDiary is a memory layer for health, powered by local data and Gemma-assisted summaries.',
  },
];
```

## Asset List

- `app_home_navigation.mp4`
- `app_daily_voice_checkin_gemma.mp4`
- `app_medications_documents_vault.mp4`
- `app_ask_files_sources.mp4`
- `app_model_status_insights_proof.mp4`
- `app_recaps_previsit.mp4`
- `app_prevention_center.mp4`
- `real_notes_phone_calendar.mp4`
- `real_medication_context_no_labels.mp4`
- `real_prepare_for_visit_closing.mp4`
- `broll_on_device_gemma_chip.mp4`
- `broll_rules_separate_from_ai.mp4`

## Implementation Notes

- Keep scene order aligned with the CapCut script so both versions can share voiceover and captions.
- Render captions from the `caption` field and keep them within safe title area.
- Use blur overlays on all real-life clips where labels, names, notifications or documents may be readable.
- Use `ProofBadge` only with actual captured app proof UI, not as a standalone unsupported claim.
- Add a final QA mode that totals scene duration by `type` and prints app/real/AI seconds before export.
- Keep optional Wearables and Dossier clips outside the main 180-second composition unless replacing another app scene.

## QA Checklist

- Final render is 180 seconds or less.
- App recording starts by 0:12.
- No real patient data appears.
- Every AI-related scene includes safety framing.
- No line implies diagnosis, prescription, dosage advice, emergency triage, doctor portal, hospital integration or regulatory approval.
- On-device Gemma wording says "when the model is available" or equivalent.
- Voice-dictation wording says the user reviews the transcript/draft before saving.
