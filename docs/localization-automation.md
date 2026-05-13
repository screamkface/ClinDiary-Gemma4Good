# Localization Automation

This repo now includes a small localization pipeline so the app can become truly bilingual without duplicating Dart files.

## Entry Points

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/localization_pipeline.ps1 audit
```

macOS / Linux:

```bash
bash scripts/localization_pipeline.sh audit
```

Direct Dart usage from `apps/mobile`:

```bash
dart run tool/localization_pipeline.dart audit
```

## Commands

### `audit`

Scans `lib/**/*.dart` and writes the following files under `apps/mobile/build/localization/`:

- `audit_report.json`: raw findings
- `arb_translation_workfile.json`: UI copy for EN/IT translation
- `ai_translation_workfile.json`: AI prompt, fallback and demo text for EN/IT translation
- `locale_issues.json`: hardcoded locale and forced-language issues
- `summary.md`: quick overview

### `merge-arb`

After your local LLM fills `it` values in `arb_translation_workfile.json`, merge them back into the ARB files:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/localization_pipeline.ps1 merge-arb --input build/localization/arb_translation_workfile.json
```

This updates:

- `apps/mobile/lib/l10n/app_en.arb`
- `apps/mobile/lib/l10n/app_it.arb`

The script also generates placeholder metadata for entries like `{count}` or `{createdName}`.

### `build-ai-catalog`

After translating `ai_translation_workfile.json`, build JSON catalogs for prompt strings:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/localization_pipeline.ps1 build-ai-catalog --input build/localization/ai_translation_workfile.json
```

Outputs:

- `apps/mobile/build/localization/ai_catalog_en.json`
- `apps/mobile/build/localization/ai_catalog_it.json`

These catalogs are meant to feed a future prompt registry so the AI layer can switch language with the app.

## Recommended Minimal Workflow

1. Run `audit`.
2. Give `arb_translation_workfile.json` and `ai_translation_workfile.json` to the local LLM.
3. Save the filled JSON files in place.
4. Run `merge-arb`.
5. Run `build-ai-catalog`.
6. Update the code to replace hardcoded UI strings with `AppLocalizations` keys and to consume the AI catalogs.

## Important Notes

- Do not duplicate Dart files per language.
- Keep one codebase and translate through ARB plus prompt catalogs.
- Keep payload keys stable in English; only the user-facing prompt instructions and output language should change.
- `locale_issues.json` is the checklist for removing hardcoded `en_US`, `it_IT` and forced-language logic.
