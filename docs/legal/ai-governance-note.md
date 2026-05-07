# ClinDiary - AI Governance Note

Data: **1 aprile 2026**

## Perimetro AI attuale nel repository pubblico

ClinDiary usa modelli AI per:

- recap giornaliero
- recap settimanale
- recap mensile
- recap pre-visita
- report narrativi AI
- query documentale con citazioni

Nel checkout pubblico corrente queste funzioni sono progettate per il flusso mobile local-first. La generazione testuale Android passa da Gemma in formato LiteRT-LM quando il modello e disponibile sul device; in caso contrario l'app usa fallback locali prudenti.

## Regole operative gia implementate / richieste

- fallback `rule_based`
- nessun invio di dati sanitari a provider esterni nel flusso mobile local-only
- gestione modello esplicita: import, download o provisioning manuale
- no decisione clinica automatica nella prevenzione
- dati device e wearable usati come aggregati locali, non stream grezzi verso servizi esterni
- document query con citazioni obbligatorie quando sono disponibili fonti locali

## Provider attuale nel codice pubblico

- provider generazione Android: `on_device_litertlm`
- modello target: `gemma-4-E2B-it.litertlm`
- embeddings documentali locali: `embeddinggemma-300m.tflite` dove disponibile
- fallback: `rule_based` / fallback locale prudente

Provider cloud, Regolo o pipeline backend non sono parte del flusso pubblico corrente salvo ripristino esplicito di sorgenti backend e contratti/vendor pack.

## Guardrail di prodotto

- nessuna diagnosi
- nessuna prescrizione
- nessuna interpretazione causale forte se i dati non la supportano
- output sempre prudente e contestualizzato
- sezioni UI con notice standardizzate

## Supervisione umana richiesta

- tutte le decisioni cliniche restano fuori dal modello
- gli output servono per organizzare il contesto e preparare il confronto medico
- document query e recap vanno letti come supporto informativo, non come referto

## Incidenti AI da tracciare

- fallback ripetuti
- timeout provider
- risposta non citata o poco supportata
- output allarmistico
- output che supera i limiti di claim del prodotto

## Touchpoints tecnici

- `apps/mobile/lib/features/insights/data/on_device_ai_service.dart`
- `apps/mobile/lib/features/insights/data/on_device_prompt_builder.dart`
- `apps/mobile/lib/features/insights/data/insights_repository.dart`
- `apps/mobile/lib/features/documents/data/documents_repository.dart`
- `apps/mobile/lib/shared/widgets/clinical_scope_notice.dart`
