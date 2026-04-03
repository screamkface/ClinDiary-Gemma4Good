# ClinDiary Architecture — Fase 3

## Obiettivo

Questa fase introduce:

- insight narrativi prudenti
- motore red flags deterministico
- alert center
- report PDF server-side

## Backend

- `app/ai/summary_provider.py`: narrativa prudente provider-agnostic, con implementazione locale rule-based
- `app/rules/red_flags.py`: regole cliniche spiegabili per dolore toracico, dispnea, saturazione bassa, febbre persistente, sintomi neurologici, sanguinamento importante e peggioramento rapido
- `app/services/insight_service.py`: aggregazione dati e persistenza `ai_summaries`
- `app/services/alert_service.py`: sincronizzazione alert e timeline `ai_alert`
- `app/services/report_service.py`: generazione PDF, storage e timeline `report_generated`
- `app/api/v1/insights.py`, `alerts.py`, `reports.py`: surface REST della fase

## Mobile

- `features/insights`: selezione periodo e lettura della sintesi
- `features/alerts`: alert center con risoluzione manuale
- `features/reports`: generazione report e apertura PDF
- `features/home`: nuovi accessi rapidi e riepilogo alert aperti
- `features/timeline`: mapping di `ai_alert` e `report_generated`

## Confini architetturali

- rules engine: `apps/backend/app/rules`
- AI narrative: `apps/backend/app/ai`
- orchestration: `apps/backend/app/services`
- UI logic: `apps/mobile/lib/features/**/presentation`
- persistence: PostgreSQL per summary/alert/report metadata, storage S3-compatible per PDF e documenti
