# ClinDiary — Blueprint tecnico per LLM sviluppatore

## Ruolo dell’agente

Agisci come **senior full-stack engineer + mobile architect + AI product engineer** incaricato di progettare e sviluppare **ClinDiary**, una mobile app clinica intelligente per monitoraggio quotidiano, timeline clinica, archiviazione documenti sanitari, sintesi AI, screening preventivi e supporto al follow-up medico.

Devi produrre codice e architettura **production-oriented**, modulare, sicura, estendibile e pronta per evolvere da MVP a piattaforma clinica più ampia.

Non devi trattare l’app come wellness generica.  
Devi trattarla come **health data platform con supporto clinico prudente**, evitando claim diagnostici assoluti.

----------

# 1. Obiettivo del prodotto

ClinDiary è una app che permette a un paziente di:

-   registrare ogni giorno sintomi, sonno, umore, parametri e note
    
-   caricare referti, esami del sangue, radiografie, lettere cliniche e altri documenti
    
-   costruire una **timeline clinica continua**
    
-   ricevere **riassunti intelligenti e pattern rilevanti**
    
-   ricevere **promemoria screening, prevenzione e farmaci**
    
-   esportare report chiari per il medico
    
-   migliorare il follow-up tra una visita e l’altra
    

Il sistema **non sostituisce il medico** e **non deve generare diagnosi definitive**.  
Può fornire:

-   sintesi
    
-   triage prudente
    
-   suggerimenti di approfondimento
    
-   alert su red flags
    
-   supporto decisionale leggero
    

----------

# 2. Principi di prodotto da rispettare

Durante lo sviluppo devi sempre rispettare questi principi:

## 2.1 Sicurezza clinica

-   Nessuna diagnosi definitiva automatica
    
-   Nessun claim assoluto tipo “hai X”
    
-   Output AI sempre prudente e spiegabile
    
-   Red flags gestite con motore regole deterministico
    

## 2.2 UX semplice

-   Il check-in giornaliero deve durare meno di 60 secondi
    
-   UI pulita, chiara, mobile-first
    
-   Le azioni principali devono essere rapide
    

## 2.3 Timeline come centro del prodotto

Tutti i dati devono convergere in una **timeline clinica unica**:

-   check-in giornalieri
    
-   sintomi
    
-   parametri
    
-   documenti
    
-   farmaci
    
-   screening
    
-   alert
    
-   report
    
-   eventi clinici
    

## 2.4 Struttura modulare

L’app deve essere costruita in moduli indipendenti:

-   auth
    
-   profilo clinico
    
-   diario giornaliero
    
-   documenti
    
-   insights AI
    
-   screening/prevenzione
    
-   farmaci/aderenza
    
-   report
    

## 2.5 Estendibilità

Progetta ClinDiary come base per:

-   moduli specialistici futuri
    
-   dashboard per studi medici
    
-   accesso caregiver
    
-   integrazione wearable
    
-   piano B2B/B2B2C
    

----------

# 3. Stack tecnologico obbligatorio

Usa il seguente stack.

## Mobile app

-   **Flutter**
    
-   Dart
    
-   architettura feature-first
    
-   state management: Riverpod
    
-   navigation: GoRouter
    
-   local persistence: Hive o Drift
    
-   form validation robusta
    
-   design system interno riusabile
    

## Backend

-   **FastAPI**
    
-   Python 3.12+
    
-   Pydantic
    
-   SQLAlchemy o SQLModel
    
-   Alembic per migration
    
-   architettura service-oriented modulare
    

## Database

-   **PostgreSQL**
    

## File storage

-   storage S3-compatible
    

## Background jobs

-   Redis
    
-   Celery o RQ
    

## AI layer

-   separato dal core backend
    
-   modulo dedicato per:
    
    -   sintesi
        
    -   classificazione documenti
        
    -   parsing referti
        
    -   spiegazioni utente-friendly
        

## Search / semantic retrieval

-   pgvector opzionale ma consigliato
    

## Infra

-   Docker
    
-   docker-compose per ambiente locale
    
-   CI/CD ready
    
-   logging strutturato
    
-   monitoring hooks
    

----------

# 4. Output richiesto all’LLM

Devi sviluppare il progetto in modo incrementale e ordinato.

Per ogni fase devi produrre:

-   codice completo
    
-   struttura file
    
-   commenti minimi ma utili
    
-   README tecnici
    
-   tipi forti
    
-   error handling
    
-   test essenziali
    
-   API chiare
    
-   naming consistente
    

Non generare codice monolitico disordinato.  
Non generare placeholder inutili.  
Ogni modulo deve essere realmente integrabile con gli altri.

----------

# 5. Moduli funzionali da implementare

## 5.1 Autenticazione e account

Funzionalità:

-   registrazione
    
-   login
    
-   refresh token
    
-   logout
    
-   reset password
    
-   consenso dati sanitari
    
-   onboarding iniziale
    

Campi base:

-   email
    
-   password hash
    
-   created_at
    
-   last_login
    
-   role
    

Ruoli iniziali:

-   patient
    
-   admin
    

Ruoli futuri:

-   doctor
    
-   caregiver
    

----------

## 5.2 Profilo clinico

Funzionalità:

-   dati anagrafici
    
-   anamnesi
    
-   allergie
    
-   patologie note
    
-   familiarità
    
-   farmaci cronici
    
-   abitudini di vita
    

Campi esempio:

-   nome
    
-   cognome
    
-   data nascita
    
-   sesso biologico
    
-   altezza
    
-   peso
    
-   fumatore
    
-   alcol
    
-   attività fisica
    

Sotto-moduli:

-   allergies
    
-   medical_conditions
    
-   medications
    
-   family_history
    

----------

## 5.3 Diario giornaliero

Funzionalità:

-   check-in giornaliero rapido
    
-   inserimento sintomi
    
-   inserimento parametri
    
-   note libere
    
-   storico giornaliero
    

Campi check-in:

-   sleep_hours
    
-   sleep_quality
    
-   energy_level
    
-   mood_level
    
-   stress_level
    
-   appetite_level
    
-   hydration_level
    
-   general_pain
    
-   general_notes
    

Sintomi:

-   code
    
-   severity
    
-   duration
    
-   body_location
    
-   metadata_json
    

Parametri:

-   temperature
    
-   blood_pressure
    
-   heart_rate
    
-   oxygen_saturation
    
-   glucose
    
-   weight
    

Supporta questionari adattivi:

-   se sintomo = mal di testa, chiedi campi extra
    
-   se febbre, chiedi durata e temperatura
    
-   se nausea, chiedi vomito/sintomi associati
    

----------

## 5.4 Archivio documenti clinici

Funzionalità:

-   upload PDF e immagini
    
-   metadata documento
    
-   OCR / text extraction
    
-   classificazione documento
    
-   parsing automatico se possibile
    
-   collegamento alla timeline
    

Tipi documento:

-   lab_report
    
-   imaging_report
    
-   discharge_letter
    
-   specialist_visit
    
-   prescription
    
-   medical_certificate
    
-   generic_document
    

Ogni documento deve salvare:

-   titolo
    
-   tipo
    
-   data upload
    
-   data esame
    
-   source
    
-   file_url
    
-   ocr_text
    
-   parsed_status
    

----------

## 5.5 Parsing referti e dati strutturati

Implementa un modulo per:

-   classificare il documento
    
-   estrarre testo
    
-   riconoscere referti di laboratorio
    
-   estrarre risultati strutturati
    
-   evidenziare valori fuori range
    

Entità:

-   lab_panels
    
-   lab_results
    
-   imaging_reports
    

Esempi lab_results:

-   analyte_name
    
-   value
    
-   unit
    
-   ref_min
    
-   ref_max
    
-   abnormal_flag
    

Non assumere accuratezza perfetta del parsing.  
Prevedi:

-   confidence score
    
-   revisione manuale futura
    
-   stato parsed / reviewed
    

----------

## 5.6 Timeline clinica

La timeline è una vista aggregata.

Eventi supportati:

-   daily_entry
    
-   symptom_event
    
-   vital_event
    
-   document_uploaded
    
-   lab_result_summary
    
-   imaging_summary
    
-   medication_started
    
-   medication_stopped
    
-   screening_due
    
-   screening_done
    
-   ai_alert
    
-   report_generated
    

Ogni evento deve avere:

-   event_type
    
-   source_type
    
-   source_id
    
-   title
    
-   description
    
-   event_date
    
-   severity opzionale
    

----------

## 5.7 AI insights

L’AI deve essere usata in modo prudente.

Funzioni:

-   riassunto giornaliero
    
-   riassunto settimanale
    
-   riassunto pre-visita
    
-   spiegazione semplificata di referti
    
-   pattern detection descrittivo
    
-   correlazioni leggere
    

Output ammessi:

-   “si osserva”
    
-   “potrebbe essere utile approfondire”
    
-   “trend compatibile con”
    
-   “monitorare”
    
-   “parlare con il medico”
    

Output vietati:

-   diagnosi certe
    
-   urgenze non giustificate
    
-   prescrizioni
    
-   linguaggio allarmistico
    

----------

## 5.8 Triage e red flags

Implementa un **rule engine separato** dall’AI generativa.

Deve gestire:

-   dolore toracico
    
-   dispnea
    
-   saturazione bassa
    
-   febbre alta persistente
    
-   sintomi neurologici improvvisi
    
-   sanguinamenti importanti
    
-   peggioramento rapido
    

Output:

-   info
    
-   attenzione
    
-   contatta medico
    
-   urgenza
    

Ogni alert deve essere:

-   tracciato
    
-   spiegabile
    
-   basato su regole chiare
    

----------

## 5.9 Screening e prevenzione

Implementa un modulo dedicato.

Funzionalità:

-   catalogo screening
    
-   screening consigliati in base al profilo
    
-   stato screening utente
    
-   reminder
    
-   screening gratuiti disponibili
    
-   spiegazioni chiare
    

Tabelle:

-   screening_programs
    
-   screening_rules
    
-   patient_screening_status
    
-   screening_notifications
    
-   regional_screening_availability
    

Stati screening:

-   never_done
    
-   recommended
    
-   scheduled
    
-   completed
    
-   overdue
    
-   skipped
    

La logica di eleggibilità deve essere deterministica, non affidata al solo LLM.

----------

## 5.10 Farmaci e aderenza

Funzionalità:

-   terapia attiva
    
-   promemoria farmaci
    
-   conferma assunzione
    
-   storico aderenza
    
-   note effetti collaterali
    

Entità:

-   medications
    
-   medication_schedules
    
-   medication_logs
    

----------

## 5.11 Report ed export

Implementa generazione report per visita.

Tipi report:

-   weekly_summary
    
-   monthly_summary
    
-   pre_visit_report
    
-   screening_status_report
    

Contenuti:

-   sintomi recenti
    
-   trend principali
    
-   farmaci
    
-   documenti recenti
    
-   screening
    
-   alert rilevanti
    
-   riassunto AI
    

Formato:

-   PDF server-side
    
-   scaricabile da app
    

----------

# 6. Architettura software richiesta

## 6.1 Struttura Flutter

Usa architettura feature-first.

Struttura esempio:

```text
lib/
  app/
    app.dart
    router.dart
    theme/
    core/
      constants/
      errors/
      network/
      storage/
      widgets/
      utils/
  features/
    auth/
    onboarding/
    profile/
    daily_journal/
    symptoms/
    vitals/
    documents/
    timeline/
    insights/
    alerts/
    screenings/
    medications/
    reports/
  shared/

```

Ogni feature deve contenere:

-   data
    
-   domain
    
-   presentation
    

Pattern consigliato:

-   repository
    
-   models
    
-   DTO
    
-   providers
    
-   screens
    
-   widgets
    
-   services
    

----------

## 6.2 Struttura backend

Usa struttura modulare pulita.

```text
app/
  main.py
  core/
    config.py
    security.py
    database.py
    logging.py
    exceptions.py
  api/
    v1/
      auth.py
      profile.py
      daily_entries.py
      symptoms.py
      vitals.py
      documents.py
      timeline.py
      insights.py
      alerts.py
      screenings.py
      medications.py
      reports.py
  models/
  schemas/
  services/
  repositories/
  workers/
  ai/
  rules/
  tests/

```

----------

# 7. Schema dati minimo richiesto

Implementa almeno queste entità.

## users

-   id
    
-   email
    
-   password_hash
    
-   role
    
-   created_at
    
-   updated_at
    

## patient_profiles

-   id
    
-   user_id
    
-   first_name
    
-   last_name
    
-   birth_date
    
-   biological_sex
    
-   height_cm
    
-   weight_kg
    
-   smoker
    
-   alcohol_use
    
-   activity_level
    

## allergies

-   id
    
-   patient_id
    
-   allergen
    
-   severity
    
-   notes
    

## medical_conditions

-   id
    
-   patient_id
    
-   name
    
-   diagnosis_date
    
-   status
    
-   notes
    

## medications

-   id
    
-   patient_id
    
-   name
    
-   dosage
    
-   frequency
    
-   route
    
-   start_date
    
-   end_date
    
-   active
    

## daily_entries

-   id
    
-   patient_id
    
-   entry_date
    
-   sleep_hours
    
-   sleep_quality
    
-   energy_level
    
-   mood_level
    
-   stress_level
    
-   appetite_level
    
-   hydration_level
    
-   general_notes
    

## symptom_entries

-   id
    
-   daily_entry_id
    
-   symptom_code
    
-   severity
    
-   duration_minutes
    
-   body_location
    
-   metadata_json
    

## vital_sign_entries

-   id
    
-   daily_entry_id
    
-   type
    
-   value
    
-   unit
    
-   measured_at
    

## clinical_documents

-   id
    
-   patient_id
    
-   document_type
    
-   title
    
-   file_url
    
-   upload_date
    
-   exam_date
    
-   source
    
-   ocr_text
    
-   parsed_status
    

## lab_panels

-   id
    
-   document_id
    
-   panel_name
    
-   panel_date
    

## lab_results

-   id
    
-   lab_panel_id
    
-   analyte_name
    
-   value
    
-   unit
    
-   ref_min
    
-   ref_max
    
-   abnormal_flag
    

## imaging_reports

-   id
    
-   document_id
    
-   exam_type
    
-   body_part
    
-   report_text
    
-   impression
    

## timeline_events

-   id
    
-   patient_id
    
-   event_type
    
-   source_type
    
-   source_id
    
-   title
    
-   description
    
-   event_date
    

## ai_summaries

-   id
    
-   patient_id
    
-   summary_type
    
-   period_start
    
-   period_end
    
-   content
    
-   generated_at
    

## alerts

-   id
    
-   patient_id
    
-   severity
    
-   alert_type
    
-   title
    
-   description
    
-   status
    
-   triggered_at
    

## screening_programs

-   id
    
-   code
    
-   name
    
-   description
    
-   min_age
    
-   max_age
    
-   target_sex
    
-   interval_months
    
-   public_coverage_flag
    
-   category
    
-   active
    

## patient_screening_status

-   id
    
-   patient_id
    
-   screening_program_id
    
-   last_done_date
    
-   next_due_date
    
-   status
    

## medication_logs

-   id
    
-   medication_id
    
-   scheduled_at
    
-   taken_at
    
-   status
    
-   notes
    

----------

# 8. API richieste

Implementa REST API v1.

## Auth

-   POST `/api/v1/auth/register`
    
-   POST `/api/v1/auth/login`
    
-   POST `/api/v1/auth/refresh`
    
-   POST `/api/v1/auth/logout`
    

## Profile

-   GET `/api/v1/profile/me`
    
-   PUT `/api/v1/profile/me`
    

## Conditions / allergies / medications

-   POST `/api/v1/profile/conditions`
    
-   GET `/api/v1/profile/conditions`
    
-   POST `/api/v1/profile/allergies`
    
-   GET `/api/v1/profile/allergies`
    
-   POST `/api/v1/profile/medications`
    
-   GET `/api/v1/profile/medications`
    

## Daily journal

-   POST `/api/v1/daily-entries`
    
-   GET `/api/v1/daily-entries`
    
-   GET `/api/v1/daily-entries/{id}`
    
-   PUT `/api/v1/daily-entries/{id}`
    

## Symptoms / vitals

-   POST `/api/v1/daily-entries/{id}/symptoms`
    
-   POST `/api/v1/daily-entries/{id}/vitals`
    

## Documents

-   POST `/api/v1/documents/upload`
    
-   GET `/api/v1/documents`
    
-   GET `/api/v1/documents/{id}`
    
-   POST `/api/v1/documents/{id}/process`
    

## Timeline

-   GET `/api/v1/timeline`
    

## Insights

-   GET `/api/v1/insights/daily`
    
-   GET `/api/v1/insights/weekly`
    
-   GET `/api/v1/insights/pre-visit`
    

## Alerts

-   GET `/api/v1/alerts`
    
-   POST `/api/v1/alerts/{id}/resolve`
    

## Screenings

-   GET `/api/v1/screenings/catalog`
    
-   GET `/api/v1/screenings/me`
    
-   POST `/api/v1/screenings/recompute`
    
-   POST `/api/v1/screenings/{id}/mark-done`
    

## Medications

-   GET `/api/v1/medications/logs`
    
-   POST `/api/v1/medications/{id}/log`
    

## Reports

-   POST `/api/v1/reports/generate`
    
-   GET `/api/v1/reports/{id}`
    

----------

# 9. Regole AI e contenuti medici

Il comportamento AI deve rispettare queste istruzioni.

## 9.1 Stile di output

-   semplice
    
-   clinicamente prudente
    
-   non sensazionalistico
    
-   utile
    
-   basato sui dati presenti
    

## 9.2 Divieti

Non deve:

-   fare diagnosi definitive
    
-   dire che un utente ha una malattia senza conferma medica
    
-   prescrivere farmaci
    
-   rassicurare in modo improprio in presenza di red flags
    
-   ignorare alert deterministici
    

## 9.3 Ordine logico

Prima:

-   controlla red flags e rule engine
    

Poi:

-   genera sintesi narrativa
    

## 9.4 Ogni sintesi deve includere

-   periodo analizzato
    
-   dati considerati
    
-   trend principali
    
-   punti di attenzione
    
-   suggerimento prudente
    

----------

# 10. Logica di notifiche

Implementa un notification engine per:

-   reminder check-in giornaliero
    
-   reminder farmaci
    
-   reminder screening
    
-   documenti da completare
    
-   report pronti
    
-   alert clinici
    
-   prevenzione personalizzata
    

Canali:

-   push
    
-   inbox interna app
    
-   email opzionale futura
    

Ogni notifica deve avere:

-   tipo
    
-   titolo
    
-   body
    
-   priority
    
-   read_status
    
-   created_at
    

Le notifiche devono essere controllabili dall’utente.

----------

# 11. Sicurezza e privacy

Il codice deve essere progettato come sistema che tratta dati sanitari.

Requisiti minimi:

-   JWT sicuri
    
-   password hash robuste
    
-   validazione input
    
-   autorizzazione per resource ownership
    
-   accesso solo ai dati del proprio profilo
    
-   file upload sicuri
    
-   logging senza esporre PHI inutile
    
-   separazione metadata e file
    
-   audit trail pronto per estensione
    

Non implementare feature insicure “per velocità”.

----------

# 12. Testing richiesto

Devi includere:

## Backend

-   unit test servizi principali
    
-   test API critiche
    
-   test auth
    
-   test daily entries
    
-   test screenings rules
    
-   test alerts rule engine
    

## Flutter

-   widget test base
    
-   test repository
    
-   test provider logici
    
-   test dei flow critici:
    
    -   login
        
    -   check-in
        
    -   upload documento
        
    -   visualizzazione timeline
        

----------

# 13. Ordine di implementazione obbligatorio

Segui questo ordine.

## Fase 1

-   auth
    
-   onboarding
    
-   profilo clinico
    
-   diario giornaliero
    
-   sintomi
    
-   parametri
    
-   timeline base
    

## Fase 2

-   upload documenti
    
-   OCR/text extraction pipeline stub-ready
    
-   parsing base
    
-   visualizzazione documenti
    
-   timeline eventi documentali
    

## Fase 3

-   AI summaries
    
-   red flags engine
    
-   alert center
    
-   report export
    

## Fase 4

-   screening/prevenzione
    
-   reminder
    
-   farmaci e aderenza
    
-   notifiche
    

## Fase 5

-   raffinamento UX
    
-   caching locale
    
-   analytics tecniche
    
-   hardening sicurezza
    
-   test coverage migliore
    

----------

# 14. Deliverable richiesti per ogni fase

Per ogni fase devi fornire:

1.  struttura cartelle
    
2.  file creati
    
3.  codice completo
    
4.  migration DB
    
5.  endpoint documentati
    
6.  sample data seed
    
7.  istruzioni run locale
    
8.  test minimi
    
9.  TODO realistici per fase successiva
    

----------

# 15. Vincoli di qualità

Il progetto deve essere:

-   leggibile
    
-   typed
    
-   coerente
    
-   modulare
    
-   production-oriented
    
-   facilmente manutenibile
    
-   facilmente estendibile
    
-   senza duplicazioni inutili
    
-   senza hardcoded business logic sparsa
    

Qualsiasi regola clinica deve stare:

-   in `rules/`
    
-   oppure in servizi dedicati
    

Qualsiasi logica AI deve stare:

-   in `ai/`
    

----------

# 16. UX minima richiesta

Schermate minime Flutter:

-   Splash / auth
    
-   Onboarding
    
-   Home dashboard
    
-   Daily check-in
    
-   Symptom detail entry
    
-   Documents list
    
-   Document detail
    
-   Timeline
    
-   Alerts
    
-   Screenings
    
-   Medications
    
-   Reports
    
-   Profile
    

Tab principali:

-   Home
    
-   Diario
    
-   Timeline
    
-   Documenti
    
-   Profilo
    

Schermate future:

-   Insights
    
-   Prevenzione
    
-   Caregiver
    
-   Medico
    

----------

# 17. Prompt operativo finale da dare a un LLM

Puoi usare anche questa versione sintetica.

## Prompt master

Sviluppa **ClinDiary**, una mobile app in Flutter con backend FastAPI per monitoraggio clinico quotidiano, timeline sanitaria, gestione documenti clinici, screening/prevenzione, farmaci, report e sintesi AI prudente. Usa Flutter + Riverpod + GoRouter lato mobile, FastAPI + PostgreSQL + SQLAlchemy + Alembic lato backend. Implementa architettura modulare, sicurezza adatta a dati sanitari, red flags tramite motore regole deterministico, AI solo per sintesi e supporto non diagnostico. Procedi per fasi: auth/onboarding/profile, diario giornaliero, timeline, documenti, insights, alerts, screening, farmaci, report. Genera codice reale, test minimi, migrazioni, seed data, README e struttura repository completa.

----------

# 18. La mia raccomandazione finale

Per usare davvero bene questo blueprint con un agente, ti conviene dargli i task in questo ordine:

1.  **genera monorepo struttura completa**
    
2.  **implementa backend auth + profile + daily entries**
    
3.  **implementa app Flutter con flow onboarding e check-in**
    
4.  **collega timeline**
    
5.  **aggiungi documenti**
    
6.  **aggiungi AI e alerts**
    
7.  **aggiungi screening e farmaci**
    
8.  **aggiungi report**
    

Così eviti che l’LLM provi a costruire tutto insieme in modo confuso.

Se vuoi, nel prossimo messaggio ti preparo la versione ancora più utile: un **super prompt già pronto da incollare direttamente in Cursor/Claude Code**, scritto in modo ultra-operativo.
