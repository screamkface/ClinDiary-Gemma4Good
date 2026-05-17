# ClinDiary API v1 — Fase 3

Base path: `/api/v1`

## Insights

- `GET /insights/daily`
- `GET /insights/weekly`
- `GET /insights/pre-visit`

## Alerts

- `GET /alerts`
- `POST /alerts/{alert_id}/resolve`

## Reports

- `POST /reports/generate`
- `GET /reports/{report_id}`
- `GET /reports/{report_id}/content?token=...`

## Regole di comportamento

- le sintesi sono prudenti, spiegabili e non diagnostiche
- il rule engine red flags e separato dalla narrativa AI
- gli alert sono tracciati e risolvibili
- i report vengono generati server-side in PDF e resi scaricabili tramite URL firmata
