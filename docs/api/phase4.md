# ClinDiary API v1 — Fase 4

Base path: `/api/v1`

## Screenings

- `GET /screenings/catalog`
- `GET /screenings/me`
- `POST /screenings/recompute`
- `POST /screenings/{screening_id}/mark-done`

## Medications

- `GET /medications/logs`
- `POST /medications/{medication_id}/log`

## Notifications

- `GET /notifications`
- `GET /notifications/preferences`
- `PUT /notifications/preferences`
- `POST /notifications/{notification_id}/read`

## Note comportamentali

- l'eleggibilita screening e deterministica e spiegabile
- il catalogo iniziale e orientato al contesto Italia/SSN
- i reminder vengono deduplicati lato backend tramite chiavi stabili
- le notifiche restano in inbox interna app con `read_status` e priorita
- le preferenze permettono di disattivare singole categorie senza toccare l'alert center clinico
