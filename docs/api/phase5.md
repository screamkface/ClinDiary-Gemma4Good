# ClinDiary API — Fase 5

Questa fase introduce comportamento trasversale e alcune estensioni concrete su notifiche e screenings.

## Header di risposta

Su tutte le risposte API/health:

- `X-Request-ID`
- `X-Response-Time-Ms`

## Rate limiting Auth

Applicato su:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/password-reset/request`
- `POST /api/v1/auth/password-reset/confirm`

Quando il limite e superato:

- status code `429`
- body:

```json
{
  "detail": "Too many auth requests. Please retry later."
}
```

- header aggiuntivi:
  - `Retry-After`
  - `X-RateLimit-Limit`
  - `X-RateLimit-Remaining`
  - `X-RateLimit-Reset`

## Screenings

### `GET /api/v1/screenings/catalog`

Nuovo query param opzionale:

- `region_code`

### `GET /api/v1/screenings/me`

Nuovo query param opzionale:

- `region_code`

### `POST /api/v1/screenings/recompute`

Nuovo query param opzionale:

- `region_code`

Il filtro restringe `regional_availability` alla regione richiesta, con fallback a `IT` se non disponibile.

## Notifiche

### `POST /api/v1/notifications/devices`

Registra o aggiorna un device token del paziente autenticato.

Request:

```json
{
  "platform": "android",
  "device_token": "demo-device-token",
  "device_label": "Pixel personale"
}
```

Response:

```json
{
  "id": "uuid",
  "platform": "android",
  "device_token": "demo-device-token",
  "device_label": "Pixel personale",
  "active": true,
  "last_seen_at": "2026-03-21T10:00:00Z"
}
```

### `GET /api/v1/notifications/preferences`

Campi aggiunti:

- `push_enabled`
- `email_enabled`
- `email_address`

### `PUT /api/v1/notifications/preferences`

Campi aggiornabili aggiunti:

- `push_enabled`
- `email_enabled`
- `email_address`

## Config runtime rilevante

- `RATE_LIMIT_ENABLED`
- `RATE_LIMIT_BACKEND`
- `RATE_LIMIT_AUTH_REQUESTS`
- `RATE_LIMIT_WINDOW_SECONDS`
- `RATE_LIMIT_PREFIX`
- `AI_PROVIDER`
- `AI_BASE_URL`
- `AI_API_KEY`
- `GEMINI_API_KEY`
- `OCR_PROVIDER`
- `OCR_MAX_PAGES`
- `NOTIFICATION_PUSH_PROVIDER`
- `NOTIFICATION_PUSH_WEBHOOK_URL`
- `NOTIFICATION_EMAIL_PROVIDER`
- `NOTIFICATION_EMAIL_FROM`
- `SMTP_HOST`
- `SMTP_PORT`

## Provider AI disponibili

- `rule_based`
- `openai_compatible`
- `gemini_ai_studio`

Per `gemini_ai_studio`:

- endpoint REST usato: `.../models/{model}:generateContent`
- auth header: `x-goog-api-key`
- model consigliato iniziale: `gemini-2.5-flash`
