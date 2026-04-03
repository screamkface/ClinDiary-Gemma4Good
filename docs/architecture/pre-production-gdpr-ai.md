# Cose importanti da fare prima della produzione

Questa nota traduce il quadro attuale in una checklist di governance privacy e AI prima di usare ClinDiary come app principale per una cartella clinica personale.

> Nota: non e parere legale. E una checklist di prodotto/privacy basata sul comportamento attuale del repo.

## Stato attuale

- Il consenso ai dati sanitari esiste nell'onboarding e viene salvato lato backend.
- Esiste anche un consenso AI esterno separato, revocabile da onboarding o impostazioni, e il backend impedisce ai recap di usare provider esterni se l'utente non ha opt-in.
- La schermata `Privacy AI` nel mobile raccoglie consenso, revoca ed export dei dati principali in un unico posto.
- Il motore AI e provider-agnostic: `rule_based` locale, `openai_compatible` e `gemini_ai_studio`.
- Il prompt AI invia un payload molto ricco con profilo, condizioni, farmaci, wearable, documenti, recap precedenti, episodi clinici e alert.
- Il fallback locale `rule_based` e disponibile, quindi si puo tenere una modalita piu prudente senza provider esterni.
- Restano ancora da completare in modo formale: privacy notice dedicata all'AI, flusso completo dei diritti GDPR, documentazione DPIA/registro trattamenti e testi legali finali per i provider cloud.

Riferimenti nel codice:

- `apps/mobile/lib/features/onboarding/presentation/onboarding_screen.dart`
- `apps/backend/app/services/profile_service.py`
- `apps/backend/app/ai/summary_provider.py`
- `apps/backend/app/services/insight_service.py`

## Cose da chiudere prima della produzione

1. Informativa privacy e AI separata
   - Spiega chiaramente se e quando i dati sanitari vengono inviati a provider esterni.
   - Distingui tra uso locale/rule-based e uso di Gemini o altri provider cloud.

2. Consenso AI separato e revocabile
   - Implementato nel codice: il consenso sanitario generico non basta come messaggio UX e l'app espone gia un opt-in specifico per l'uso di provider esterni nella schermata `Privacy AI`.
   - Da completare con testo legale finale, tracciamento audit e revoca chiara anche nella documentazione utente.

3. Minimizzazione del payload
   - Invia solo i dati necessari al recap.
   - Evita di mandare documenti, recap precedenti o wearable quando il contesto non li richiede.
   - Preferisci `rule_based` locale o provider sotto controllo quando possibile.

4. Contratti e trasferimenti
   - Se il provider e esterno, serve un contratto da responsabile o sub-responsabile del trattamento.
   - Se i dati escono dallo SEE, serve una valutazione dei trasferimenti e garanzie appropriate.

5. DPIA e registro trattamenti
   - Per un'app che tratta dati salute e usa AI e un passaggio da fare prima della produzione.
   - Va documentato chi tratta cosa, per quale finalita, per quanto tempo e con quali misure di sicurezza.

6. Rights workflow
   - Esportazione completa dei dati.
   - Cancellazione account e dati.
   - Rettifica e portabilita.
   - Stato di revoca del consenso visibile e semplice.

7. Logging e retention
   - Non salvare prompt raw o PII nei log.
   - Conserva solo cio che serve: recap finale, provider/model, audit minimo.
   - Definisci tempi di conservazione per summary, documenti e audit.

8. Limiti funzionali dell'AI
   - Niente diagnosi autonoma, triage o prescrizioni.
   - Il recap resta supporto clinico e organizzativo.
   - Se il provider esterno fallisce, fallback locale controllato.

## Regola pratica di produzione

- Default: `rule_based` o provider locale/controllato.
- Provider cloud esterno: solo con opt-in, privacy notice chiara, contratto, transfer check e DPIA chiusa.
- Niente dati piu del necessario.
- Nessun uso del recap come decisione automatica ad effetto clinico o legale.

## Piano operativo consigliato

Se vuoi restare il piu possibile prudente e GDPR-friendly:

1. Mantieni `rule_based` come default per tutti.
2. Aggiungi un toggle separato "Usa AI esterna per i recap" con consenso esplicito.
3. Mostra prima del toggle una mini informativa: quali dati vengono inviati, a quale provider, per quale scopo e con quali limiti.
4. Minimizza il payload per il provider esterno:
   - invia solo il periodo e il contesto necessari
   - evita documenti grezzi se non servono
   - evita recap storici lunghi se un contesto breve basta
5. Non loggare prompt o dati sanitari in chiaro.
6. Conserva solo metadata utili:
   - provider usato
   - modello
   - data di generazione
   - eventuale fallback
7. Aggiungi export completo e cancellazione account in un flusso visibile all'utente.
8. Fai revisione legale/DPO prima di attivare provider cloud in produzione.

Se non vuoi o non puoi chiudere questi punti, la scelta piu sicura e tenere il recap AI locale/rule-based e usare provider esterni solo in beta o in test interni.

## Riferimenti

- GDPR: https://eur-lex.europa.eu/eli/reg/2016/679/oj
- FSE 2.0 e contesto sanitario italiano: https://www.pnrr.salute.gov.it/it/news-e-media/notizie/fascicolo-sanitario-elettronico-20-entra-fase-operativa/
