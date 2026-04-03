# ClinDiary - AI Governance Note

Data: **1 aprile 2026**

## Perimetro AI attuale

ClinDiary usa modelli AI per:

- recap giornaliero
- recap settimanale
- recap mensile
- recap pre-visita
- report narrativi AI
- query documentale con citazioni

## Regole operative gia implementate

- fallback `rule_based`
- consenso separato per AI esterna
- gating backend per minori / managed profile policy
- no decisione clinica automatica nella prevenzione
- dati device e wearable inviati come aggregati, non stream grezzi
- document query con citazioni obbligatorie

## Provider attuale

- provider di default: `regolo_ai`
- modello summary/report: `minimax-m2.5`
- modelli RAG documentale:
  - `qwen3-8b`
  - `qwen3-embedding-8b`
  - `qwen3-reranker-4b`

Dettaglio tecnico in:

- `docs/legal/ai-provider-register.md`

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

- `apps/backend/app/ai/summary_provider.py`
- `apps/backend/app/ai/document_rag_provider.py`
- `apps/backend/app/services/insight_service.py`
- `apps/backend/app/services/document_rag_service.py`
- `apps/mobile/lib/shared/widgets/clinical_scope_notice.dart`
