## May 2026 Demo Seed

ClinDiary now seeds a fixed local-only demo month for the primary hackathon profile when the app runs with:

```bash
--dart-define=HACKATHON_DEMO_MODE=true
--dart-define=LOCAL_ONLY_MODE=true
```

Seed version: `2026-05-hackathon-v1`

## What Is Seeded

- Primary profile: Marco Rossi
- Full month of daily check-ins for `2026-05-01` through `2026-05-31`
- Daily wearable summaries for the same month
- Medication adherence logs for the same month
- Timeline events across the month arc
- In-app notifications for the month arc
- Prevention records and prevention-center context
- Health dossier snapshot with May 2026 context
- Gemma center history and document query history examples
- Cached monthly report snapshot
- Local document vault seed for 5 synthetic documents:
  - `May 2026 metabolic panel`
  - `May 2026 lipid and glucose follow-up`
  - `May 2026 blood pressure diary note`
  - `May 2026 allergy / inflammation check`
  - `May 2026 pre-visit summary note`

## Clinical Story

- May 1-5: mild fatigue, poor sleep, higher stress
- May 6-10: home blood pressure sometimes elevated
- May 11-15: more walking and hydration, symptoms improve
- May 16-20: local lab documents added with discussion points around kidney markers, LDL, triglycerides, and HbA1c
- May 21-25: better sleep and mostly consistent medication adherence
- May 26-31: pre-visit preparation and clinician questions

All seeded content is synthetic and privacy-safe.

## Reset Or Reseed

If a device already contains older demo seed data, the new seed version should reseed automatically.

Developer helper available in code:

```dart
await DemoSeedData.resetAndReseed(
  database,
  localDocumentVaultService: localDocumentVaultService,
);
```

That helper clears the stored demo seed version key and reruns the normal seed flow.

If needed, clearing app data also forces a clean reseed on next launch.

## Judge Demo Script

1. Open the app in hackathon demo mode.
2. Navigate to history/calendar and open May 2026.
3. Show daily check-ins across the month.
4. Open wearables and highlight the visible trend improvement.
5. Open medications and show mostly consistent adherence with a few late or missed entries.
6. Open prevention center and dossier.
7. Open documents and show the five local synthetic reports/notes.
8. Open `May 2026 metabolic panel` or `May 2026 lipid and glucose follow-up`.
9. Use `Ask about this file` with prompts like:
   - `Explain this report in simple words.`
   - `Which values are abnormal?`
   - `What should I ask my doctor about?`
10. Open Gemma recap or trend flow and show that the app uses local May context.
11. Confirm the local proof/runtime card indicates no remote AI request is required.

## Known Limitations

- The seed uses synthetic structured text files in the local vault, not bundled scanned PDFs.
- The local document parser extracts what it can from the seeded text; responses should stay constrained to the values present.
- Real-device smoke testing is still required for final judge-path confirmation after APK install.
