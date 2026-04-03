# ClinDiary - Roadmap Prevenzione

Data: **1 aprile 2026**

## Aggiornamento stato

- Wave 1 ora implementata nel prodotto:
  - revisione uso del tabacco
  - supporto per smettere di fumare se fumo attivo
  - revisione consumo di alcol
  - counselling se consumo di alcol elevato
  - supporto comportamentale per obesita
  - counselling su alimentazione e movimento nei profili cardiometabolici a rischio
  - mini-catalogo vaccinale piu ricco con uso reale dello storico vaccinale gia registrato
- Wave 2 ora implementata in baseline:
  - osteoporosi / salute ossea con criteri per eta, menopausa e rischio osseo
  - screening polmone se storia tabagica rilevante
  - ecografia aorta addominale nei profili maschili 65-75 con storia di fumo
  - rischio cadute negli over 65 con cadute recenti o instabilita
  - screening MST personalizzato con fattori di rischio strutturati nel profilo
- Wave 3 ora implementata nella baseline:
  - percorso preconcezionale e gravidanza guidato da campi profilo espliciti
  - registro vaccinale piu strutturato nel Centro prevenzione
  - aree specialistiche mantenute in `shared_decision`, non in automatismo forte:
    - PSA/prostata
    - cute/melanoma
    - vista in eta avanzata
  - voci `not_routine` aggiuntive per evitare automatismi su:
    - vitamina D nella popolazione generale
    - tiroide nella popolazione generale
    - pannelli ematici annuali completi senza indicazione
- Le wave successive restano valide come raffinamento, ma la baseline 1-3 e ora attiva nel prodotto.

## Obiettivo

Mappare in modo pragmatico il perimetro prevenzione di ClinDiary in tre blocchi:

1. `Da fare subito`
2. `Da fare dopo`
3. `Da non automatizzare troppo`

Questa roadmap serve a guidare engineering e product.  
Non sostituisce una validazione clinica o regolatoria finale.

## Stato attuale

Oggi ClinDiary copre gia in modo deterministico:

- visita preventiva annuale
- pressione arteriosa
- peso / altezza / BMI
- salute mentale
- revisione uso del tabacco
- supporto per smettere di fumare se fumo attivo
- revisione consumo di alcol
- counselling se consumo di alcol elevato
- supporto comportamentale per obesita
- counselling su alimentazione e movimento nei profili con rischio cardiometabolico
- HIV almeno una volta
- epatite C almeno una volta
- lipidi se rischio
- glicemia / HbA1c se rischio
- revisione vaccini e mini-catalogo vaccinale piu ricco guidato anche dallo storico inserito
- osteoporosi / salute ossea
- screening polmone risk-based
- aneurisma aorta addominale risk-based
- rischio cadute negli anziani con segnali dichiarati
- screening MST personalizzato su fattori di rischio strutturati
- preconcezione e gravidanza su profili femminili che lo dichiarano
- registro vaccinale piu leggibile nel Centro prevenzione
- aree di `shared_decision` per prostata, cute e vista
- screening pubblici italiani:
  - cervice uterina
  - mammografia
  - colon-retto
- voci `not_routine` gia protette:
  - screening routinario del testicolo negli asintomatici
  - ecografie generiche negli asintomatici

Touchpoints principali:

- `apps/backend/app/rules/screenings.py`
- `apps/backend/app/services/screening_service.py`
- `apps/backend/app/services/prevention_center_service.py`

## 1. Da fare subito

Queste sono le aree con miglior rapporto valore/complessita, perche sono:

- coerenti con il perimetro attuale
- spiegabili
- implementabili in modo deterministico
- supportate bene dai dati gia raccolti o con aggiunte minime

### 1.1. Screening e counseling per tabacco

Perche: il profilo ha gia `smoker`.

Cosa aggiungere:

- raccomandazione esplicita di cessazione del fumo
- reminder periodico di revisione abitudine tabagica
- materiale o CTA `da discutere col medico / centro antifumo`

Motore:

- deterministic rule su `profile.smoker == true`

Categoria ClinDiary:

- `discuss_with_doctor`

Fonte:

- USPSTF tobacco cessation in adults  
  https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/tobacco-use-in-adults-and-pregnant-women-counseling-and-interventions

### 1.2. Screening e counseling per alcol a rischio

Perche: il profilo ha gia `alcohol_use`.

Cosa aggiungere:

- identificazione prudente di consumo da rivedere
- consiglio organizzativo di confronto medico se pattern a rischio
- nessuna etichetta diagnostica

Motore:

- deterministic rule su `alcohol_use in {moderate, high}`

Categoria ClinDiary:

- `discuss_with_doctor`

Fonte:

- USPSTF unhealthy alcohol use screening and counseling  
  https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/unhealthy-alcohol-use-in-adolescents-and-adults-screening-and-behavioral-counseling-interventions

### 1.3. Interventi comportamentali per obesita

Perche: BMI e gia calcolabile.

Cosa aggiungere:

- se `BMI >= 30`, suggerire percorso comportamentale strutturato
- mantenere la formulazione come invito a discutere un percorso, non come prescrizione

Motore:

- deterministic rule su BMI

Categoria ClinDiary:

- `discuss_with_doctor`

Fonte:

- USPSTF obesity / weight loss behavioral interventions  
  https://www.uspreventiveservicestaskforce.org/uspstf/index.php/recommendation/obesity-in-adults-interventions

### 1.4. Counseling su dieta e attivita fisica nei profili a rischio cardiovascolare

Perche: gia abbiamo parte del profilo utile:

- BMI
- fumo
- attivita fisica
- alcune condizioni/familiarita

Cosa aggiungere:

- percorso preventivo lifestyle per profili cardiometabolici a rischio
- raccomandazione chiara ma non prescrittiva

Motore:

- combinazione deterministica di:
  - BMI elevato
  - fumo
  - dislipidemia/diabete/ipertensione se presenti in patologie note

Categoria ClinDiary:

- `discuss_with_doctor`

Fonte:

- USPSTF counseling su dieta e attivita fisica in adulti con fattori di rischio cardiovascolare  
  https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/healthy-diet-and-physical-activity-counseling-adults-with-high-risk-of-cvd

### 1.5. Allargare il linguaggio vaccinale da “review” a mini-catalogo deterministico

Perche: la logica vaccinale c e gia, ma e ancora orientata soprattutto a review.

Cosa aggiungere:

- stato piu strutturato per:
  - influenza
  - COVID
  - Td/Tdap
  - HPV
  - herpes zoster
  - pneumococco
  - epatite B
  - RSV quando pertinente

Motore:

- eta
- sesso/contesto biologico
- condizioni croniche gia note

Categoria ClinDiary:

- `routine` o `discuss_with_doctor` a seconda del vaccino

Fonti:

- CDC adult immunization schedule  
  https://www.cdc.gov/vaccines/hcp/imz-schedules/adult-age-compliant.html
- CDC adult notes  
  https://www.cdc.gov/vaccines/hcp/imz-schedules/adult-notes.html

## 2. Da fare dopo

Queste aree sono importanti, ma richiedono piu dati o una modellazione piu ricca.

### 2.1. Osteoporosi / fragilita ossea

Motivo per rimandarla:

- richiede almeno una parte di contesto oggi non modellato bene:
  - stato menopausale
  - precedenti fratture da fragilita
  - terapie che riducono densita ossea
  - fattori di rischio piu specifici

Fonte:

- USPSTF osteoporosis screening  
  https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/osteoporosis-screening

### 2.2. Screening polmone risk-based

Motivo per rimandarlo:

- serve una storia tabagica migliore, non basta il booleano `smoker`
- idealmente servono:
  - pack-years
  - ex-smoker / current smoker
  - anni dalla cessazione

Fonte:

- USPSTF lung cancer screening  
  https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/lung-cancer-screening

### 2.3. Aneurisma aorta addominale

Motivo per rimandarlo:

- richiede rischio piu preciso:
  - sesso biologico
  - eta
  - fumo attuale/pregresso
  - familiarita specifica per aneurisma

Fonte:

- USPSTF abdominal aortic aneurysm screening  
  https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/abdominal-aortic-aneurysm-screening

### 2.4. Rischio cadute negli anziani

Motivo per rimandarlo:

- richiede nuovi campi o workflow:
  - cadute precedenti
  - instabilita
  - ausili
  - sedativi
  - performance funzionale

Fonte:

- USPSTF falls prevention in community-dwelling older adults  
  https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/falls-prevention-community-dwelling-older-adults-interventions

### 2.5. MST davvero personalizzate

Motivo per rimandarlo:

- oggi ClinDiary ha una voce corretta `risk_based`, ma non ha un modello abbastanza ricco per:
  - nuovi partner
  - partner multipli
  - MSM
  - gravidanza
  - partner con STI
  - PrEP

Fonte:

- CDC STI screening recommendations  
  https://www.cdc.gov/std/treatment-guidelines/screening-recommendations.htm

### 2.6. Percorso preconcezionale / gravidanza

Motivo per rimandarlo:

- richiede dati molto sensibili e uno scope clinico piu delicato
- va modellato bene prima di automatizzare suggerimenti

### 2.7. Registro vaccinale vero

Motivo per rimandarlo:

- il Centro prevenzione gia suggerisce vaccini da verificare
- il salto successivo corretto e uno storico strutturato, non piu solo `review`

## 3. Da non automatizzare troppo

Qui ClinDiary deve restare prudente.  
Possiamo mostrare informazione o shared decision making, ma non trasformarli in “promemoria automatici forti”.

### 3.1. PSA / screening prostata

Da trattare come:

- `shared decision`
- non come reminder standard per tutti

Fonte:

- USPSTF prostate cancer screening clinical summary  
  https://www.uspreventiveservicestaskforce.org/uspstf/document/clinical-summary/prostate-cancer-screening

### 3.2. Ecografie generiche e imaging opportunistico

Da trattare come:

- `not_routine`

Stato ClinDiary:

- gia protetto correttamente per gli asintomatici

### 3.3. Testicolo screening routinario negli asintomatici

Da trattare come:

- `not_routine`

Stato ClinDiary:

- gia protetto correttamente

### 3.4. Screening cute / melanoma nella popolazione generale asintomatica

Da trattare come:

- niente reminder automatico forte di massa
- solo educazione prudente o discussione se rischio specifico

Fonte:

- USPSTF skin cancer screening  
  https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/skin-cancer-screening

### 3.5. Vitamina D, tiroide, pannelli ematici “annuali per tutti”

Da trattare come:

- non routine automatica per popolazione generale asintomatica

Fonti:

- USPSTF vitamin D deficiency screening  
  https://www.uspreventiveservicestaskforce.org/uspstf/document/RecommendationStatementFinal/vitamin-d-deficiency-screening
- USPSTF thyroid dysfunction screening  
  https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/thyroid-dysfunction-screening

### 3.6. Screening visivo routinario automatico nell anziano asintomatico

Da trattare come:

- prudenza
- non come automatismo forte senza ulteriori dati

Fonte:

- USPSTF impaired visual acuity in older adults  
  https://www.uspreventiveservicestaskforce.org/uspstf/recommendation/impaired-visual-acuity-screening-older-adults

## Ordine di implementazione consigliato

### Wave 1

- tabacco
- alcol
- obesita / counseling peso
- lifestyle cardiometabolico
- vaccini piu strutturati

### Wave 2

- osteoporosi
- polmone
- AAA
- cadute
- MST con profilo di rischio vero

### Wave 3

- gravidanza / preconcezionale
- registro vaccinale completo
- aree specialistiche avanzate e shared-decision delicate

## Impatto sul modello dati

Per arrivare alla baseline completa Wave 1-3 sono serviti nuovi campi o moduli minimi:

- smoking pack-years
- ex-smoker / current smoker
- anni dalla cessazione
- stato menopausale
- fratture pregresse
- cadute pregresse
- rischio sessuale strutturato
- registro vaccinale personale piu ricco
- trying to conceive
- currently pregnant
- taking folic acid

## Conclusione

ClinDiary oggi ha una base prevenzione buona, ampia e prudente, ma non esaustiva.  
La direzione corretta non e “aggiungere tutto subito”, ma:

- allargare prima le aree ad alta utilita e alta spiegabilita
- aggiungere nuovi campi profilo solo dove servono davvero
- lasciare alcune aree in `shared decision` o `not_routine`

In altre parole:

- **non siamo incompleti a caso**
- **siamo volutamente conservativi**
- **la baseline Wave 1-3 e ora presente**
- **i prossimi passi devono essere raffinamenti, non automatismi aggressivi**
