# Registrazione: genesi del libro

Lo scopo è poter ricostruire **ogni passaggio** che ha portato al libro: chi ha deciso cosa, quando, con quali alternative e su quali fonti. Queste regole sono obbligatorie.

## File del libro (`libri/<slug>/`)

| File | Contenuto | Regola |
|---|---|---|
| `stato.md` | fase corrente, contatori degli ID, prossimo passo | aggiornato a ogni sessione |
| `registro.md` | **tutte** le domande e le risposte, in ordine | **solo in aggiunta**: non si modifica né si cancella il passato |
| `contributi-agente.md` | tutto ciò che l'agente ha generato senza indicazioni | in aggiunta; cambia solo il campo «Stato» |
| `canone.md` | fatti stabiliti (nomi, date, regole del mondo, relazioni) | ogni voce cita l'ID che l'ha stabilita |
| `bibliografia.md` | fonti dei fatti reali e delle citazioni | in aggiunta |
| `idea.md` | idea, varianti, verifica di originalità | fase 0 |
| `struttura.md` | struttura del libro e della collana | fase 1 |
| `personaggi.md` | schede dei personaggi | fase 2 |
| `luoghi.md` | luoghi e ambientazioni | fase 3 |
| `trama.md` | trama, episodi, aneddoti, eventi, scaletta | fase 4 |
| `stile.md` | narratore, registro, ritmo, regole di stile | fase 5 |
| `testo/NN-titolo.md` | capitoli | fase 6 |

## Identificativi

- `D-0001`: domanda dell'agente, con la relativa risposta;
- `S-0001`: sviluppo di testo scritto su indicazione dell'autore;
- `A-0001`: contributo autonomo dell'agente, senza indicazioni;
- `B-001`: fonte bibliografica.

I contatori sono in `stato.md`: non riutilizzare mai un ID.

## Formato di una voce in `registro.md`

```markdown
### D-0012 · Fase 2 – Personaggi · 2026-10-11 14:32

**Domanda:** Che cosa teme di più Livia, al di là della paura di perdere il faro?

**Opzioni proposte (generate dall'agente):**
- A) …
- B) …
- C) …
- D) …
- E) Rispondo a modo mio
- F) Decidi tu

**Risposta dell'autore (testuale):**
> B, ma invece della sorella deve essere il padre.

**Origine della scelta:** opzione B modificata dall'autore
<!-- valori possibili: risposta libera dell'autore | opzione X scelta dall'autore | opzione X modificata dall'autore | delegata all'agente → A-xxxx -->

**Analisi:**
- Congruità: …
- Coerenza: nessun conflitto / conflitto con D-0007 (…) → risolto così: …
- Originalità: …
- Fonti: B-004 (se pertinente)

**Decisioni registrate:** personaggi.md › Livia › Paure; canone.md › C-019

**Sviluppo del testo:** proposto · informazioni richieste: D-0013, D-0014 · esito: accettato → S-0005 (testo/03-la-tempesta.md)
```

Note:
- La risposta dell'autore va riportata **alla lettera**, senza correzioni.
- Se l'autore cambia idea su una decisione passata, **non modificare** la vecchia voce: aggiungi una nuova voce che dice «Revoca/modifica di D-xxxx», e aggiorna canone e file tematici.
- Le domande poste per raccogliere le informazioni necessarie allo sviluppo sono voci `D-` a tutti gli effetti.

## Formato di una voce in `contributi-agente.md`

```markdown
### A-0007 · 2026-10-11 15:02 · Fase 4 – Trama
**Motivo:** l'autore ha risposto «decidi tu» a D-0031 / proposta spontanea dell'agente / dettaglio necessario non indicato
**Contenuto:** (testo integrale oppure sintesi con rimando al file e ai marcatori)
**Dove:** trama.md › Episodio 6; testo/06-il-mercato.md (marcatori A-0007)
**Stato:** proposto | accettato | accettato con modifiche (D-0035) | rifiutato (D-0036)
```

Sono contributi autonomi anche i dettagli secondari inventati dall'agente durante uno sviluppo (un nome, un oggetto, una battuta non richiesti). Raggruppali in un'unica voce `A-` per sviluppo ed elencali.

## Formato di una voce in `sviluppi` (dentro `registro.md`)

Quando l'agente scrive testo con il permesso dell'autore, aggiungi dopo la voce `D-` collegata:

```markdown
#### S-0005 · sviluppo di D-0012, D-0013, D-0014 · 2026-10-11 15:10
**File:** testo/03-la-tempesta.md (marcatori S-0005)
**Lunghezza:** ~900 parole
**Contributi autonomi inclusi:** A-0008
**Esito:** accettato | da rivedere | rifiutato
```

## Formato di `canone.md`

```markdown
| ID | Fatto stabilito | Stabilito da | Stato |
|---|---|---|---|
| C-019 | Livia teme di diventare come il padre | D-0012 | valido |
| C-020 | Il faro è stato spento nel 1971 | D-0015, B-004 | DA VERIFICARE |
```

## Formato di `bibliografia.md`

```markdown
### B-004
- **Fonte:** «Faro di …», Wikipedia, voce in italiano
- **URL:** https://it.wikipedia.org/wiki/…
- **Consultata il:** 2026-10-11
- **Supporta:** data di spegnimento del faro (C-020)
- **Richiesta da:** D-0015
- **Note:** confermata anche da … (B-005)
```

## Comando «genesi»

Leggi `registro.md`, `contributi-agente.md` e (se presente) la cronologia git, e scrivi un racconto cronologico in prosa: com'è nata l'idea, quali varianti sono state scartate e perché, le svolte principali, quanta parte del testo è `AUTORE`, `SVILUPPO` o `AGENTE`. Indica sempre gli ID, così che ogni affermazione sia verificabile.
