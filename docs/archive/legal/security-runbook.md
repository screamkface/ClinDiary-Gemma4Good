# ClinDiary - Security Runbook

Data: **1 aprile 2026**

## Obiettivo

Definire la risposta operativa minima per:

- incidente applicativo
- possibile data breach
- compromissione di un vendor esterno

## Trigger principali

- accessi anomali o massivi a dossier/documenti
- errori ripetuti su token, auth o share link
- output AI anomali collegati a un provider esterno
- compromissione di credenziali cloud, SMTP, push o vendor
- perdita o esposizione del vault locale documentale in scenario supporto/debug

## Triage iniziale

Entro 1 ora:

1. identificare ambiente coinvolto: `dev`, `staging`, `prod`
2. confermare se il problema riguarda:
   - disponibilita
   - integrita
   - riservatezza
3. congelare i log e gli artefatti utili
4. nominare un owner tecnico dell incidente

## Contenimento tecnico

### Auth / sessione locale

- cancellare sessione locale e secure storage sul device coinvolto
- verificare che il flusso demo/local-only non esponga dati di altri profili
- se in futuro viene ripristinato un backend, aggiungere rotazione token/segreti e invalidazione sessioni server

### Documenti / vault locale

- sospendere export/share locali se il problema riguarda file temporanei o vault
- verificare cifratura AES-GCM e chiavi `flutter_secure_storage`
- cancellare copie temporanee decrittate dove presenti
- se in futuro vengono ripristinati share link server, aggiungere revoca immediata, TTL e access log

### AI on-device / vendor futuri

- rimuovere o disabilitare il modello locale se il problema riguarda output AI anomali
- usare fallback locale prudente quando il runtime on-device non e affidabile
- sospendere `document query` se il problema riguarda citazioni o recupero locale
- se in futuro viene attivato un provider esterno, bloccarlo a livello config e seguire il DPA/vendor runbook

### Notifiche locali / canali futuri

- disattivare reminder locali se generano contenuto errato o sensibile sul lock screen
- verificare permessi notifiche e contenuto visualizzato
- se in futuro vengono attivati `smtp`, `fcm`, `apns`, disattivarli fino a rotazione chiavi

## Verifica impatto dati

Checklist minima:

- quali categorie dati sono coinvolte
- quanti utenti/profili
- se sono coinvolti dati salute
- se l accesso e` confermato o solo sospetto
- finestra temporale dell evento
- sistemi e vendor coinvolti

## Comunicazioni interne

- founder / owner prodotto
- engineering lead
- consulente privacy / DPO se nominato
- consulente MDR solo se l evento impatta feature cliniche rilevanti o claim regolati

## Decisione legale/privacy

Da fare con legal/privacy, non chiudibile solo con engineering:

- valutare se l evento integra un data breach notificabile
- valutare tempi e obblighi verso utenti e autorita
- archiviare decisione e motivazione

## Post-incident review

Entro 5 giorni lavorativi:

1. root cause
2. timeline
3. dati coinvolti
4. contromisure adottate
5. fix permanenti
6. backlog residuo

## Repo touchpoints utili

- `apps/mobile/lib/app/core/storage/local_database.dart`
- `apps/mobile/lib/features/documents/data/local_document_vault_service.dart`
- `apps/mobile/lib/features/documents/data/local_document_vault_cipher.dart`
- `apps/mobile/lib/features/insights/data/on_device_ai_service.dart`
- `apps/mobile/lib/features/settings/presentation/privacy_ai_screen.dart`
- `apps/mobile/lib/app/core/notifications/local_medication_reminder_service.dart`
