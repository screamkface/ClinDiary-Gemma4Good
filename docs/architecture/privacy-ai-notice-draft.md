# Bozza informativa privacy AI

> Bozza da revisionare con un avvocato o consulente privacy prima della produzione.
> Non e un parere legale e non sostituisce la documentazione ufficiale del titolare del trattamento.

Questa pagina raccoglie una bozza di informativa dedicata all'uso di provider AI esterni in ClinDiary, cosi non si perde il filo tra codice, roadmap e revisione legale.

## 1. Oggetto

ClinDiary consente, su scelta esplicita dell'utente, di usare provider AI esterni per generare riepiloghi clinici prudenti e altri contenuti di supporto organizzativo.

Se l'utente non attiva il consenso AI separato, ClinDiary usa il motore locale rule-based e non invia recap a provider esterni.

## 2. Titolare del trattamento

- Titolare: **[da compilare]**
- Contatti privacy: **[da compilare]**
- Eventuale DPO/consulente privacy: **[da compilare]**

## 3. Dati trattati

A seconda delle funzioni attivate, ClinDiary puo trattare:

- dati anagrafici e di profilo clinico
- dati relativi a patologie, allergie, farmaci, familiarita e vaccini
- diario giornaliero, sintomi e parametri
- dati wearable/smartwatch importati dall'utente
- documenti clinici caricati o analizzati nell'app
- alert deterministici e recap clinici precedenti, se necessari al contesto

Quando l'AI esterna e disattivata, questi dati restano trattati localmente dal sistema per produrre il recap rule-based.

## 4. Finalita

I dati vengono trattati per:

- fornire la cartella clinica personale dell'utente
- generare recap prudenti giornalieri, settimanali, mensili o pre-visita
- mostrare trend, pattern e elementi di attenzione
- offrire export, backup e scheda emergenza
- migliorare l'usabilita e la continuita del dato clinico, se l'utente attiva le funzioni correlate

## 5. Base giuridica

Da completare nella versione ufficiale con il parere legale.

Bozza di lavoro:

- art. 6 GDPR: **[da definire con il legale]**
- art. 9 GDPR per i dati relativi alla salute: **[da definire con il legale]**
- consenso esplicito separato per l'uso di provider AI esterni quando applicabile

## 6. Consenso AI separato

ClinDiary prevede un consenso AI separato e revocabile.

Quando il consenso e attivo:

- i recap possono usare provider esterni come Gemini o provider OpenAI-compatible via API
- il sistema invia solo il contesto necessario alla generazione del recap
- il recap resta comunque uno strumento di supporto e non una diagnosi

Quando il consenso e disattivato:

- ClinDiary usa il motore locale rule-based
- nessun recap viene inviato a provider esterni

Il consenso puo essere modificato in ogni momento dall'utente nella schermata **Privacy AI**.

## 7. Destinatari e ruoli

In caso di AI esterna, i provider usati da ClinDiary possono agire come responsabili o sub-responsabili del trattamento, secondo la struttura contrattuale effettiva.

Da completare con:

- nome del/i provider
- ruolo privacy esatto
- documentazione contrattuale
- eventuali sub-responsabili

## 8. Trasferimenti extra SEE

Se il provider AI o parte della sua infrastruttura si trova fuori dallo SEE, il trasferimento puo richiedere garanzie adeguate ai sensi del GDPR.

Da completare con:

- valutazione del trasferimento
- verifica delle misure tecniche e organizzative
- eventuali Standard Contractual Clauses o strumenti equivalenti

## 9. Conservazione

Bozza:

- i recap clinici possono essere conservati nella cartella dell'utente finche utili al servizio
- i log tecnici devono essere minimizzati e non devono contenere prompt raw o dati sanitari in chiaro
- i dati esportati o archiviati seguono le politiche definite dal titolare

Da definire nella versione finale:

- tempi esatti di conservazione
- regole di cancellazione
- politiche di backup e retention

## 10. Sicurezza

ClinDiary dovrebbe adottare misure tecniche e organizzative adeguate, tra cui:

- cifratura dei dati a riposo e in transito
- autenticazione sicura
- controllo accessi
- audit trail
- minimizzazione del payload verso provider esterni
- backup e procedure di ripristino

## 11. Diritti dell'interessato

L'utente dovrebbe poter esercitare i diritti previsti dal GDPR, nei limiti applicabili, tra cui:

- accesso
- rettifica
- cancellazione
- limitazione
- portabilita
- opposizione, quando applicabile
- revoca del consenso AI separato

La schermata **Privacy AI** e il dossier aiutano gia a gestire parte di questi flussi, ma il testo ufficiale va allineato alla procedura del titolare.

## 12. Informazioni importanti per l'utente

- ClinDiary non sostituisce il medico.
- I recap AI sono supporto organizzativo e clinico prudente, non diagnosi, triage o prescrizione.
- Se l'utente condivide la scheda emergenza o il dossier, deve essere consapevole dei dati che sta rendendo disponibili.
- La revoca del consenso AI non elimina automaticamente i recap gia salvati, salvo regole di cancellazione o rettifica definite dal titolare.

## 13. Testo breve per la UI

Testo breve da mostrare vicino al toggle AI:

> Se attivi questa opzione, alcuni recap possono essere generati usando un provider AI esterno. I dati inviati sono limitati al contesto necessario. Puoi revocare il consenso in qualunque momento. Se la disattivi, ClinDiary usa il motore locale rule-based.

## 14. Lista di cose da far validare dal legale

- base giuridica precisa per trattamento e AI
- testo finale dell'informativa
- clausole per responsabile del trattamento
- eventuali trasferimenti extra SEE
- tempi di conservazione
- testo sul consenso AI separato
- processo di revoca e cancellazione
- eventuale DPIA

## 15. Stato del repo

Nel codice ClinDiary sono gia presenti:

- toggle AI separato e revocabile
- enforcement backend sul consenso AI
- fallback locale rule-based
- schermata Privacy AI con export dati
- documentazione di roadmap aggiornata

Questa bozza serve a non perdere il lavoro di coordinamento tra prodotto, privacy e legale.

