# ClinDiary Architecture — Fase 2

## Obiettivo

Questa fase estende la baseline con un modulo documentale reale:

- archivio clinico con upload file
- storage persistente via MinIO
- worker Celery per processing asincrono
- estrazione testo per PDF digitali + OCR configurabile per immagini/scansioni
- parsing deterministico base per laboratorio e imaging
- revisione manuale di documenti e parsing
- nuovi eventi timeline documentali

## Backend

- `app/core/storage.py`: adapter storage con implementazioni `MinioStorageService` e `LocalStorageService`
- `app/models/clinical_document.py`: metadati, stato parsing, testo estratto e relazioni strutturate
- `app/models/lab_panel.py`, `lab_result.py`, `imaging_report.py`: proiezioni strutturate spiegabili
- `app/services/document_service.py`: orchestrazione upload, processing, review manuale, timeline e viewer token
- `app/services/ocr_service.py`: adapter OCR provider-agnostic (default `paddleocr`) per immagini/PDF scannerizzati
- `app/services/document_classifier.py`: classificazione deterministica senza AI
- `app/services/document_parser.py`: parser regex/keyword per lab e imaging
- `app/workers/document_tasks.py`: entrypoint Celery per processing documenti

## Mobile

- `features/documents/data`: picker locale, repository API e cache detail/list
- `features/documents/domain`: modelli tipizzati per documento, pannelli lab e referti imaging
- `features/documents/presentation`: lista, upload, dettaglio, review manuale e stato processing
- `features/timeline/presentation`: mapping dei nuovi eventi documentali senza cambiare il contratto API

## Confini architetturali

- business logic documentale: `apps/backend/app/services/document_service.py`
- parsing e classificazione clinica spiegabile: `apps/backend/app/services/document_parser.py`, `apps/backend/app/services/document_classifier.py`
- worker asincrono: `apps/backend/app/workers`
- UI documentale: `apps/mobile/lib/features/documents/presentation`
- persistence: PostgreSQL per metadata e strutture parse, MinIO per i file, Drift per cache locale mobile
