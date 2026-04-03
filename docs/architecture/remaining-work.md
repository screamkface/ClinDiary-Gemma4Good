# ClinDiary - Cosa Manca Ancora

Questo documento descrive lo stato reale del progetto dopo l'ultimo step implementativo e indica i gap ancora aperti rispetto al blueprint.

## Aggiornamento continuo

- Ultimo aggiornamento: **1 aprile 2026**
- Regola operativa: a fine di ogni step implementativo, questo file viene aggiornato con stato reale e prossime priorita.
- Pacchetto business/documentale aggiunto per founder outreach verso So.Re.Sa./Regione Campania, con piano operativo per la fase senza societa`, gate di costituzione e strategia di accesso progressivo a pilot e procurement.
- aggiunto report markdown completo dello stato attuale del prodotto, con funzioni, modelli AI, stack tecnologico, architettura e gap ancora aperti in `docs/architecture/app-current-state-report.md`

## Snapshot rapido (1 aprile 2026)

- Fasi 1-4: implementate e testate.
- Fase 5: baseline importante presente:
  - middleware HTTP con `X-Request-ID`, `X-Response-Time-Ms`, logging strutturato e rate limit auth Redis-backed con fallback in-memory
  - adapter AI provider-agnostic con supporto `openai_compatible`, `regolo_ai`, `gemini_ai_studio` e fallback sicuro al provider rule-based; Regolo AI e` il provider di default nel setup attuale con modello `minimax-m2.5`
  - verifica locale completata: Regolo AI risponde davvero su `minimax-m2.5` senza fallback; timeout AI locale aumentato a 60 secondi per accomodare la latenza del provider
  - recap AI lunghi corretti: il renderer mobile mostra tutto il contenuto senza clipping locale e il backend assegna un budget output piu alto a `weekly`, `monthly` e `pre_visit` per evitare troncamenti del provider
  - recap AI con tabelle gestite deterministicamente nel renderer condiviso: markdown table e pipe-table semplici vengono convertite in tabelle native scrollabili su Giorno, Settimana, Mese, Pre-visita, Storico e Report
  - prompt AI arricchiti con contesto paziente completo: profilo, regione, condizioni, allergie, familiarita, terapie, storico giornaliero, aderenza farmaci, esami recenti, imaging e alert aperti
  - recap prudenti persistiti per giorno, settimana e mese con endpoint dedicati e scheduling automatico via Celery beat
  - eval CLI AI disponibile su casi curati (`clindiary-ai-eval`) per validare struttura, disclaimer e provider reale oltre al semplice smoke
  - OCR modulare con `pypdf` + adapter `paddleocr`, env/config pronti e runtime Docker verificato su build `backend/worker`
  - runtime OCR locale verificato su Windows dopo installazione delle dipendenze `paddleocr` e `paddlepaddle`, con smoke `clindiary-ocr-smoke` attivo
  - smoke CLI locali disponibili per validare AI, OCR e notifiche su dati reali o payload di prova (`clindiary-ai-smoke`, `clindiary-ocr-smoke`, `clindiary-notification-smoke`)
  - audit CLI locale disponibile per verificare rapidamente se la configurazione push/email e` pronta per provider reali (`clindiary-notification-audit`)
  - test delivery notifiche disponibile via API/app per verificare push/email con configurazione reale o stub locale
  - integrazione smartwatch/wearable via Health Connect (Android) e Apple Health/HealthKit (iOS) con import aggregato per giornata, sync backend dedicata, auto-sync all'avvio se i permessi sono gia presenti e shortcut esplicito per aprire le autorizzazioni salute quando il prompt non compare
  - schermata wearable con diagnostica copiabile per supporto/debug su device reali
  - diagnostica wearable arricchita: separa permessi Health Connect e Attivita fisica, mostra sorgenti rilevate, metriche presenti/assenti e una verifica rapida che aiuta a capire se il blocco e` in ClinDiary o nell'app del wearable (es. Xiaomi Fitness)
  - adapter wearable Android corretto per non richiedere piu `EXERCISE_TIME`, che nella versione attuale del plugin `health` non e` mappato correttamente su Health Connect e generava warning rumorosi
  - adapter wearable Android riallineato anche su HRV: usa `HEART_RATE_VARIABILITY_RMSSD` al posto di `SDNN` su Health Connect, evitando richieste permessi con datatype non supportati lato plugin
  - adapter wearable Android corretto anche sulla distanza: usa `DISTANCE_DELTA` al posto di `DISTANCE_WALKING_RUNNING` su Health Connect, evitando falsi negativi nel controllo permessi
  - sync wearable backend reso robusto ai duplicati same-day nel payload; il client mobile ora gestisce anche risposte server non-JSON senza mostrare piu `FormatException` grezze
  - reader wearable Android ampliato: ora prova a importare anche `SLEEP_SESSION` e `WORKOUT` come fallback, e la diagnostica mostra anche la distanza quando presente
  - schermata wearable resa piu esplicita sui casi di export parziale: traduce i package sorgente in nomi leggibili (`Google Fit`, `Xiaomi Fitness`) e mostra un warning dedicato quando Health Connect espone solo dati attivita`, evitando che l'utente scambi un limite del provider per un bug di ClinDiary
  - scheduling farmaci avanzato con giorni specifici, finestre attive, cicli on/off e pausa temporanea
  - screenings con availabilities regionali seedate per Italia e filtro `region_code`, agganciati al `region_code` del profilo e propagati a prevenzione/notifiche/LLM; il profilo espone la regione di screening e le schermate prevenzione la mostrano
  - copertura regionale completa con portali istituzionali verificati per tutte le regioni italiane, inclusa Trentino-Alto Adige/Südtirol
  - audit CLI dei portali regionali disponibile per rilevare rapidamente link rotti o cambiati
  - catalogo prevenzione espanso con livelli `routine`, `risk_based` e `not_routine`, seed incrementale/upsert su DB esistenti e schermata mobile dedicata piu leggibile
  - prevenzione personale con voci di routine come visita annuale, pressione, BMI, salute mentale, revisione vaccini, HIV/HCV almeno una volta; voci risk-based come lipidi e diabete; voci solo catalogo per interventi non routinari negli asintomatici come screening testicolare ed ecografie generiche
  - regole screening estese con contesto BMI oltre a eta, sesso, fumo e familiarita
  - checklist personale annuale nella schermata prevenzione con spunte per l'anno solare corrente; i completamenti sono persistiti in un log dedicato e possono essere aggiunti/rimossi senza perdere lo storico degli anni precedenti
  - secondo livello di catalogo prevenzione introdotto: `visita annuale consigliata` separata da `esami e controlli da discutere col medico`, con classificazione centralizzata `care_pathway` esposta dalle API
  - nuovo `Centro prevenzione personale` con aggregazione reale di: visita annuale, controlli per eta/sesso, vaccini consigliati da verificare, controlli stagionali e reminder di follow-up
  - `Centro prevenzione` mobile ora organizzato anche con tab bar (`Sintesi`, `Controlli`, `Vaccini`, `Percorsi`, `Follow-up`) per raggiungere subito le aree chiave senza scroll lungo
  - pattern UX a tab esteso anche alle schermate lunghe principali: `Profilo` (`Sintesi`, `Contesto`, `Clinico`), `Storico` (`Giorno`, `Calendario`), `Dossier salute` (`Sintesi`, `Clinico`, `Referti`, `Diario`, `Condividi`) e `Report clinici` (`Genera`, `Ultimo report`)
  - ulteriore semplificazione dentro le tab piu dense: `Profilo > Clinico` ora usa uno switcher compatto tra `Farmaci`, `Patologie`, `Allergie`, `Familiarità`; `Storico > Giorno` usa uno switcher tra `Recap`, `Check-up`, `Eventi`, `Documenti`, `Wearable`
  - polish visivo globale del nuovo pattern di navigazione: `TabBar` e `SegmentedButton` sono ora uniformati dal tema app con indicatori, pesi tipografici, colori e superfici coerenti su tutte le schermate tabbed
- fix di robustezza UX: gli switcher interni di `Profilo > Clinico` e `Storico > Giorno` ora sono scrollabili orizzontalmente e non comprimono piu i label, evitando RenderFlex overflow e spezzature brutte tipo `Pato-logie`
- la bottom navigation ora clampa localmente il text scale per evitare overflow con testo ingrandito e le impostazioni usano controlli scrollabili al posto dei segmenti compressi
- nuovo `Dossier salute` con vista ordinata e pronta all'uso di: profilo, problemi clinici, allergie, patologie, farmaci, familiarita, storico vaccinale, diario recente, documenti/referti, lab strutturati, imaging, insight, report, alert e wearable, con scheda emergenza condivisibile in beta, PDF dedicato per soccorritori, link sicuri revocabili, condivisione rapida NFC/QR, provenance chiara e export/share PDF + backup JSON dedicati
- `Dossier salute` arricchito anche con sintesi pulite delle misure da dispositivi clinici collegati, mostrate in una sezione dedicata e riportate anche nell'export PDF
- sintesi device clinici ora strutturate e riusate in modo coerente tra dossier e recap/report AI, con `latest_value`, `trend_label` e note di attenzione deterministicamente derivate dove presenti
- roadmap tecnica integrazioni device/app salute aggiunta in `docs/architecture/device-integration-roadmap.md`, con matrice vendor reale, priorita` (`OMRON`, `Withings`, `iHealth`, `A&D`, `Dexcom` come Wave 1) e strategia ibrida `hub + vendor API + BLE`
- aggiunte anche system instruction riusabili per GPT-5.4 in `docs/architecture/gpt54-system-instruction.md` e `docs/architecture/gpt54-system-instruction-short.md`
- modulo `Dispositivi` Wave 1 implementato davvero: catalogo provider (`OMRON`, `Withings`, `iHealth`, `A&D`, `Dexcom`), connessioni profilo-scoped, import job, misure normalizzate, API `/api/v1/devices/*` e schermata mobile dedicata
- schermata `Dispositivi` migliorata: dai connettori con ingest manuale l'utente puo` registrare direttamente misure cliniche (pressione, peso, SpO2, temperatura, FC, glicemia) senza uscire dall'app
- i report/recap AI ora includono anche le misure dei device clinici Wave 1 in forma sintetica e deterministica per metrica, senza inviare stream grezzi al modello
- `Chiedi ai documenti` ora espone meglio la copertura del retrieval: ambito della ricerca, numero documenti, numero passaggi e nota di copertura mostrati direttamente in UI
- notifiche adapter-ready con preferenze `push/email`, registrazione device e delivery service `log_only/webhook/smtp`
  - reminder farmaci locali su device via `flutter_local_notifications` + `timezone`, sincronizzati dall'app in base a terapia e preferenze; il backend non genera piu `medication_reminder`
  - area storico mobile con calendario giornaliero e dettaglio giorno (`check-up`, eventi, documenti e report giornaliero)
  - calendario storico mobile con pallino sui giorni attivi e eventi giornalieri separati in card
  - home mobile con badge rosso su `Notifiche` se ci sono elementi non letti e su `Farmaci` se oggi esistono dosi pianificate gia scadute ma non ancora registrate
  - mobile con coda offline estesa a profilo, vaccini, notifiche e documenti, con trace rete persistite in Drift e schermata `Sync locale` piu leggibile
  - recap AI mobile promosso a tab dedicata centrale nella bottom navigation, con schermata chat-like a scroll pieno e azioni `copia`/`rigenera` fisse in alto
  - UI mobile core ripulita in chiave minimal: Home riordinata come hub, Profilo compattato, Diario/Timeline/Documenti resi piu leggibili a blocchi, header piu corti e meno testo dispersivo
  - Home mobile rifinita come hub a gerarchia chiara: stato del giorno, azioni principali, profili e strumenti secondari sono ora separati in livelli visivi piu netti
  - Profilo mobile rifinito in blocchi distinti: riepilogo assistito, dati rapidi, contesto personale e liste cliniche compatte con delete esplicito
  - schermate secondarie riallineate al look minimal: Notifiche, Farmaci, Prevenzione, Storico e Centro prevenzione hanno copy piu corto, sezioni piu nette e meno rumore visivo
  - passata UI finale estesa anche a Documenti, Dossier, Report, Smartwatch, Impostazioni, Privacy AI e Sync locale: meno testo introduttivo, piu blocchi compatti, card/fact box e gerarchia visiva piu uniforme su tutto il mobile
  - bottom navigation mobile rifinita in stile floating minimal: barra piu compatta, colori allineati al tema ClinDiary e pulsante AI centrale rialzato ma piu integrato; per mantenere una navbar simmetrica a 5 slot la Timeline e stata spostata sotto il ramo Home invece di restare una tab primaria
  - dettaglio documento ripulito dopo il parsing: il testo estratto OCR e` nascosto di default e si apre solo su richiesta dell'utente con toggle esplicito
  - modulo Documenti evoluto in archivio a cartelle: creazione cartelle, breadcrumb, upload nella cartella corrente, spostamento file tra cartelle e ricerca deterministica per titolo, nome file, fonte e testo estratto
  - timeline mobile riorganizzata per giorno con intestazioni dedicate, conteggio eventi per data e card compatte, al posto del feed lineare unico
  - timeline mobile arricchita con filtri rapidi per categorie (`Tutti`, `Check-up`, `Documenti`, `Farmaci`, `Prevenzione`, `Alert`, `Report`)
  - tab `Recap AI` con calendario compatto e pallini sui giorni con attivita, collegato direttamente alla data del recap
  - dialogo nuovo profilo familiari reso scrollabile, con data di nascita via date picker e cancel safe per evitare overflow su schermi piccoli
  - dialogo modifica profilo reso scrollabile, con data di nascita via date picker e cancel safe per evitare overflow su schermi piccoli
  - dialoghi vaccini, problemi clinici e conferme del dossier/documenti resi piu robusti, scrollabili dove serve e con dismiss safe via rootNavigator
  - routing shell mobile allineato al back gesture: le branch con stack interno tornano alla pagina precedente, le root branch tornano alla Home prima di uscire dall'app
  - back gesture mobile corretto su tutta la shell: ogni tab usa il proprio navigator stack, quindi lo swipe indietro chiude prima la pagina corrente della branch e non esce piu prematuramente dall'app
  - audit trail persistente (`audit_logs`) per auth, profilo, documenti, notifiche e farmaci
  - metriche runtime esportate su `/metrics` con contatori HTTP/OCR/document scan
  - document hardening con hash SHA-256, validazione firma MIME e scan hook configurabile
  - OCR con retry e fallback secondario `tesseract` oltre al provider primario
  - metadata AI persistiti (`provider_name`, `model_name`) per ogni summary
  - delivery backend push/email pronto per `webhook`, `fcm`, `apns`, `smtp`
  - chain Alembic ripristinata e tabella `alembic_version` estesa per supportare revision id lunghi
  - API dedicate per edit/pause/resume/delete schedule farmaci senza ricreare la terapia
  - delete reale da mobile/backend per allergie, patologie note, farmaci e familiarita
  - schermate mobile `Profilo`, `Farmaci`, `Storico` e `Insights` rese piu compatte e leggibili, con blocchi/card al posto di testo continuo
  - resa mobile dei recap AI migliorata: parser condiviso piu robusto per markdown/sezioni, titoli in evidenza e report clinici allineati allo stesso renderer leggibile
  - fix del crash Flutter sul date picker in `Insights` tramite localizzazioni Material/Cupertino configurate in app
  - reminder farmaci locali: niente prompt automatico non richiesto, skip corretto delle dosi gia registrate e permesso Android `POST_NOTIFICATIONS` dichiarato
  - mobile con queue offline estesa per azioni notifiche e schermata `Sync locale` per debug/flush
  - archivio documenti differenziato per piano: `free` usa un vault locale sul dispositivo con cartelle, move-file e ricerca metadata-only; `AI Plus` usa l archivio cloud backend con OCR, parsing, reindex e query documentale
  - vault documenti locale ora isolato per utente e profilo attivo sul device, evitando mescolamenti tra account o profili familiari
  - downgrade documenti rifinito: i file già caricati nel cloud restano consultabili in sola lettura anche sul piano free, mentre upload/process/move/delete cloud restano bloccati a AI Plus
  - cambio piano mobile riflesso subito sui provider documenti grazie all invalidazione patient-scoped; in caso di errore nel fetch billing il repository documenti ricade ora in modo prudente sulla modalità `local`
  - testing semplificato: il piano demo AI Plus continua a sbloccare tutto in debug, quindi durante i test puoi passare da archivio locale a cloud senza cambiare app o repo
- Suite verificata storicamente:
  - `apps/backend/.venv/bin/pytest apps/backend/tests -q`
  - `cd apps/mobile && flutter analyze`
  - `cd apps/mobile && flutter test`
  - `cd apps/mobile && flutter build apk --debug`
- Tooling locale:
  - script Android disponibili in `scripts/run_android_app.sh` e `scripts/run_android_app.ps1`; il launcher Android accetta sia l'ID sia il nome Flutter del device e supporta `--restart-services` per ricaricare davvero `.env` e provider esterni
  - logging script corretto su `stderr` per non contaminare `API_BASE_URL` durante `flutter run`
  - `LocalDatabase` Drift include una migration strategy esplicita per upgrade schema su device
- env backend locale presente in `apps/backend/.env`, caricato automaticamente dallo script Android insieme al `.env` di root se presente
- nuova documentazione legale dedicata in `docs/legal/` con overview conformita UE/Italia e gap analysis operativa GDPR / Regolo / MDR
- aggiunta anche checklist operativa pre-lancio in `docs/legal/pre-launch-checklist.md`
- aggiunto anche piano esecutivo dettagliato in `docs/legal/legal-execution-plan.md`
- aggiunto anche registro provider AI e nota tecnica sulla cifratura del vault locale in `docs/legal/ai-provider-register.md` e `docs/legal/local-vault-encryption-note.md`
  - aggiunta anche roadmap dedicata della prevenzione in `docs/architecture/prevention-roadmap.md`, con distinzione tra cio che va implementato subito, cio che richiede nuovi dati e cio che non va automatizzato troppo
  - Wave 1 della roadmap prevenzione ora implementata: revisione tabacco e alcol, counselling fumo/alcol a rischio, supporto comportamentale per obesita, counselling alimentazione/movimento nei profili cardiometabolici e mini-catalogo vaccinale piu ricco con uso dello storico vaccinale
  - motore regole screening esteso con nuovi criteri deterministici basati su condizioni note, uso di alcol e livello di attivita
  - Wave 2 della roadmap prevenzione ora implementata in baseline: osteoporosi/salute ossea, screening polmone risk-based, ecografia aorta addominale risk-based, rischio cadute e screening MST personalizzato
  - profilo clinico esteso con campi strutturati per storia tabagica, rischio osseo, cadute e rischio sessuale, usati dal motore prevenzione in modo spiegabile
  - Wave 3 della roadmap prevenzione ora implementata: preconcezione/gravidanza, registro vaccinale piu strutturato nel Centro prevenzione e aree specialistiche mantenute in `shared_decision` o `not_routine` per prostata, cute, vista, vitamina D, tiroide e pannelli ematici generici
  - profilo clinico esteso anche con campi gravidanza/preconcezione (`trying_to_conceive`, `currently_pregnant`, `taking_folic_acid`) per attivare solo i percorsi pertinenti
- avanzamento engineering compliance:
  - account deletion end-to-end con cleanup cloud + locale device
  - export/privacy workflow piu esplicito in app con PDF, JSON e scheda emergenza dalla sezione Privacy AI
  - note legali beta accessibili in app da onboarding, impostazioni, privacy AI e paywall
  - notice UI standardizzate sulle schermate AI/prevenzione per ridurre wording ambiguo o troppo assertivo
  - vault documenti free cifrato lato app con AES-GCM, indice cifrato e apertura tramite copia temporanea decifrata on-demand
  - cleanup retention schedulato per token, audit log e AI summaries configurabili
  - config produzione rinforzata con validazioni su secret/debug/origini
  - FastAPI ora nasconde `docs`, `redoc` e `openapi.json` in produzione
  - telemetria provider/fallback AI estesa e verificata
  - aggiunti anche i deliverable tecnici/documentali mancanti che possiamo chiudere nel repo: `retention-matrix.md`, `security-runbook.md`, `ai-governance-note.md`

## 1. Stato attuale

ClinDiary oggi copre:

- Fase 1: auth, onboarding, profilo, diario, sintomi, parametri, timeline base
- Fase 2: documenti, upload, archivio, processing asincrono, parsing laboratorio/imaging, revisione manuale
- Fase 2 documenti: archivio reale a cartelle con ricerca e move-file, con modalita `locale` sul piano free e `cloud` su AI Plus mantenendo compatibili gli endpoint documentali esistenti
- Fase 2 documenti: il vault locale free e` scoped per utente/profilo, mentre i documenti cloud preesistenti restano visibili in sola lettura dopo downgrade
- Fase 3: insights prudenti daily/weekly/monthly/pre-visit, prompt clinici completi, red flags deterministiche, alert center, report PDF
- Fase 4: screening/prevenzione, aderenza farmaci, notifiche e preferenze notifiche; i reminder farmaci sono locali al device, il backend resta source of truth per terapia e preferenze
- Fase 4 prevenzione: il catalogo distingue tra controlli di routine, controlli da valutare in base al rischio e pratiche non consigliate come routine negli asintomatici
- Fase 4 prevenzione: la Wave 1 ora include anche tabacco, alcol, obesita e counselling lifestyle cardiometabolico con regole esplicite e testate
- Fase 4 prevenzione: la Wave 2 ora aggiunge criteri deterministici per osteoporosi, polmone, aneurisma aortico addominale, cadute e MST personalizzate
- Fase 4 prevenzione: la Wave 3 ora aggiunge gravidanza/preconcezione, registro vaccinale piu strutturato e aree a decisione condivisa per prostata/cute/vista senza trasformarle in automatismi aggressivi
- Fase 4 prevenzione personale: l'utente puo vedere e gestire una checklist annuale dei controlli gia eseguiti nell'anno corrente
- Fase 4 catalogo prevenzione: la visita preventiva generale e distinta dai singoli esami/controlli, cosi la UI non mescola piu visita annuale e test specifici
- Fase 4/5 esperienza prevenzione: l'utente ha anche un Centro prevenzione personale distinto dagli screening grezzi, con vaccini, follow-up e controlli stagionali spiegabili; i vaccini ora usano in modo prudente anche lo storico vaccinale gia registrato
- Dossier salute: l'utente ha una cartella clinica personale ordinata e sempre pronta, costruita aggregando i moduli clinici gia presenti
- Fase 5 baseline: hardening HTTP, rate limit distribuito, OCR configurabile, adapter AI esterno, scheduling farmaci evoluto, screenings regionali seedati, storico giornaliero mobile, offline mobile esteso e wearable sync giornaliera verso backend/AI
- Fase 5 device baseline: modulo `devices` Wave 1 con supporto reale al setup dei connettori clinici, import manuale per i flussi gia` supportati e tracking degli import
- Fase 5 AI/device context: le misure device entrano nel payload AI come aggregati clinici per periodo (`pressione`, `peso`, `SpO2`, `glicemia`, ecc.), con conteggio, media/ultima misura e trend breve
- Fase 5 UI: dialoghi long-form e conferme principali allineati a layout scrollabili, cancel sicuri e back gesture coerente con la shell
- Fase 5 baseline: la chain Alembic e` ora coerente fino a `20260325_0021`, con estensione della tabella di versione per revision id lunghi
- Mutazioni profilo: ogni cambio di profilo riattiva il refresh deterministico di screenings, prevenzione e notifiche dipendenti dal profilo, incluso il cambio regione

## 2. Cosa manca davvero

### 2.1. Gap ancora aperti rispetto al blueprint

1. Validazione provider AI reale
   - Stato: codice pronto per `openai_compatible`, `regolo_ai` e `gemini_ai_studio`, con fallback rule-based e metadata provider/model persistiti; Regolo AI e` il provider di default nel setup attuale con modello `minimax-m2.5` e Gemini resta supportato come alternativa compatibile.
   - Manca ancora:
     - prompt evaluation clinica su casi reali o curati
   - Dove intervenire:
     - `apps/backend/app/ai/summary_provider.py`
     - `apps/backend/app/services/insight_service.py`

2. OCR e scan su casi reali
   - Stato: `pypdf` + `paddleocr` + fallback `tesseract`, retry, hash file, validazione firma MIME e hook di scan; runtime locale verificato con smoke `clindiary-ocr-smoke`.
   - Manca ancora:
     - validazione su scansioni difficili reali
     - eventuale tuning soglie o engine in base ai documenti veri
     - collegamento a un antivirus o webhook reale se desiderato
   - Dove intervenire:
     - `apps/backend/app/services/ocr_service.py`
     - `apps/backend/app/services/document_scan_service.py`
     - `apps/backend/app/services/document_service.py`

3. Push/email end-to-end con credenziali reali
   - Stato: backend pronto per `fcm`, `apns`, `smtp`; device registration e preferenze gia presenti; smoke locale e test delivery API/app disponibili per verificare delivery e configurazione.
   - Manca ancora:
     - credenziali provider vere
     - token device reali lato app e progetti vendor configurati
     - test end-to-end su Android/iOS signed
   - Dove intervenire:
     - `apps/backend/app/services/notification_delivery_service.py`
     - `.env` backend/runtime provider
     - `apps/mobile/android/`
     - `apps/mobile/ios/`

4. Screenings regionali con link istituzionali verificati
   - Stato: plumbing applicativo regionale implementato end-to-end; catalogo prevenzione e regional availability Italia presenti, con tutte le regioni agganciate a portali istituzionali ufficiali.
   - Manca ancora:
     - manutenzione periodica dei link ufficiali se i portali regionali cambiano
     - eventuale arricchimento con link ASL/singole aziende sanitarie dove utile
   - Dove intervenire:
     - `apps/backend/app/services/screening_service.py`
     - `apps/backend/app/seed.py`

5. Offline-first ancora piu esteso
   - Stato: medication logs, notifiche, mutazioni profilo/vaccini e documenti sono queue-able; trace e debug UI presenti.
   - Coda offline con replacement last-write-wins per le mutation ripetute sullo stesso endpoint, cosi gli edit offline non si accumulano in duplicato.
   - Manca ancora:
      - sync/merge su piu feature cliniche
      - conflict resolution piu ricca
   - Dove intervenire:
     - `apps/mobile/lib/app/core/storage/local_database.dart`
     - `apps/mobile/lib/app/core/network/api_client.dart`
     - `apps/mobile/lib/features/*/data/`

6. Coverage e validazioni finali
   - Stato: suite backend/mobile verde e piu ampia della baseline.
   - Manca ancora:
     - integration test con file OCR reali
     - test adapter FCM/APNs/SMTP con mocking piu profondo
     - validazione wearable su device reali, soprattutto su Android OEM come Xiaomi/MIUI dove il prompt Health Connect puo avere comportamenti diversi
   - Dove intervenire:
     - `apps/backend/tests/`
     - `apps/mobile/test/`

7. Governance privacy/GDPR/AI prima della produzione
   - Stato: consenso sanitario generico presente, consenso AI esterno separato gia implementato in onboarding e nelle impostazioni, enforcement backend attivo, provider AI configurabili e fallback rule-based locale disponibile. In app sono ora esposte note legali beta e workflow privacy piu espliciti per export e cancellazione account; il vault documenti free ha anche un primo layer di cifratura applicativa.
   - Manca ancora:
     - privacy notice dedicata all'AI e ai provider esterni
     - DPIA e registro trattamenti
     - workflow completo e formalizzato lato operations per export/cancellazione/portabilita
     - contratto e transfer assessment per provider cloud esterni
   - Dettaglio operativo: vedi `docs/architecture/pre-production-gdpr-ai.md` e `docs/architecture/privacy-ai-notice-draft.md`

8. Device connectors live con onboarding vendor reale
   - Stato: Wave 1 applicativa gia` presente con modelli, API, UI, catalogo provider, import job e ingest manuale. Il modulo e` gia` usabile per bootstrap/setup e per flussi non dipendenti da credenziali vendor.
   - Manca ancora:
     - callback OAuth e token exchange live per `Withings`, `iHealth`, `Dexcom`
     - onboarding/approval partner per `OMRON` e `Dexcom`
     - bridge SDK/BLE reale per `OMRON` e, se desiderato, `A&D`
     - webhook/polling live vendor e normalizzazione payload reali
   - Dove intervenire:
     - `apps/backend/app/services/device_service.py`
     - `apps/backend/app/api/v1/devices.py`
     - `apps/mobile/lib/features/devices/`
     - eventuali adapter vendor-specific futuri in `apps/backend/app/services/vendors/`

### 2.2. Gap secondari o opzionali

- CRUD ancora piu ricco per documenti e farmaci
- migrazione opzionale da archivio locale a cloud per i documenti gia presenti sul dispositivo quando un utente passa a AI Plus
- storico vaccinale compilabile e follow-up di prevenzione ancora piu dettagliati
- ulteriore raffinamento UI/UX delle schermate secondarie meno usate
- ruoli caregiver/doctor
- schermate future citate nel blueprint ma non ancora prioritarie
- marker calendario e filtri rapidi per giorni con sync wearable
- gestione UI ancora piu ricca per terapie multiple complesse
- bridge BLE / OAuth live dei connettori device Wave 1 dopo ottenere credenziali e approval partner

## 3. Cosa puoi modificare subito, in base all'obiettivo

### Se vuoi migliorare i documenti/OCR

Modifica qui:

- `apps/backend/app/services/document_service.py`
- `apps/backend/app/services/document_parser.py`
- `apps/backend/app/services/document_classifier.py`
- `apps/backend/app/services/ocr_service.py`
- `apps/mobile/lib/features/documents/presentation/`

### Se vuoi migliorare la logica clinica

Modifica qui:

- `apps/backend/app/rules/red_flags.py`
- `apps/backend/app/rules/screenings.py`
- `apps/backend/app/services/profile_service.py` per decidere quando riapplicare le regole dopo un cambio profilo
- `apps/backend/app/services/notification_service.py` e `apps/backend/app/services/screening_service.py` per il refresh persistito di screening/notifiche
- `apps/backend/app/models/screening_completion_record.py` e `apps/backend/alembic/versions/20260324_0014_screening_completion_records.py` per il log storico dei completamenti annuali
- `apps/backend/app/services/screening_service.py` e `apps/backend/app/schemas/screenings.py` per la classificazione `care_pathway` (`annual_visit`, `discuss_with_doctor`, `not_routine`)
- `apps/backend/app/services/prevention_center_service.py` e `apps/backend/app/schemas/prevention_center.py` per il Centro prevenzione personale
- `apps/mobile/lib/features/screenings/` per il catalogo prevenzione lato app e il modo in cui mostriamo routine/risk-based/not-routine
- `apps/mobile/lib/features/prevention_center/` per la UI aggregata di vaccini, stagionalita e follow-up

### Se vuoi migliorare le integrazioni device/app salute

Modifica qui:

- `apps/backend/app/services/device_service.py`
- `apps/backend/app/repositories/device_repository.py`
- `apps/backend/app/api/v1/devices.py`
- `apps/backend/app/models/device_*.py`
- `apps/mobile/lib/features/devices/`
- `docs/architecture/device-integration-roadmap.md`

Non mettere la logica clinica in UI o repository.

### Se vuoi migliorare l'AI

Modifica qui:

- `apps/backend/app/ai/summary_provider.py`
- `apps/backend/app/services/insight_service.py`
- `apps/backend/app/workers/summary_tasks.py`

Non mettere la logica AI in `rules/`.

### Se vuoi aggiungere nuove API

Modifica qui:

- route: `apps/backend/app/api/v1/`
- schema request/response: `apps/backend/app/schemas/`
- orchestrazione: `apps/backend/app/services/`
- accesso dati: `apps/backend/app/repositories/`
- persistence: `apps/backend/app/models/`
- migrazione: `apps/backend/alembic/versions/`

### Se vuoi cambiare il mobile

Modifica qui:

- feature: `apps/mobile/lib/features/<feature>/`
- wiring globale: `apps/mobile/lib/app/router.dart`
- provider: `apps/mobile/lib/app/providers.dart`
- dipendenze/repository DI: `apps/mobile/lib/app/dependencies.dart`
- storage locale/offline: `apps/mobile/lib/app/core/storage/`
- rete/tracing: `apps/mobile/lib/app/core/network/`
- tema: `apps/mobile/lib/app/theme/app_theme.dart`
- storico giornaliero: `apps/mobile/lib/features/history/`
- dossier utente: `apps/mobile/lib/features/dossier/`
- prevenzione personale: `apps/mobile/lib/features/prevention_center/`
- wearable UX: `apps/mobile/lib/features/wearables/`

## 4. Priorita consigliata

Ordine sensato da seguire adesso:

1. chiudere il runtime OCR containerizzato con una smoke reale su scansione
2. validare Regolo AI o un altro provider reale con chiave vera e misurare output/guardrail sui prompt clinici completi
3. completare push vendor-backed oppure email transazionale reale
4. audit trail sicurezza + hardening upload
5. validare il flusso wearable su dispositivi reali Android, inclusi Xiaomi/MIUI, dopo l'aggiunta del bottone per aprire le autorizzazioni salute
6. estendere l'offline queue mobile oltre ai medication logs e aggiungere una sync console piu ricca
7. arricchire i link screening regionali con fonti istituzionali verificate
8. aumentare la coverage test sui flussi nuovi

## 5. Cosa non devi toccare senza motivo

- file generati in `.dart_tool/`, `build/`, `__pycache__/`, `.venv/`
- file Flutter ephemerals
- registrant generati di piattaforma, se non stai lavorando a plugin/platform integration
- migrazioni vecchie gia applicate: non modificarle, aggiungine di nuove
