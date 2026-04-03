# ClinDiary Architecture — Fase 4

## Obiettivo

Questa fase introduce:

- screening e prevenzione
- promemoria e inbox notifiche
- farmaci e aderenza
- preferenze notifiche utente e sync periodico background

## Backend

- `app/models/screening_*`, `patient_screening_status.py`, `notification.py`, `notification_preference.py`, `medication_schedule.py`, `medication_log.py`: nuove entita persistenti della fase
- `app/rules/screenings.py`: motore di eleggibilita deterministico basato su eta, sesso biologico, fumo e familiarita
- `app/services/screening_service.py`: seed catalogo Italia, recompute status, timeline screening e mark-done
- `app/services/medication_adherence_service.py`: logging terapia e timeline di aderenza
- `app/services/notification_service.py`: inbox engine con reminder check-in, screening, farmaci, documenti, alert e report, filtrati dalle preferenze utente
- `app/workers/notification_tasks.py` + Celery Beat: sync periodico reminder senza attendere l'apertura della schermata inbox
- `app/api/v1/screenings.py`, `medications.py`, `notifications.py`: surface REST della fase, incluse preferenze notifiche

## Mobile

- `features/screenings`: catalogo, screening personali e CTA di completamento
- `features/medications`: terapia attiva, orari base e conferma assunzione
- `features/notifications`: inbox interna con priorita, mark-read e toggle preferenze
- `features/home`: riepilogo rapido di inbox clinica e prevenzione
- `features/timeline`: mapping di `screening_due`, `screening_completed` e `medication_logged`

## Confini architetturali

- business logic: `apps/backend/app/services`
- regole cliniche: `apps/backend/app/rules`
- persistence: PostgreSQL per status, logs e notifiche; storage file resta separato
- background orchestration: Celery worker + beat per sync reminder periodico
- UI logic: `apps/mobile/lib/features/**/presentation`
- l'AI non decide eleggibilita screening e non sostituisce reminder o triage
