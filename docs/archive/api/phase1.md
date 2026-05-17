# ClinDiary API v1 — Fase 1

Base path: `/api/v1`

## Auth

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/logout`
- `POST /auth/password-reset/request`
- `POST /auth/password-reset/confirm`

## Profile

- `GET /profile/me`
- `PUT /profile/me`
- `POST /profile/onboarding/complete`
- `GET /profile/conditions`
- `POST /profile/conditions`
- `GET /profile/allergies`
- `POST /profile/allergies`
- `GET /profile/medications`
- `POST /profile/medications`
- `GET /profile/family-history`
- `POST /profile/family-history`

## Daily Journal

- `POST /daily-entries`
- `GET /daily-entries`
- `GET /daily-entries/{id}`
- `PUT /daily-entries/{id}`
- `POST /daily-entries/{id}/symptoms`
- `POST /daily-entries/{id}/vitals`

## Timeline

- `GET /timeline`

## Note

- tutte le route cliniche richiedono bearer token
- ownership enforcement: ogni utente vede solo il proprio profilo clinico
- refresh token e password reset usano persistenza server-side con hash token

