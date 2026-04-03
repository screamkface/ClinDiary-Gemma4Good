# ClinDiary - Retention Matrix

Data: **1 aprile 2026**

> Documento tecnico-operativo. La versione finale deve essere validata con legal/privacy.

| Categoria dati | Stato attuale nel repo | Retention tecnica attuale | Direzione consigliata |
| --- | --- | --- | --- |
| Access token | TTL breve | 15 minuti | mantenere breve |
| Refresh token | persistiti e puliti da task | `RETENTION_REFRESH_TOKENS_DAYS`, default 30 giorni | confermare con legal |
| Password reset token | persistiti e puliti da task | `RETENTION_PASSWORD_RESET_TOKENS_DAYS`, default 7 giorni | confermare con legal |
| AI summaries | persistite | cleanup opzionale via `RETENTION_AI_SUMMARIES_DAYS` | definire retention finale per tipo report |
| Audit log | persistiti | cleanup via `RETENTION_AUDIT_LOGS_DAYS`, default 365 giorni | allineare con policy finale |
| Dossier share links | persistiti con scadenza | TTL ridotto e cleanup di scaduti/revocati | mantenere TTL breve |
| Documenti cloud | persistiti | nessuna retention automatica distruttiva | richiede decisione business/legal |
| Documenti locali free | vault locale cifrato | dipende dal device e da delete flow | esplicitare in informativa |
| Device measurements | persistite | nessuna retention automatica specifica | valutare retention clinica minima |
| Wearable daily summaries | persistite | nessuna retention automatica specifica | valutare retention finale |
| Report PDF | persistiti | seguono lifecycle report | definire retention finale |
| Notifiche | persistite | nessuna retention specifica oltre cleanup generico | definire retention finale |

## Già implementato nel codice

- cleanup schedulato di token e audit log
- cleanup di AI summaries se configurato
- TTL dei share link
- account deletion con cleanup locale/cloud

## Gap ancora aperti

- policy finale documenti cloud
- policy finale device/wearable
- policy backup fuori repo
- policy export condivisi dall utente

## Touchpoints tecnici

- `apps/backend/app/services/retention_service.py`
- `apps/backend/app/workers/retention_tasks.py`
- `apps/backend/app/core/config.py`
- `apps/backend/app/services/dossier_service.py`
- `apps/mobile/lib/features/documents/data/local_document_vault_service.dart`
