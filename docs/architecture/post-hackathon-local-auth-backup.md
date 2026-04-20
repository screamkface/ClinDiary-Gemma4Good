# ClinDiary - Post-hackathon: auth locale e backup cifrato

## Contesto

Questa nota raccoglie una proposta post-hackathon per proteggere meglio i dati clinici locali e, in modo opzionale, introdurre backup cloud senza esporre plaintext.

## Decisione consigliata

Usare un modello ibrido con base locale obbligatoria:

- auth locale al primo avvio con password o PIN forte
- biometria solo come sblocco rapido opzionale
- Google Sign-In + Google Drive solo come backup opzionale cifrato end-to-end

## Obiettivi

- proteggere i dati sanitari locali anche in caso di accesso fisico al device
- mantenere UX semplice dopo il primo setup
- preservare modalita offline-first
- preparare restore multi-device senza leggere dati in chiaro lato cloud

## Architettura tecnica minima

### 1) Cifratura dati applicativi

- generare una DEK (Data Encryption Key) random a 256 bit
- cifrare DB locale e vault documenti con DEK (AES-GCM)
- non salvare mai la DEK in chiaro su disco

### 2) Sblocco tramite password/PIN

- derivare KEK da password con Argon2id
- cifrare (wrap) la DEK con KEK
- salvare in secure storage solo:
  - DEK cifrata
  - salt Argon2id
  - parametri KDF versionati

### 3) Biometria opzionale

- usare Android Keystore / iOS Keychain per custodire un secret locale di sblocco rapido
- biometria non sostituisce il setup iniziale con password/PIN
- fallback sempre disponibile con password/PIN

### 4) Lock lifecycle

- app lock all'avvio
- auto-lock su background o inattivita
- wipe memoria volatile delle chiavi quando l'app si blocca

## Backup Google Drive opzionale (E2E)

- Sign-In Google usato per identificare account backup, non per decifrare dati
- upload su area app privata Drive di blob gia cifrati lato app
- restore possibile solo con password/PIN locale
- il cloud non deve mai avere accesso al plaintext

## Fasi consigliate

### Fase A - Local auth e app lock

- onboarding sicurezza locale (password/PIN)
- gestione DEK/KEK e unlock flow
- schermata lock/unlock con biometria opzionale
- timeout di auto-lock configurabile

### Fase B - Backup/restore cifrato

- export snapshot cifrata del vault locale
- upload/download da Google Drive app-private
- restore con verifica integrita e richiesta password/PIN

## Decisioni aperte

- password vs PIN (o supporto a entrambe)
- policy lock (solo background vs background + timeout inattivita)
- frequenza backup automatico e limiti rete/batteria
- UX di recovery se l'utente dimentica password/PIN

## Note compliance

- mantenere allineamento con documenti in `docs/legal/` su retention, security runbook e governance AI
- aggiornare privacy notice quando si abilita backup cloud opzionale
- mantenere audit trail degli eventi critici di sicurezza (unlock falliti, restore, cambio credenziali locali)
