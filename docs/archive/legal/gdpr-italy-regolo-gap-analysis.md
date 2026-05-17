# ClinDiary - Gap Analysis GDPR / Italia / Regolo

Data: **31 marzo 2026**

> Nota importante: questo documento non e consulenza legale. Serve come base tecnica per una revisione con avvocato privacy, DPO e consulente MDR.

## Metodo

La valutazione qui sotto incrocia:

- comportamento reale del codice e del prodotto
- documentazione gia presente nel repo
- fonti ufficiali UE / Garante / Regolo

Classificazione usata:

- `Bloccante`: da chiudere prima di un lancio pubblico serio
- `Alta`: forte rischio o carenza importante
- `Media`: da rafforzare
- `Bassa`: miglioramento consigliato

## Sintesi esecutiva

ClinDiary oggi e **tecnicamente avanzata ma giuridicamente incompleta**.

I blocchi veri da chiudere prima del go-live sono:

1. privacy notice / AI notice finali
2. base giuridica art. 6 + art. 9 GDPR
3. DPIA
4. DPA e vendor due diligence su Regolo
5. retention e diritti interessato
6. hardening sicurezza produzione
7. assessment MDR

## Gap dettagliati

### 1. Informativa privacy e AI non finalizzata

- Priorita: `Bloccante`
- Stato attuale:
  - esiste solo una bozza in `docs/architecture/privacy-ai-notice-draft.md`
  - esiste una checklist in `docs/architecture/pre-production-gdpr-ai.md`
- Perche non basta:
  - per trattamenti sanitari devi fornire informativa chiara, specifica e aggiornata
  - oggi nel repo non c'e un testo finale pronto per produzione
- Azione:
  - creare informativa finale utente
  - creare AI notice separata e linkarla in onboarding / impostazioni / paywall AI

### 2. Base giuridica art. 6 e art. 9 non chiusa

- Priorita: `Bloccante`
- Stato attuale:
  - il consenso sanitario e registrato
  - il consenso AI esterno e separato e revocabile
  - riferimenti codice:
    - `apps/backend/app/services/profile_service.py`
    - `apps/backend/app/models/user_onboarding.py`
- Problema:
  - il fatto che il prodotto raccolga un consenso non equivale da solo ad aver definito correttamente la base giuridica
  - per dati relativi alla salute serve anche una condizione valida ex art. 9 GDPR
- Azione:
  - far definire formalmente dal legale:
    - art. 6
    - art. 9
    - ruolo del consenso AI rispetto alla base del trattamento principale

### 3. DPIA molto probabilmente necessaria

- Priorita: `Bloccante`
- Stato attuale:
  - dati salute
  - dati wearable
  - profili familiari / possibili minori
  - AI esterna
  - dossier, sharing, alert, prevenzione
- Perche:
  - il Garante e l'EDPB considerano ad alto rischio trattamenti che combinano categorie particolari di dati, soggetti vulnerabili e tecnologie nuove
- Azione:
  - eseguire DPIA formale prima della produzione
  - includere rischio AI, sharing, local storage e RAG documentale

### 4. Assessment DPO da fare

- Priorita: `Alta`
- Stato attuale:
  - nel repo non emerge una nomina DPO o una valutazione documentata sulla sua necessita
- Perche:
  - se il trattamento di dati sanitari e sistematico e su scala rilevante, la nomina puo diventare necessaria o comunque fortemente consigliata
- Azione:
  - fare valutazione formale con consulente privacy

### 5. DPA / vendor due diligence su Regolo ancora da formalizzare

- Priorita: `Bloccante`
- Stato attuale:
  - Regolo e gia integrabile come provider
  - la documentazione pubblica Regolo dichiara:
    - infrastruttura europea
    - zero retention
    - DPA disponibile
    - orientamento GDPR / AI Act
- Problema:
  - lato ClinDiary non risulta ancora chiusa la filiera contrattuale / documentale
- Azione:
  - raccogliere e archiviare:
    - DPA
    - privacy policy
    - terms
    - sub-processor list
    - security commitments
  - mappare formalmente ruolo privacy del fornitore

### 6. Minimizzazione verso AI esterna ancora non dimostrata

- Priorita: `Alta`
- Stato attuale:
  - il prompt usa un payload ricco:
    - profilo
    - condizioni
    - allergie
    - farmaci
    - wearable
    - documenti
    - recap precedenti
    - alert
  - riferimento:
    - `apps/backend/app/ai/summary_provider.py`
    - `apps/backend/app/services/insight_service.py`
- Problema:
  - il principio di minimizzazione impone di inviare solo cio che e necessario per la specifica finalita
- Azione:
  - introdurre profili di payload per tipo recap
  - ridurre default dei dati inviati al provider esterno
  - documentare i criteri di selezione del payload

### 7. Workflow diritti interessato incompleto

- Priorita: `Bloccante`
- Stato attuale:
  - export dossier PDF/JSON presente:
    - `apps/backend/app/api/v1/dossier.py`
  - revoca consenso AI presente
- Gap:
  - non emerge un flusso completo per:
    - cancellazione account
    - cancellazione totale dei dati
    - rettifica strutturata
    - limitazione del trattamento
    - portabilita completa
- Nota importante:
  - non ho trovato endpoint o flow chiari di account deletion nel backend
- Azione:
  - introdurre flussi e procedure documentate per diritti GDPR

### 8. Retention non definita

- Priorita: `Bloccante`
- Stato attuale:
  - non vedo una policy finale di retention per:
    - documenti
    - recap AI
    - audit log
    - share links
    - backup
- Azione:
  - scrivere retention matrix
  - implementare job / policy di cleanup dove richiesto

### 9. Sicurezza di produzione non pronta per default

- Priorita: `Alta`
- Stato attuale:
  - in config:
    - `debug=True`
    - `jwt_secret_key="change-me-in-production"`
    - CORS orientati a dev
  - file:
    - `apps/backend/app/core/config.py`
    - `apps/backend/app/main.py`
- Problema:
  - per dati sanitari devi poter dimostrare misure tecniche e organizzative adeguate
- Azione:
  - hardening produzione:
    - secret management
    - debug off
    - CORS stretti
    - env separation
    - incident response

### 10. Cifratura locale dei documenti free non applicata a livello app

- Priorita: `Alta`
- Stato attuale:
  - i documenti free sono salvati in locale su filesystem app:
    - `apps/mobile/lib/features/documents/data/local_document_vault_service.dart`
- Problema:
  - non vedo cifratura applicativa dei file a riposo
  - per dati sanitari e un punto molto sensibile, specie su device condivisi o compromessi
- Azione:
  - valutare cifratura locale file-level o key wrapping per vault locale
  - almeno documentare chiaramente il modello di sicurezza e i limiti

### 11. Share links dossier: area ad alto rischio da rafforzare

- Priorita: `Alta`
- Stato attuale:
  - esistono share links token-based, anonimi, revocabili e con scadenza
  - default `expires_in_days=7`, ma consentito fino a 365 giorni
  - file:
    - `apps/backend/app/api/v1/dossier.py`
    - `apps/backend/app/services/dossier_service.py`
    - `apps/backend/app/schemas/dossier.py`
- Rischio:
  - un bearer link a contenuto sanitario e molto delicato
  - 365 giorni massimi sono tanti per materiale clinico
- Azione:
  - ridurre TTL massimo
  - valutare PIN/second factor opzionale
  - watermark / access notice / auditing piu forte

### 12. Logging e audit: bene l'impostazione, ma va blindata

- Priorita: `Media`
- Stato attuale:
  - i log attuali sembrano concentrarsi su metadata tecnici e non su prompt raw
  - `structlog`:
    - `apps/backend/app/core/logging.py`
  - provider AI:
    - `apps/backend/app/ai/summary_provider.py`
- Punti da chiudere:
  - policy esplicita "no raw prompt / no health data in logs"
  - retention dei log
  - access control ai log

### 13. Gestione minori / profili familiari da chiarire

- Priorita: `Alta`
- Stato attuale:
  - ClinDiary supporta managed profiles / family profiles
  - il sistema usa `birth_date` e puo gestire soggetti minorenni
- Problema:
  - con dati sanitari di minori e AI esterna servono verifiche aggiuntive molto serie
  - da chiarire anche nel rapporto con Regolo e nei testi utente
- Azione:
  - decidere policy minori
  - eventualmente bloccare AI esterna per profili under 18 finche non validata

### 14. Rischio MDR / medical device qualification

- Priorita: `Bloccante`
- Stato attuale:
  - ClinDiary genera:
    - recap clinici
    - pre-visita
    - screening/prevenzione personalizzata
    - red flags
    - suggerimenti di follow-up
- Perche e critico:
  - se il prodotto viene qualificato come software destinato a fornire informazioni per prevenzione o monitoraggio, il MDR diventa centrale
- Azione:
  - fare assessment regolatorio formale subito
  - riallineare positioning, copy marketing e in-app wording in base all'esito

### 15. AI Act governance da rafforzare

- Priorita: `Alta`
- Stato attuale:
  - esiste gia un impianto prudente:
    - niente diagnosi
    - consenso AI
    - fallback rule-based
  - ma non vedo ancora un pacchetto completo di governance documentata
- Azione:
  - predisporre:
    - AI usage policy
    - human oversight policy
    - model/provider register
    - incident / fallback register
    - AI literacy minima per team

## Punti che vanno nella direzione giusta

- consenso AI esterno separato e revocabile
- enforcement backend del consenso
- fallback locale `rule_based`
- audit trail gia presente
- export dossier gia presente
- viewer URL a tempo
- preferenza per provider europeo come Regolo

## Piano operativo consigliato

### Fase A - Bloccanti

1. chiudere informativa privacy e AI finale
2. definire base giuridica art. 6 + art. 9
3. fare DPIA
4. chiudere vendor pack Regolo
5. assessment MDR
6. definire retention policy
7. introdurre account deletion / erasure workflow

### Fase B - Alta priorita

1. minimizzare payload AI
2. hardening sicurezza produzione
3. rafforzare share links
4. policy minori / family profiles
5. AI governance pack
6. valutare cifratura locale documenti free

### Fase C - Chiusura pre-lancio

1. runbook data subject requests
2. runbook data breach
3. vendor review annuale
4. tabella ruoli / trattamenti / finalita / retention

## Fonti ufficiali / primarie

- GDPR:
  https://eur-lex.europa.eu/eli/reg/2016/679/oj
- MDR:
  https://eur-lex.europa.eu/eli/reg/2017/745/oj
- AI Act:
  https://eur-lex.europa.eu/eli/reg/2024/1689/oj
- EDPB, DPIA FAQ:
  https://www.edpb.europa.eu/sme-data-protection-guide/faq-frequently-asked-questions/answer/what-data-protection-impact_en
- EDPB, DPO guidelines:
  https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/data-protection-officer_nb
- Garante Privacy, area app:
  https://www.garanteprivacy.it/temi/internet-e-nuove-tecnologie/app
- Garante Privacy, DPIA:
  https://www.garanteprivacy.it/home/docweb/-/docweb-display/docweb/9058979
- Codice Privacy italiano:
  https://www.normattiva.it/eli/id/2003/07/29/003G0218/CONSOLIDATED/20191230
- Regolo, European Inference:
  https://regolo.ai/european-inference/
- Regolo, Privacy Policy:
  https://regolo.ai/privacy-policy/
- Regolo, Terms & Conditions:
  https://regolo.ai/terms-and-conditions/
