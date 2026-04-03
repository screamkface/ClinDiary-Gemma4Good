# Registro Provider AI

Data ultimo aggiornamento: **31 marzo 2026**

## Provider attivo previsto

- Provider: `Regolo AI`
- Uso principale:
  - recap AI prudenti (`daily`, `weekly`, `monthly`, `pre-visit`)
  - retrieval documentale e risposta con citazioni
- Ambito geografico dichiarato dal fornitore:
  - UE / Italia da verificare con documentazione contrattuale definitiva

## Modelli configurati nel repo

### Recap clinici prudenti

- Provider code: `regolo_ai`
- Model name: `minimax-m2.5`
- Finalita:
  - generazione di riepiloghi prudenti basati su diario, wearable, documenti recenti e alert
- Note tecniche:
  - fallback deterministico `rule_based`
  - payload minimizzato per tipo di recap
  - AI esterna disabilitata per profili minorenni

### RAG documentale

- Answer model: `qwen3-8b`
- Embedding model: `qwen3-embedding-8b`
- Embedding dimensions default: `1024`
- Reranker model: `qwen3-reranker-4b`
- Finalita:
  - interrogazione dei documenti caricati con citazioni esplicite

## Dati inviati al provider

### Recap AI

- contesto clinico non identificativo diretto
- storico diario nel periodo richiesto
- sintomi e parametri
- farmaci e aderenza
- wearable aggregati
- documenti recenti / esami strutturati
- alert aperti

### Esclusioni intenzionali

- nessun nome completo del paziente nel payload recap
- nessun log dei raw prompt sanitari

## Retention e logging tecnici

- fallback locale disponibile se provider esterno non disponibile
- metriche applicative su successo/fallback/config missing
- nessun prompt clinico completo nei log applicativi

## Da verificare con vendor/legal

- DPA firmata o incorporata
- subprocessor list
- retention dichiarata lato vendor
- data residency formale
- misure sicurezza e incident process
