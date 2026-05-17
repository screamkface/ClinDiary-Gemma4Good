# ClinDiary - Piano Esecutivo Legale e Regolatorio

Data: **31 marzo 2026**

> Nota importante: questo documento non e consulenza legale. Serve per trasformare i gap legali individuati in un piano operativo eseguibile.

## Obiettivo

Trasformare ClinDiary da:

- prodotto tecnicamente maturo ma non ancora pronto per un lancio pubblico compliance-ready

a:

- prodotto con percorso legale, privacy e regolatorio chiaro
- backlog eseguibile da engineering
- deliverable chiari da produrre con avvocato privacy, DPO e consulente MDR

## Come leggere questo documento

Ogni task ha:

- `ID`
- `Priorita`
- `Tipo`
  - `code`
  - `docs`
  - `vendor`
  - `legal`
- `Owner consigliato`
- `Cosa fare`
- `Output atteso`
- `Repo touchpoints`, se applicabili

## Regola generale

I task `legal` e `vendor` non possono essere "chiusi" solo con codice.  
I task `code` e `docs` invece possono essere preparati subito nel repo.

## Stato engineering nel repo

Al **31 marzo 2026** risultano gia portati avanti nel codice:

- `E-003` registro provider AI interno
- `E-004` payload AI distinti e minimizzati per finalita
- `E-005` gating backend dell AI esterna per profili minorenni
- `E-006` test/telemetria base per evitare logging di payload sanitari
- `E-007` account deletion con cleanup cloud + cleanup locale device
- `E-008` workflow portabilita piu esplicito in app con export PDF/JSON/scheda emergenza
- `E-009` cleanup retention schedulato per token, audit log e, se configurato, AI summaries
- `E-010` validazioni produzione su secret/debug/env
- `E-011` separazione env/CORS rinforzata via config
- `E-012` TTL ridotto e cleanup piu duro dei dossier share link
- `E-013` proof-of-concept di cifratura applicativa del vault locale documentale free
- `E-014` telemetria minima per provider/fallback AI
- `D-005` prima bozza tecnica di retention matrix nel repo
- `D-006` prima bozza tecnica di security runbook nel repo
- `D-007` prima nota tecnica di AI governance nel repo

Restano invece aperti i task che richiedono validazione o decisione esterna:

- tutti i task `legal`
- tutti i task `vendor`
- i documenti finali da sostituire alle versioni beta in-app

---

## Workstream 1 - Decisione regolatoria sul perimetro del prodotto

### L-001 - Assessment MDR iniziale

- Priorita: `Bloccante`
- Tipo: `legal`
- Owner consigliato: founder + consulente MDR
- Cosa fare:
  - far valutare formalmente se ClinDiary, nel suo posizionamento attuale, puo rientrare nel Regolamento UE 2017/745
  - includere:
    - recap AI
    - pre-visita
    - red flags
    - screening/prevenzione personalizzata
    - document query
- Output atteso:
  - memo formale con una di queste conclusioni:
    - `non medical device`
    - `borderline`
    - `medical device`
  - elenco delle feature considerate critiche
- Repo touchpoints:
  - `docs/legal/gdpr-italy-regolo-gap-analysis.md`
  - marketing copy, store listing, landing page, onboarding copy

### L-002 - Decisione di positioning

- Priorita: `Bloccante`
- Tipo: `legal`
- Owner consigliato: founder + product + consulente MDR
- Cosa fare:
  - decidere la narrativa ufficiale del prodotto
  - scegliere se ClinDiary e:
    - diario/persona health organizer
    - supporto organizzativo
    - strumento di supporto clinico
- Output atteso:
  - decisione scritta
  - elenco claim consentiti e claim vietati
- Repo touchpoints:
  - copy mobile
  - README pubblico
  - store description

### Task tecnici derivati da questo workstream

#### E-001 - Audit di tutto il wording prodotto

- Priorita: `Alta`
- Tipo: `code`
- Owner consigliato: engineering + product
- Cosa fare:
  - rivedere tutte le stringhe che possono sembrare diagnostiche o prescrittive
- Aree da controllare:
  - `apps/mobile/lib/features/insights/`
  - `apps/mobile/lib/features/reports/`
  - `apps/mobile/lib/features/screenings/`
  - `apps/mobile/lib/features/prevention_center/`
  - `apps/mobile/lib/features/documents/presentation/document_query_screen.dart`
- Output atteso:
  - elenco stringhe aggiornate
  - eventuali warning UI standardizzati

---

## Workstream 2 - Privacy e base giuridica

### L-003 - Definizione base giuridica

- Priorita: `Bloccante`
- Tipo: `legal`
- Owner consigliato: avvocato privacy / DPO
- Cosa fare:
  - definire formalmente:
    - base art. 6 GDPR
    - condizione art. 9 GDPR
  - distinguere:
    - trattamento principale dell'app
    - AI esterna
    - condivisione dossier
    - analytics/logging
- Output atteso:
  - matrice `finalita -> base giuridica -> categoria dati`

### D-001 - Informativa privacy finale

- Priorita: `Bloccante`
- Tipo: `docs`
- Owner consigliato: legal + founder
- Cosa fare:
  - trasformare la bozza attuale in testo finale
- Base di partenza:
  - `docs/architecture/privacy-ai-notice-draft.md`
- Output atteso:
  - `docs/legal/final-privacy-notice.md` oppure documento equivalente definitivo

### D-002 - Informativa AI finale

- Priorita: `Bloccante`
- Tipo: `docs`
- Owner consigliato: legal + founder
- Cosa fare:
  - produrre testo finale dedicato all'uso di provider AI esterni
- Output atteso:
  - `docs/legal/final-ai-notice.md` oppure documento equivalente definitivo

### E-002 - Collegare le informative in app

- Priorita: `Alta`
- Tipo: `code`
- Owner consigliato: engineering
- Cosa fare:
  - aggiungere link/pagine definitive alle informative in:
    - onboarding
    - privacy AI screen
    - settings
    - eventuale paywall AI
- Repo touchpoints:
  - `apps/mobile/lib/features/onboarding/presentation/onboarding_screen.dart`
  - `apps/mobile/lib/features/settings/presentation/privacy_ai_screen.dart`
  - `apps/mobile/lib/features/billing/presentation/billing_screen.dart`
- Output atteso:
  - navigazione completa verso testi legali finali

---

## Workstream 3 - DPIA, DPO e governance privacy

### L-004 - DPIA formale

- Priorita: `Bloccante`
- Tipo: `legal`
- Owner consigliato: DPO / consulente privacy
- Cosa fare:
  - aprire e completare DPIA
  - includere:
    - dati salute
    - wearable
    - family profiles
    - AI esterna
    - RAG documentale
    - share links
    - documenti locali free
- Output atteso:
  - DPIA completata con decisioni, rischi, contromisure e residual risk

### L-005 - Valutazione obbligo/opportunita DPO

- Priorita: `Alta`
- Tipo: `legal`
- Owner consigliato: avvocato privacy
- Cosa fare:
  - valutare formalmente se nominare DPO
- Output atteso:
  - memo con esito

### D-003 - Registro trattamenti

- Priorita: `Alta`
- Tipo: `docs`
- Owner consigliato: founder + privacy advisor
- Cosa fare:
  - redigere registro trattamenti con finalita, categorie dati, destinatari, retention, misure
- Output atteso:
  - `docs/legal/processing-activities-register.md` o documento equivalente

---

## Workstream 4 - Vendor Regolo e catena contrattuale

### V-001 - Vendor pack Regolo

- Priorita: `Bloccante`
- Tipo: `vendor`
- Owner consigliato: founder / legal ops
- Cosa fare:
  - raccogliere e archiviare:
    - privacy policy
    - terms
    - DPA
    - subprocessor list
    - security docs
    - data location statement
- Output atteso:
  - cartella interna o fascicolo vendor Regolo

### V-002 - Ruolo privacy del fornitore

- Priorita: `Bloccante`
- Tipo: `vendor`
- Owner consigliato: legal
- Cosa fare:
  - qualificare formalmente Regolo come:
    - responsabile
    - sub-responsabile
    - altro ruolo
- Output atteso:
  - nota legale firmata o approvata

### V-003 - Transfer assessment

- Priorita: `Alta`
- Tipo: `vendor`
- Owner consigliato: legal
- Cosa fare:
  - verificare se tutta la catena resta in UE/SEE
  - se no, valutare SCC / safeguards
- Output atteso:
  - transfer memo

### E-003 - Registro provider AI nel repo

- Priorita: `Media`
- Tipo: `docs`
- Owner consigliato: engineering
- Cosa fare:
  - creare documento interno che registri:
    - provider
    - modello
    - finalita
    - retention dichiarata
    - data location
- Output atteso:
  - `docs/legal/ai-provider-register.md`

---

## Workstream 5 - Minimizzazione dati e AI esterna

### E-004 - Profili di payload AI

- Priorita: `Alta`
- Tipo: `code`
- Owner consigliato: engineering
- Cosa fare:
  - definire payload diversi per:
    - daily
    - weekly
    - monthly
    - pre-visit
  - evitare che tutti i recap mandino sempre tutto
- Repo touchpoints:
  - `apps/backend/app/services/insight_service.py`
  - `apps/backend/app/ai/summary_provider.py`
- Output atteso:
  - builder di payload minimizzati per finalita

### E-005 - Feature flag AI esterna per minori / managed profiles

- Priorita: `Alta`
- Tipo: `code`
- Owner consigliato: engineering
- Cosa fare:
  - introdurre policy tecnica per bloccare o limitare AI esterna sui profili minorenni finche non validata
- Repo touchpoints:
  - `apps/backend/app/services/insight_service.py`
  - `apps/backend/app/services/profile_service.py`
  - `apps/mobile/lib/features/profile/`
- Output atteso:
  - gating esplicito lato backend

### E-006 - Audit tecnico "no raw prompts in log"

- Priorita: `Media`
- Tipo: `code`
- Owner consigliato: engineering
- Cosa fare:
  - aggiungere test o check per evitare che payload sanitari finiscano nei log
- Repo touchpoints:
  - `apps/backend/app/core/logging.py`
  - `apps/backend/app/ai/summary_provider.py`
  - `apps/backend/app/services/document_rag_service.py`
- Output atteso:
  - policy e test base

---

## Workstream 6 - Diritti GDPR

### E-007 - Flusso cancellazione account

- Priorita: `Bloccante`
- Tipo: `code`
- Owner consigliato: engineering
- Cosa fare:
  - implementare un flusso chiaro di account deletion
  - includere:
    - profilo
    - documenti
    - recap
    - share links
    - subscription state
    - token
- Stato attuale:
  - non emerge un endpoint dedicato nel backend
- Repo touchpoints:
  - `apps/backend/app/api/v1/auth.py`
  - `apps/backend/app/services/auth_service.py`
  - eventuale nuovo `account_service.py`
  - UI settings/profile
- Output atteso:
  - endpoint + schermata + procedura interna

### E-008 - Flusso richiesta export / portabilita

- Priorita: `Alta`
- Tipo: `code`
- Owner consigliato: engineering
- Cosa fare:
  - organizzare meglio l'export esistente dentro un workflow privacy esplicito
- Repo touchpoints:
  - `apps/backend/app/api/v1/dossier.py`
  - `apps/mobile/lib/features/settings/presentation/privacy_ai_screen.dart`
  - `apps/mobile/lib/features/dossier/`
- Output atteso:
  - UX coerente per export dati personali

### D-004 - Procedura diritti interessato

- Priorita: `Bloccante`
- Tipo: `docs`
- Owner consigliato: legal + operations
- Cosa fare:
  - scrivere procedura interna per:
    - accesso
    - rettifica
    - cancellazione
    - portabilita
    - limitazione
    - revoca consenso AI
- Output atteso:
  - `docs/legal/data-subject-rights-procedure.md`

---

## Workstream 7 - Retention e lifecycle dei dati

### D-005 - Retention matrix

- Priorita: `Bloccante`
- Tipo: `docs`
- Owner consigliato: legal + founder + engineering
- Cosa fare:
  - definire tempi di conservazione per ogni categoria
- Categorie minime:
  - profilo
  - documenti
  - recap AI
  - audit log
  - notifiche
  - share links
  - backup
  - dati locali
- Output atteso:
  - `docs/legal/retention-matrix.md`

### E-009 - Cleanup tecnico coerente con retention

- Priorita: `Alta`
- Tipo: `code`
- Owner consigliato: engineering
- Cosa fare:
  - implementare cleanup o scadenze automatiche dove richiesto dalla retention matrix
- Repo touchpoints:
  - share links
  - audit logs
  - report AI
  - backup policy integration

---

## Workstream 8 - Security production hardening

### E-010 - Secret management e config produzione

- Priorita: `Bloccante`
- Tipo: `code`
- Owner consigliato: engineering / devops
- Cosa fare:
  - rimuovere dipendenza pratica da default insicuri
  - usare secret manager / env production reali
- Repo touchpoints:
  - `apps/backend/app/core/config.py`
  - deploy docs
- Output atteso:
  - checklist produzione chiusa

### E-011 - CORS e environment separation

- Priorita: `Alta`
- Tipo: `code`
- Owner consigliato: engineering / devops
- Cosa fare:
  - restringere CORS ai domini reali
  - separare dev/staging/prod in modo netto
- Repo touchpoints:
  - `apps/backend/app/main.py`
  - deployment env

### E-012 - Hardening share links

- Priorita: `Alta`
- Tipo: `code`
- Owner consigliato: engineering
- Cosa fare:
  - ridurre TTL massimo
  - valutare PIN opzionale
  - migliorare audit e warning UI
- Repo touchpoints:
  - `apps/backend/app/schemas/dossier.py`
  - `apps/backend/app/services/dossier_service.py`
  - `apps/mobile/lib/features/dossier/`

### E-013 - Valutazione cifratura locale documenti free

- Priorita: `Alta`
- Tipo: `code`
- Owner consigliato: engineering
- Cosa fare:
  - decidere se introdurre cifratura applicativa del vault locale
- Repo touchpoints:
  - `apps/mobile/lib/features/documents/data/local_document_vault_service.dart`
- Output atteso:
  - proof-of-concept oppure decision memo con modello di rischio accettato

### D-006 - Runbook sicurezza

- Priorita: `Alta`
- Tipo: `docs`
- Owner consigliato: security / founder
- Cosa fare:
  - scrivere:
    - incident response
    - data breach response
    - vendor compromise response
- Output atteso:
  - `docs/legal/security-runbook.md`

---

## Workstream 9 - AI governance e processo interno

### D-007 - AI governance note

- Priorita: `Alta`
- Tipo: `docs`
- Owner consigliato: founder + engineering
- Cosa fare:
  - documentare:
    - modelli usati
    - finalita
    - fallback
    - limiti
    - human oversight
- Output atteso:
  - `docs/legal/ai-governance-note.md`

### D-008 - AI incident register

- Priorita: `Media`
- Tipo: `docs`
- Owner consigliato: operations / product
- Cosa fare:
  - tenere traccia di:
    - hallucinations rilevanti
    - output inappropriati
    - fallback ripetuti
    - incidenti vendor
- Output atteso:
  - template operativo

### E-014 - Telemetria minima per fallback AI

- Priorita: `Media`
- Tipo: `code`
- Owner consigliato: engineering
- Cosa fare:
  - migliorare metriche su:
    - fallback
    - timeout provider
    - error rate per provider
- Repo touchpoints:
  - `apps/backend/app/ai/summary_provider.py`
  - `apps/backend/app/core/metrics.py`

---

## Workstream 10 - Deliverable finali prima del go-live

### Pacchetto minimo da chiudere

Per dichiarare ClinDiary pronta a una fase di lancio piu seria devi avere almeno:

1. assessment MDR completato
2. privacy notice finale
3. AI notice finale
4. base giuridica formalizzata
5. DPIA completata o formalmente gestita
6. DPA Regolo raccolta e verificata
7. rights workflow definito
8. retention matrix definita
9. hardening produzione chiuso
10. policy minori definita

## Ordine pratico consigliato

### Sprint 1

1. `L-001`
2. `L-002`
3. `L-003`
4. `D-001`
5. `D-002`

### Sprint 2

1. `L-004`
2. `L-005`
3. `V-001`
4. `V-002`
5. `V-003`
6. `E-004`

### Sprint 3

1. `E-007`
2. `E-008`
3. `D-004`
4. `D-005`
5. `E-012`
6. `E-013`

### Sprint 4

1. `E-010`
2. `E-011`
3. `D-006`
4. `D-007`
5. `E-014`

## Cosa possiamo fare noi subito nel repo

Questi task sono implementabili subito da engineering senza attendere il legale:

- `E-001`
- `E-002`
- `E-003`
- `E-004`
- `E-005`
- `E-006`
- `E-007`
- `E-008`
- `E-009`
- `E-010`
- `E-011`
- `E-012`
- `E-013`
- `E-014`
- e tutti i task `docs` interni preparatori

## Cosa richiede invece intervento esterno reale

- `L-001`
- `L-002`
- `L-003`
- `L-004`
- `L-005`
- `V-001`
- `V-002`
- `V-003`

## File collegati

- overview:
  - `docs/legal/eu-italy-compliance-overview.md`
- gap analysis:
  - `docs/legal/gdpr-italy-regolo-gap-analysis.md`
- checklist:
  - `docs/legal/pre-launch-checklist.md`
