# ClinDiary Architecture — Fase 1

## Obiettivo

Questa fase costruisce la baseline end-to-end del prodotto:

- autenticazione con access token + refresh token rotation
- onboarding con consenso dati sanitari
- profilo clinico e sotto-moduli base
- diario giornaliero con sintomi e parametri
- timeline clinica aggregata
- app Flutter con flow protetto e cache locale

## Backend

- `app/core`: configurazione, database, sicurezza, logging.
- `app/models`: entità SQLAlchemy per auth, profilo, diario e timeline.
- `app/repositories`: accesso dati separato dalla logica di dominio.
- `app/services`: orchestration di auth, onboarding, profile e journaling.
- `app/api/v1`: REST API per la Fase 1.
- `app/workers`: bootstrap Celery per job futuri.

## Mobile

- `app/`: router GoRouter, tema, dipendenze condivise.
- `features/auth`: login, registrazione, restore session.
- `features/onboarding`: completamento profilo iniziale e consenso.
- `features/daily_journal`: check-in rapido e inserimento sintomi adattivo.
- `features/timeline`: feed cronologico unico.
- `features/profile`: anagrafica clinica, allergie, condizioni, farmaci, familiarità.

## Confini architetturali

- business logic: `app/services`
- clinical rules: riservate a `app/rules` per le fasi successive
- AI logic: isolata in `app/ai`
- UI logic: `apps/mobile/lib/features/**/presentation`
- persistence: SQLAlchemy lato backend, Drift + secure storage lato mobile

