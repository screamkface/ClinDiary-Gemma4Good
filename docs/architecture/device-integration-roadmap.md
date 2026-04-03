# ClinDiary - Roadmap Integrazioni Device e App Salute

Ultimo aggiornamento: **1 aprile 2026**

## Stato implementazione corrente

Baseline `Wave 1` gia` implementata nel repo:

- nuovo modulo backend `devices` con modelli `device_connections`, `device_import_jobs`, `device_measurements`
- API `/api/v1/devices/*` per overview, link, disconnect, sync e ingest misure
- UI mobile `Dispositivi` con tab `Provider`, `Connessi`, `Misure`, `Import`
- catalogo provider reale per `OMRON`, `Withings`, `iHealth`, `A&D Medical`, `Dexcom`
- tracking import job e timeline event per le misure device

Limite attuale, intenzionale e veritiero:

- la sync live vendor-specific richiede ancora credenziali partner, token exchange o SDK/BLE esterni
- quindi la Wave 1 oggi copre gia` framework, persistenza, UI, bootstrap dei connettori e ingest manuale dove supportato, ma non finge una live sync senza onboarding vendor

## Obiettivo

Far diventare ClinDiary una piattaforma di salute generale capace di importare dati in modo affidabile da:

- hub di sistema (`Apple Health / HealthKit`, `Android Health Connect`)
- app companion dei vendor
- cloud API vendor
- SDK BLE diretti per device clinici selezionati

La strategia giusta non e` integrare "tutto" nello stesso modo, ma usare un modello a piu livelli:

1. **Hub di sistema come base universale**
2. **API cloud vendor per i dati clinici ad alto valore**
3. **SDK/BLE diretti** solo dove il dato real-time o la precisione del device contano davvero

## Principi di prodotto

- **Non dipendere solo dagli hub** per i dati clinici importanti: pressione, glicemia, SpO2 clinica, ECG, body composition, CGM
- **Normalizzare tutto** in un modello ClinDiary unico, indipendente dal vendor
- **Mantenere provenance forte**: ogni misura deve sapere da dove arriva (`device`, `vendor app`, `hub`, `manuale`)
- **Separare ingestion e UI**: il mobile non deve conoscere la logica specifica di ogni vendor
- **Usare OAuth cloud-to-cloud come default** quando il vendor lo supporta bene
- **Usare BLE diretto** solo per flussi che ne traggono beneficio reale

## Livelli di integrazione consigliati

### Livello 1 - Hub di sistema

Da mantenere sempre come base:

- **Apple Health / HealthKit**
- **Android Health Connect**

Vantaggi:

- copertura massima
- meno accordi vendor
- UX semplice lato utente

Limiti:

- export parziale o incoerente tra vendor
- alcune metriche non arrivano
- nessuna garanzia uniforme su tutte le app companion

Per ClinDiary il ruolo corretto degli hub e`:

- passi
- distanza
- sonno
- frequenza cardiaca
- calorie/attivita`
- SpO2 e altri parametri solo se davvero presenti

## Vendor matrix

Questa tabella copre i principali ecosistemi utili a ClinDiary. Non e` un catalogo "di tutto il mercato", ma una base ad alta confidenza su fonti ufficiali.

| Vendor / app | Tipo integrazione ufficiale | Dati utili | Modalita` migliore per ClinDiary | Priorita` |
| --- | --- | --- | --- | --- |
| **OMRON Connect** | SDK BLE + Data API + Partner API | pressione, FC, peso, temperatura, SpO2, glicemia su device supportati | **Diretta** | **P1** |
| **Withings** | Public API + webhook | pressione, peso, composizione corporea, sonno, attivita` | **Cloud API** | **P1** |
| **iHealth** | Open API OAuth2 + push | pressione, peso, glicemia, SpO2, temperatura, sonno, attivita` | **Cloud API** | **P1** |
| **A&D Medical** | API + SDK | pressione, peso, pulsossimetri, termometri, attivita` | **Diretta/Cloud** | **P1** |
| **Dexcom** | API partner OAuth2 | CGM, eventi diabete | **Cloud API** | **P1** |
| **Garmin** | Garmin Connect Health API + SDK | sonno, HR, stress, Pulse Ox, respirazione, BP, body composition | **Cloud API**, SDK solo se serve real-time | **P2** |
| **Polar** | AccessLink API + webhook | attivita`, sonno, HR continuo, temperatura, SpO2, ECG da polso | **Cloud API** | **P2** |
| **Fitbit** | Web API OAuth2 | attivita`, sonno, HR, intraday | **Cloud API** | **P2** |
| **WHOOP** | OAuth2 + webhook | sleep, recovery, strain, attivita` | **Cloud API** | **P2** |
| **Oura** | API ufficiale V2 | sleep, readiness, attivita`, HR/HRV | **Cloud API** | **P2** |
| **Samsung Health** | Data SDK / SDK, non semplice public REST | dati salute/wellness ricchi | **Hub/SDK**, non prima scelta | **P3** |
| **Abbott Libre / LibreView** | flussi partner meno aperti del mondo Dexcom | glicemia | **Da verificare con partner path** | **P3** |
| **Beurer HealthManager** | Developer Area / protocolli, meno aperta come public cloud API | pressione, ECG, glicemia, SpO2, peso | **Da valutare caso per caso** | **P3** |
| **Xiaomi Fitness** | nessuna public API semplice verificata; export via hub non affidabile | passi/attivita`, alcuni casi via Health Connect | **Health Connect only** | **P4** |

## Conclusioni per vendor

### Wave 1 - da implementare subito

1. **OMRON**
2. **Withings**
3. **iHealth**
4. **A&D Medical**
5. **Dexcom**

Questi 5 coprono gia` una fetta molto forte di salute generale:

- pressione arteriosa
- peso / BMI / body composition
- temperatura
- saturazione
- glicemia spot / CGM

Sono i piu coerenti con l'identita` di ClinDiary come app di salute generale, non solo fitness.

### Wave 2 - da aggiungere dopo

1. **Garmin**
2. **Polar**
3. **Fitbit**
4. **WHOOP**
5. **Oura**

Questa wave e` ottima per:

- sonno
- recovery
- metriche wellness
- HR continuo
- attivita` sportiva

### Wave 3 - da trattare con cautela

1. **Samsung Health SDK**
2. **Abbott Libre / LibreView**
3. **Beurer**
4. **Xiaomi Fitness**

Motivi:

- accesso meno lineare
- partner program o SDK piu complessi
- variabilita` regionale o commerciale
- rischio di investire tanto in integrazioni poco stabili

## Xiaomi: decisione consigliata

Per **Xiaomi Fitness** la scelta giusta oggi e`:

- **non fare una integrazione diretta come priorita`**
- usare **Health Connect** su Android come best-effort
- mostrare in UI con chiarezza quando Health Connect espone solo dati parziali

Inferenza importante:

- non ho trovato una public API Xiaomi semplice e affidabile comparabile a Withings / iHealth / Polar
- quindi per ClinDiary Xiaomi oggi va trattato come ecosistema da **hub integration**, non da connector premium

## Modello dati unificato consigliato

ClinDiary deve normalizzare tutto in categorie stabili, non vendor-specific.

### Tipi principali

- `blood_pressure`
- `heart_rate`
- `resting_heart_rate`
- `spo2`
- `temperature`
- `body_weight`
- `body_composition`
- `blood_glucose_bgm`
- `blood_glucose_cgm`
- `steps`
- `distance`
- `sleep_summary`
- `activity_summary`
- `ecg_summary`
- `respiration`

### Provenance obbligatoria per ogni misura

- `source_kind`: `manual`, `health_connect`, `healthkit`, `vendor_cloud`, `vendor_ble`
- `source_vendor`: `omron`, `withings`, `dexcom`, `garmin`, `xiaomi`, ecc.
- `source_device_model`
- `source_app`
- `measured_at`
- `imported_at`
- `external_record_id`
- `patient_id`

## Architettura consigliata nel backend ClinDiary

Il backend attuale puo` restare monolite modulare. Le integrazioni entrano come nuovo modulo dedicato.

### Nuovi moduli consigliati

- `apps/backend/app/models/device_connection.py`
- `apps/backend/app/models/device_measurement.py`
- `apps/backend/app/models/device_import_job.py`
- `apps/backend/app/models/device_webhook_event.py`
- `apps/backend/app/services/device_connector_service.py`
- `apps/backend/app/services/device_import_service.py`
- `apps/backend/app/services/device_normalization_service.py`
- `apps/backend/app/services/vendors/omron_service.py`
- `apps/backend/app/services/vendors/withings_service.py`
- `apps/backend/app/services/vendors/ihealth_service.py`
- `apps/backend/app/services/vendors/ad_service.py`
- `apps/backend/app/services/vendors/dexcom_service.py`
- `apps/backend/app/api/v1/devices.py`
- `apps/backend/app/workers/device_tasks.py`

### Pattern di integrazione

#### 1. Cloud OAuth connector

Per:

- Withings
- iHealth
- Dexcom
- Polar
- Fitbit
- WHOOP
- Oura
- Garmin Connect

Flusso:

1. utente collega account vendor
2. backend salva token cifrati
3. polling o webhook
4. normalizzazione
5. persistenza ClinDiary
6. proiezione in timeline / dossier / AI context

#### 2. Device SDK / BLE connector

Per:

- OMRON
- A&D
- eventuali Garmin SDK real-time

Flusso:

1. mobile associa il device
2. legge misura raw o summary
3. backend riceve payload firmato/autenticato
4. normalizzazione
5. persistenza ClinDiary

## UI consigliata

Nuova area dedicata: **Dispositivi e account salute**

### Sezioni

- `Hub di sistema`
  - Apple Health
  - Health Connect
- `Dispositivi clinici`
  - OMRON
  - iHealth
  - A&D
  - Withings
- `Wearable e wellness`
  - Garmin
  - Polar
  - Fitbit
  - Oura
  - WHOOP
- `Diabete`
  - Dexcom
  - Abbott se/quanto disponibile

Per ogni sorgente:

- stato connessione
- ultime metriche lette
- permessi/token
- note di copertura
- avvisi su dati parziali

## Priorita` implementativa concreta

### Sprint 1

- baseline architetturale `devices`
- modello connessioni vendor
- ingestion framework comune
- UI `Dispositivi`
- adapter hub attuali portati sotto lo stesso modulo

### Sprint 2

- **OMRON**
- **Withings**
- **iHealth**

### Sprint 3

- **A&D**
- **Dexcom**

### Sprint 4

- **Garmin**
- **Polar**

### Sprint 5

- **Fitbit**
- **WHOOP**
- **Oura**

### Sprint 6

- Samsung / Abbott / Beurer / Xiaomi review

## Impatto sui recap AI

I dati dei device non vanno passati al modello come stream grezzo.

Per i recap AI la forma corretta e`:

- aggregati giornalieri
- finestre settimanali/mensili
- eventi fuori range
- trend
- provenance sintetica

Esempio:

- pressione media 7 giorni
- numero misure pressorie
- glicemia media + range + episodi alti/bassi
- peso e trend
- sonno medio
- FC media / FC a riposo

## Impatto legale / regolatorio

Ogni integrazione va valutata anche su:

- termini API del vendor
- DPA / ruoli privacy
- minimizzazione dei dati
- retention
- possibile impatto MDR se i dati clinici vengono rielaborati in modo troppo decisionale

Questo vale soprattutto per:

- pressione
- ECG
- SpO2
- glicemia / CGM

## Raccomandazione finale

La strategia migliore per ClinDiary e`:

1. **base universalista** con HealthKit / Health Connect
2. **connettori premium clinici** per OMRON, Withings, iHealth, A&D, Dexcom
3. **wellness cloud connectors** per Garmin, Polar, Fitbit, WHOOP, Oura
4. **Xiaomi trattato come best-effort via hub**, non come integrazione primaria

## Fonti ufficiali principali

- OMRON Connect Create: https://www.digitalhealth.omronconnect.com/omron-connect-create
- OMRON docs: https://omron-connect-create.readme.io/docs/getting-started
- Withings Public API: https://developer.withings.com/developer-guide/v3/withings-solutions/app-to-app-solution/
- iHealth developer: https://developer.ihealthlabs.com/
- iHealth OpenAPI V2: https://developer.ihealthlabs.com/dev_documentation_openapidoc.htm
- A&D API license: https://medical.andonline.com/API-license-agreement/
- A&D SDK overview: https://www.aandd.jp/products/medical/sdk.html
- Dexcom developer docs: https://developer.dexcom.com/docs/
- Garmin Connect overview: https://developer.garmin.com/gc-developer-program/overview/
- Garmin Health API: https://developer.garmin.com/gc-developer-program/health-api/
- Garmin Health SDK: https://developer.garmin.com/health-sdk/overview/
- Polar AccessLink API: https://www.polar.com/accesslink-api/
- Fitbit API overview: https://dev.fitbit.com/apps.
- WHOOP developer platform: https://developer.whoop.com/
- WHOOP getting started: https://developer.whoop.com/docs/developing/getting-started/
- Oura API help: https://support.ouraring.com/hc/en-us/articles/4415266939155-The-Oura-API
- Apple Health & Fitness: https://developer.apple.com/health-fitness/
- Android Health Connect: https://developer.android.com/health-and-fitness/health-connect
- Xiaomi Health Cloud Android SDK: https://dev.mi.com/docs/micloud/health/android_sdk/
