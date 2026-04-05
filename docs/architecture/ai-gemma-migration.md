# ClinDiary AI Gemma Migration

## Obiettivo

Per la submission Kaggle `Gemma 4 Good Hackathon`, ClinDiary non prova a rendere locale tutta la piattaforma AI.

Il focus implementato e:

- `Private / Local Daily Recap`

Questa scelta mantiene il progetto dimostrabile, sicuro e coerente con l'architettura esistente.

## Flusso attuale

ClinDiary continua a separare due blocchi:

1. logica clinica deterministica
2. narrativa AI prudente

Restano deterministici:

- red flags
- screening e prevenzione
- reminder e follow-up hard-coded
- eligibilita e regole cliniche spiegabili

Il modello viene usato per:

- recap giornalieri
- recap periodici
- pre-visita
- sintesi narrative

## Cosa e stato aggiunto

### Backend

- alias provider `local_gemma4`
- override per-call su provider/runtime/model
- endpoint dedicati:
  - `GET /api/v1/insights/daily/private-local`
  - `POST /api/v1/insights/daily/private-local/regenerate`
  - `GET /api/v1/insights/local-status`
- endpoint prompt per recap on-device:
  - `GET /api/v1/insights/daily/on-device-prompt`
- payload minimizzato per il recap locale giornaliero
- recap locale transiente, non persistito in `ai_summaries`
- proof metadata sanitizzata per la UI e per i judge
- bootstrap user-space di Ollama in `scripts/setup_local_gemma_ollama.sh`
- profilo env locale in `apps/backend/.env.gemma-local.example`

### Mobile

- modalita recap `standard` vs `privata locale`
- modalita recap `sul dispositivo`
- proof card leggibile nella schermata `Recap AI`
- badge provider coerente con il proof endpoint
- schermata `Gestisci modello` per import, rimozione, reset runtime e dettagli file
- card `Scenari demo` in Home quando `HACKATHON_DEMO_MODE=true`
- bridge Android nativo `LiteRT-LM` tramite `MethodChannel`
- runtime on-device con risoluzione automatica del file `.litertlm` in `Android/data/it.clindiary.clindiary/files/models/`
- import in-app del file `.litertlm` direttamente dalla schermata `Recap AI`
- primo prompt-builder locale mobile: se il contesto del giorno e presente in cache, il telefono costruisce il prompt senza chiamare l'endpoint backend

### Demo mode

- `HACKATHON_DEMO_MODE=true`
- utente demo con tre scenari profilo
- entitlement AI automatici per il demo user, senza toggle billing manuali

## Perche backend-host locale e stato il primo passo

Per il MVP hackathon, `locale` significa:

- runtime privato/locale sul backend host
- nessuna dipendenza obbligatoria da provider cloud per il recap locale
- proof endpoint verificabile

Questa scelta e piu solida di un tentativo affrettato di inference on-device mobile, perche:

- non cambia l'architettura Flutter
- non introduce un doppio stack Android/iOS
- mantiene osservabilita e fallback chiari
- resta facile da dimostrare in video e ai judge

Una volta chiuso quel passaggio, ClinDiary e stato esteso anche con il percorso on-device Android:

- il backend costruisce il prompt prudente minimizzato
- Android esegue l'inferenza finale via LiteRT-LM
- la proof card mostra runtime, backend risolto e modello rilevato sul device

Questo e oggi il percorso demo piu forte sul telefono.

## Cosa rimane volutamente fuori

- full local RAG documentale come hero feature
- OCR locale come centro della submission
- sostituzione del motore deterministico con il modello

Resta fuori:

- iOS on-device
- document RAG come inference locale hero feature
- import in-app di file modello multi-gigabyte

## Posizionamento hackathon

La narrativa corretta e:

> ClinDiary e una personal health memory mobile-first.
> Gemma 4 abilita un recap giornaliero prudente tramite percorso on-device Android e, in alternativa, tramite percorso privato locale lato host.
> I dati sensibili non devono uscire obbligatoriamente verso un provider cloud per il caso d'uso base.
> Le regole cliniche safety-sensitive restano deterministiche e spiegabili.

## Limiti noti

- `Gemma 4 On-device` viene mostrato in UI solo se il runtime Android rileva un model label coerente
- l'inferenza on-device e oggi disponibile solo su Android
- il file `.litertlm` puo essere provisionato manualmente sul device oppure importato dall'app
- il prompt prudente viene costruito in locale quando i dati necessari sono gia presenti in cache; se il contesto locale non basta, ClinDiary ricade ancora sul backend per il solo prompt minimizzato
- su host di sviluppo con risorse limitate puo essere necessario un modello Gemma piu piccolo solo per smoke/dev
- il recap locale e piu corto e intenzionalmente limitato rispetto ai flussi cloud piu ricchi
