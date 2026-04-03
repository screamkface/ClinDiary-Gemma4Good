# ClinDiary API v1 — Fase 2

Base path: `/api/v1`

## Documents

- `POST /documents/upload`
- `GET /documents`
- `GET /documents/{document_id}`
- `POST /documents/{document_id}/process`
- `POST /documents/{document_id}/review`
- `GET /documents/{document_id}/content?token=...`

## Comportamento

- upload via `multipart/form-data` con whitelist MIME: `application/pdf`, `image/jpeg`, `image/png`
- limite payload: `20 MB`
- salvataggio file su storage S3-compatible tramite MinIO in locale
- `viewer_url` firmata a breve durata e adatta alla preview reale del file
- processing asincrono via Celery, con esecuzione eager nei test
- revisione manuale con conferma/correzione di metadati, testo e strutturato

## Parsing deterministico

- PDF digitali: estrazione testo reale con `pypdf`
- immagini e scan: OCR tramite provider configurabile (`OCR_PROVIDER`, default `paddleocr`) con fallback `ocr_pending` se OCR non disponibile o vuoto
- PDF scannerizzati: tentativo OCR via provider dopo fallback da `pypdf`
- classificazione senza AI tramite filename, MIME e keyword
- parsing strutturato attivo per:
  - referti laboratorio
  - referti imaging

## Timeline

Nuovi eventi documentali:

- `document_uploaded`
- `lab_result_summary`
- `imaging_summary`
