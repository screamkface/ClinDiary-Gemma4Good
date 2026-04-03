# ClinDiary - Checklist Operativa Pre-Lancio

Data: **31 marzo 2026**

> Nota importante: questa checklist non sostituisce un parere legale. Serve per organizzare il lavoro tra prodotto, engineering, privacy, security e consulenza regolatoria.

## Obiettivo

Portare ClinDiary da:

- app tecnicamente avanzata ma non ancora compliance-ready

a:

- prodotto con rischio legale mappato
- documentazione privacy minima completa
- fornitori AI gestiti correttamente
- security baseline di produzione
- decisione chiara sul perimetro MDR

## Regola di utilizzo

Non eseguire i passi in ordine casuale.  
Le dipendenze sono importanti: prima si chiudono **qualificazione legale**, **privacy**, **vendor**, poi si passa a **hardening** e **go-live**.

---

## Fase 0 - Decisioni bloccanti iniziali

### 0.1 Definisci il posizionamento del prodotto

- Decidi se ClinDiary viene presentata come:
  - diario personale e cartella clinica personale
  - supporto organizzativo al paziente
  - supporto clinico / prevenzione / monitoraggio
- Questo punto impatta direttamente il rischio MDR.

### 0.2 Fai l'assessment MDR subito

- Coinvolgi un consulente regolatorio medical device.
- Chiedi una valutazione formale su:
  - recap AI
  - red flags
  - screening/prevenzione personalizzata
  - report pre-visita
  - query sui documenti clinici
- Output atteso:
  - `non medical device`
  - oppure `medical device / probabile medical device / area grigia`

### 0.3 Gate decisionale

- Se il consulente dice che ClinDiary rischia seriamente di rientrare nel MDR:
  - blocca il go-live pubblico
  - congela copy marketing e wording in-app
  - apri track regolatoria dedicata

---

## Fase 1 - Privacy foundation

### 1.1 Chiudi l'informativa privacy finale

- Scrivi la privacy notice finale per l'app.
- Deve coprire almeno:
  - categorie di dati trattati
  - finalita
  - basi giuridiche
  - tempi di conservazione
  - destinatari
  - diritti interessato
  - canali di contatto

### 1.2 Chiudi l'informativa AI separata

- Crea testo finale per l'uso di AI esterna.
- Deve spiegare chiaramente:
  - quando viene usata AI esterna
  - quali dati possono essere inviati
  - a quale fornitore
  - che i recap non sono diagnosi o prescrizioni
  - che il consenso e revocabile

### 1.3 Definisci formalmente la base giuridica

- Fai decidere dal legale:
  - art. 6 GDPR
  - art. 9 GDPR
- Output atteso:
  - memo interno firmato o validato
  - mappatura finale per ciascuna finalita

### 1.4 Verifica se serve DPO

- Fai una valutazione formale sulla necessita o forte opportunita di nomina DPO.
- Anche se non obbligatorio, in questo contesto e fortemente consigliabile.

### 1.5 Avvia la DPIA

- Apri una DPIA vera, non un appunto informale.
- Deve includere:
  - dati sanitari
  - wearable
  - family profiles / minori
  - AI esterna
  - RAG documentale
  - share links
  - storage locale

### Gate Fase 1

- Non passare oltre se non hai almeno:
  - bozza finale delle informative
  - base giuridica definita
  - DPIA aperta con owner e scadenza

---

## Fase 2 - Vendor AI e filiera Regolo

### 2.1 Raccogli il vendor pack Regolo

- Archivia in una cartella interna:
  - privacy policy
  - terms
  - DPA
  - subprocessor list
  - security / infrastructure statement
  - data location statement

### 2.2 Verifica il ruolo privacy del fornitore

- Chiarisci con il legale:
  - responsabile del trattamento?
  - sub-responsabile?
  - altro ruolo?

### 2.3 Verifica i trasferimenti

- Se Regolo processa interamente in UE, documentalo.
- Se esistono subfornitori extra-SEE, valuta SCC / transfer assessment.

### 2.4 Documenta la minimizzazione del payload

- Per ogni funzione AI, definisci:
  - quali campi invii
  - perche servono
  - quali campi non invii

### 2.5 Decidi policy su minori

- Se ClinDiary supporta profili under 18:
  - decidi se AI esterna e consentita
  - oppure blocca AI esterna per i profili minorenni fino a revisione legale

### Gate Fase 2

- Non attivare AI esterna in produzione se:
  - non hai DPA
  - non hai vendor due diligence
  - non hai policy payload minimization

---

## Fase 3 - Diritti GDPR e governance dati

### 3.1 Implementa il workflow di cancellazione account

- Serve un flusso chiaro per:
  - richiesta cancellazione account
  - cancellazione dati backend
  - cancellazione storage documenti
  - invalidazione share links
  - gestione backup

### 3.2 Completa la portabilita

- L'export dossier esiste gia, ma va definito come parte del processo diritti.
- Documenta:
  - cosa include l'export
  - cosa non include
  - formato

### 3.3 Completa rettifica e limitazione

- Decidi come gestire:
  - correzione dati clinici
  - recap AI gia generati
  - documenti errati / da oscurare

### 3.4 Scrivi la retention matrix

- Definisci tempi e regole per:
  - documenti clinici
  - recap AI
  - report
  - audit log
  - notifiche
  - share links
  - backup
  - dati locali sul device

### 3.5 Definisci la policy log

- Formalizza:
  - niente prompt raw in log
  - niente dati salute in chiaro nei log applicativi
  - retention log tecnica
  - access control ai log

### Gate Fase 3

- Non lanciare public beta se non hai:
  - account deletion flow
  - retention matrix
  - rights handling procedure

---

## Fase 4 - Security e production hardening

### 4.1 Chiudi i default di sviluppo

- Obbligatorio prima del go-live:
  - `debug = false`
  - `jwt_secret_key` robusta e gestita in secret manager
  - CORS limitati ai domini reali
  - review completa degli env di produzione

### 4.2 Riesamina il vault locale free

- Oggi i file free sono locali ma non risultano cifrati a livello app.
- Decidi se:
  - accetti la protezione del sandbox OS
  - oppure aggiungi cifratura applicativa

### 4.3 Rafforza i share links

- Consiglio:
  - riduci TTL massimo
  - aggiungi opzione PIN o seconda protezione
  - esplicita access logging e revoca

### 4.4 Runbook sicurezza

- Prepara:
  - incident response
  - data breach response
  - gestione revoca credenziali vendor
  - gestione compromissione token/link

### 4.5 Backup e restore

- Documenta:
  - dove stanno i backup
  - tempi di conservazione
  - cifratura
  - restore test

### Gate Fase 4

- Nessun go-live senza:
  - hardening env
  - security review
  - runbook incidenti

---

## Fase 5 - AI governance e product wording

### 5.1 Rivedi tutti i testi prodotto

- Controlla:
  - onboarding
  - privacy AI
  - insights
  - report
  - screening
  - prevenzione
  - query documenti

Obiettivo:

- evitare wording che faccia sembrare ClinDiary uno strumento diagnostico o prescrittivo

### 5.2 Crea una AI governance note interna

- Deve includere:
  - modelli usati
  - finalita
  - limiti
  - fallback
  - incidenti noti
  - responsabilita umana

### 5.3 Definisci AI literacy minima

- Chi pubblica o gestisce il prodotto deve sapere:
  - cosa puo fare il modello
  - cosa non puo fare
  - quando interviene il fallback
  - quando un output va trattato come errore o rischio

### 5.4 Valuta se bloccare alcune funzioni in public beta

- Se il rischio MDR o privacy resta troppo alto, valuta di tenere fuori temporaneamente:
  - query documenti
  - pre-visita
  - screening/prevenzione AI
  - family profiles con AI esterna

### Gate Fase 5

- Prima del lancio pubblico devi avere:
  - wording rivisto
  - AI governance note
  - owner responsabili

---

## Fase 6 - Go / No-Go finale

### Checklist finale di go-live

- MDR assessment concluso
- informativa privacy finale pubblicata
- informativa AI finale pubblicata
- base giuridica definita
- DPIA chiusa o formalmente gestita
- DPA Regolo raccolta e verificata
- retention matrix approvata
- rights workflow operativo
- hardening produzione completato
- incident response pronto
- share links rafforzati o limitati
- policy minori definita
- marketing wording allineato al perimetro legale

### Se anche un blocco resta aperto

- niente go-live pubblico
- al massimo:
  - beta chiusa
  - test interni
  - sandbox con utenze controllate

---

## Ordine pratico consigliato

### Settimana 1

1. assessment MDR
2. privacy notice finale
3. AI notice finale
4. base giuridica

### Settimana 2

1. DPIA
2. vendor pack Regolo
3. minimizzazione payload
4. policy minori

### Settimana 3

1. account deletion
2. retention matrix
3. rights workflow
4. share links hardening

### Settimana 4

1. hardening produzione
2. security runbook
3. AI governance note
4. final go/no-go review

---

## Riferimenti nel repo

- overview legale:
  - `docs/legal/eu-italy-compliance-overview.md`
- gap analysis:
  - `docs/legal/gdpr-italy-regolo-gap-analysis.md`
- documenti privacy gia esistenti:
  - `docs/architecture/pre-production-gdpr-ai.md`
  - `docs/architecture/privacy-ai-notice-draft.md`
- consenso AI / onboarding:
  - `apps/backend/app/services/profile_service.py`
  - `apps/backend/app/models/user_onboarding.py`
- provider AI:
  - `apps/backend/app/ai/summary_provider.py`
- dossier export / share:
  - `apps/backend/app/api/v1/dossier.py`
  - `apps/backend/app/services/dossier_service.py`
- vault locale documenti:
  - `apps/mobile/lib/features/documents/data/local_document_vault_service.dart`

## Fonti ufficiali / primarie

- GDPR:
  https://eur-lex.europa.eu/eli/reg/2016/679/oj
- MDR:
  https://eur-lex.europa.eu/eli/reg/2017/745/oj
- AI Act:
  https://eur-lex.europa.eu/eli/reg/2024/1689/oj
- EDPB, DPIA:
  https://www.edpb.europa.eu/sme-data-protection-guide/faq-frequently-asked-questions/answer/what-data-protection-impact_en
- EDPB, DPO:
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
