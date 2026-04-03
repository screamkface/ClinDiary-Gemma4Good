# ClinDiary - Conformita UE/Italia: stato sintetico

Data: **31 marzo 2026**

> Nota importante: questo documento non e un parere legale. E una sintesi tecnica-operativa basata sul comportamento reale del repo.

## Verdettto sintetico

No: **ClinDiary oggi non e ancora "compliance-ready" per una produzione pubblica in UE/Italia**.

La base e buona, ma i gap rilevanti non sono solo GDPR. C'e anche un **rischio MDR / medical device software** in base a come l'app viene presentata e venduta.

## Cosa e gia messo bene

- Esiste un consenso separato per l'uso di AI esterna, con enforcement backend:
  - `apps/backend/app/services/profile_service.py`
  - `apps/backend/app/models/user_onboarding.py`
- Se l'utente non attiva AI esterna, esiste fallback `rule_based`.
- Non risultano log sistematici dei prompt clinici in chiaro; oggi vengono loggati soprattutto provider, modello ed errori.
- I link di visualizzazione file hanno TTL limitato:
  - `apps/backend/app/core/config.py`
- La documentazione interna gia riconosce correttamente che mancano ancora informativa AI finale, base giuridica definita, DPIA, retention e workflow diritti:
  - `docs/architecture/pre-production-gdpr-ai.md`
  - `docs/architecture/privacy-ai-notice-draft.md`

## Cosa oggi non e conforme, o non e dimostrabile come conforme

### 1. Informativa privacy / AI non completa

- Manca una informativa finale completa ex artt. 12-14 GDPR.
- Nel repo esiste una bozza, ma non un testo definitivo pronto per produzione.

### 2. Base giuridica non chiusa

- Per dati salute non basta "abbiamo il consenso nel prodotto".
- Devi definire e documentare chiaramente:
  - base ex art. 6 GDPR
  - condizione ex art. 9 GDPR
- Nei documenti interni questa parte e ancora marcata come "da definire".

### 3. DPIA molto probabilmente necessaria

- ClinDiary tratta dati sanitari, wearable, profili familiari e usa AI.
- Questo rende molto probabile la necessita di una DPIA prima della produzione.

### 4. Workflow diritti GDPR incompleto

- Esiste export del dossier, ma non emerge un flusso completo e documentato per:
  - cancellazione account
  - cancellazione dati
  - portabilita completa
  - rettifica / limitazione / opposizione

### 5. Retention policy non definita

- Non c'e ancora una policy finale su tempi di conservazione per:
  - documenti
  - recap AI
  - audit log
  - share links
  - backup

### 6. Security di default non pronta per la produzione

- Nel codice restano default di sviluppo non compatibili con un go-live serio:
  - `debug=True`
  - `jwt_secret_key="change-me-in-production"`
  - CORS larghi per ambienti locali
- Questo non significa che la produzione debba restare cosi, ma oggi il repo non e "compliance-ready" out of the box.

### 7. Minimizzazione del payload verso l'AI ancora debole

- Il payload inviato al modello e ricco: profilo, farmaci, wearable, documenti, recap precedenti, alert.
- Va dimostrato che ogni categoria sia strettamente necessaria per la specifica finalita.

### 8. Rischio MDR / software come dispositivo medico

- ClinDiary produce recap clinici prudenti, pre-visita, segnali di attenzione, screening e prevenzione personalizzata.
- Se viene presentata come software che fornisce informazioni per prevenzione, monitoraggio o supporto clinico, puo entrare nel perimetro del Regolamento UE 2017/745.
- Se succede, oggi il progetto **non e conforme MDR**: mancano classificazione, QMS, documentazione tecnica, clinical evaluation, PMS e percorso CE.

### 9. AI Act da gestire

- Anche senza arrivare subito a una classificazione "high-risk", servono governance, trasparenza, controllo umano e documentazione interna seria.
- Se ClinDiary finisse anche nel perimetro MDR, il profilo AI diventerebbe ancora piu delicato.

## Regolo aiuta?

Sì, **molto**, ma non basta da solo.

Dal materiale pubblico Regolo dichiara:

- elaborazione in Europa
- zero retention
- orientamento GDPR e AI Act
- DPA disponibile

Questo riduce il rischio rispetto a provider extra-UE, ma ClinDiary resta comunque titolare del trattamento della propria app e deve ancora chiudere:

- DPA / contrattualistica
- sub-processors
- base giuridica
- informativa
- DPIA
- retention
- assessment MDR

## Conclusione pratica

Se la domanda e "possiamo dire che l'app e conforme oggi?":

**No, non ancora.**

La strada prudente e:

1. chiudere privacy notice + AI notice
2. definire base giuridica art. 6 + art. 9
3. fare DPIA
4. definire retention + diritti interessato
5. mettere in sicurezza la produzione
6. fare assessment MDR immediato
7. usare Regolo come provider preferito, ma con DPA e vendor due diligence formalizzati

## Fonti ufficiali / primarie

- GDPR:
  https://eur-lex.europa.eu/eli/reg/2016/679/oj
- AI Act:
  https://eur-lex.europa.eu/eli/reg/2024/1689/oj
- MDR:
  https://eur-lex.europa.eu/eli/reg/2017/745/oj
- EDPB, DPIA:
  https://www.edpb.europa.eu/sme-data-protection-guide/faq-frequently-asked-questions/answer/what-data-protection-impact_en
- EDPB, DPO:
  https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/data-protection-officer_nb
- Garante Privacy, app:
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
