# ClinDiary - Nota tecnica cifratura vault locale free

Data: **31 marzo 2026**

## Scopo

Documentare il proof-of-concept implementato per la protezione dei documenti locali del piano `free`.

## Stato attuale

ClinDiary cifra ora il vault locale documentale lato app:

- file locali cifrati con `AES-GCM 256`
- indice del vault cifrato
- chiave per utente salvata nel secure storage del dispositivo quando disponibile
- fallback in-memory solo per test o ambienti dove il secure storage non e disponibile
- apertura documento locale tramite copia temporanea decifrata on-demand

## Implementazione

Touchpoints principali:

- `apps/mobile/lib/features/documents/data/local_document_vault_cipher.dart`
- `apps/mobile/lib/features/documents/data/local_document_vault_service.dart`
- `apps/mobile/lib/features/documents/data/documents_repository.dart`
- `apps/mobile/lib/features/documents/presentation/document_detail_screen.dart`

## Modello di rischio coperto

Questo PoC alza la protezione contro:

- ispezione casuale dei file dal filesystem del dispositivo
- lettura diretta dell'indice del vault locale
- mescolamento dati tra utenti e profili sullo stesso device

## Limiti noti

- non sostituisce le protezioni native del dispositivo
- le copie temporanee decifrate usate per aprire/share il file vanno considerate dati sensibili e restano da rifinire ulteriormente se si vuole un lifecycle ancora piu stretto
- la chiave resta device-local: non e pensata per sincronizzazione multi-device

## Esito

Il task `E-013` puo essere considerato avanzato a **proof-of-concept implementato**, con successivo hardening possibile su:

- wipe piu aggressivo delle copie temporanee
- timeout/TTL delle preview locali
- eventuale protezione biometrica per aperture sensibili
