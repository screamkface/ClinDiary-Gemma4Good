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

### Auth / token

- ruotare `JWT_SECRET_KEY`
- invalidare refresh token attivi
- invalidare password reset token
- verificare log auth e rate limit

### Documenti / share links

- revocare immediatamente i dossier share link attivi
- disattivare temporaneamente la creazione di nuovi link
- verificare bucket/storage e access log

### AI / vendor esterni

- passare `AI_PROVIDER=rule_based` se serve isolamento rapido
- sospendere `document query` se il problema riguarda RAG o citazioni
- bloccare il provider compromesso a livello env/config

### Notifiche / email / push

- disattivare provider `smtp`, `fcm`, `apns` se la compromissione riguarda canali outbound
- lasciare solo `log_only` fino a rotazione chiavi

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

- `apps/backend/app/core/config.py`
- `apps/backend/app/main.py`
- `apps/backend/app/core/logging.py`
- `apps/backend/app/services/dossier_service.py`
- `apps/backend/app/services/retention_service.py`
- `apps/backend/app/ai/summary_provider.py`
- `apps/backend/app/services/document_rag_service.py`
