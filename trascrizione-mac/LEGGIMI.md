# Trascrivi Audio (Mac, offline)

> **Per installarlo:** scarica [`dist/Installa-TrascriviAudio.zip`](dist/Installa-TrascriviAudio.zip)
> e segui la [Guida rapida](GUIDA-RAPIDA.md); dentro l'installatore la trovi anche in PDF.
> L'installatore chiede la cartella, installa Python e Whisper se mancano, mette sulla Scrivania
> il collegamento «Trascrivi Audio» e lo avvia. Per aggiornare, rilancialo scegliendo la stessa cartella.
>
> Per rigenerare lo ZIP e «Guida rapida.pdf» dopo aver modificato i file: `./crea-installatore.sh`
> (servono pandoc e Chrome o Chromium per il PDF; senza, usa il PDF già presente).

L'audio non lascia mai il computer. Da internet si scaricano solo Python (se manca, da python.org),
Whisper (al primo avvio, circa 300 MB) e i modelli (alla prima trascrizione, circa 4,5 GB).

## Come funziona

Si usa un solo comando, **`Trascrivi-Audio.command`** (collegamento «Trascrivi Audio» sulla Scrivania):

1. **Python e Whisper:** li controlla e, se mancano, chiede se installarli (popup con Annulla).
2. **Progetto:** chiede «Apri un progetto» oppure «Nuovo progetto».
   - **Nuovo:** nome → numero 000-999 → cartella `Progetti/NNN_NomeSenzaSpazi` → audio sorgente,
     copiato nel progetto → trascrizione.
   - **Apri:** lista dei progetti (solo nomi) → **Avanti** → «Analisi delle parole» (schermata
     di controllo) oppure «Rielabora la trascrizione» (con conferma).
3. **Trascrizione:**
   - 1° e 2° ascolto con **large-v3** e **medium** sull'intero audio;
   - 3° ascolto: large-v3 riascolta solo le frasi dubbie e, se coincide con medium, il dubbio è risolto;
   - 4° ascolto: dove ancora non coincidono, medium riascolta e conferma oppure no.

   Le parole già corrette o confermate in passato (dizionario personale) non vengono segnate.
4. **Ritagli:** ±3 secondi di audio per ogni parola rimasta dubbia.
5. **Schermata di controllo** nel browser, servita solo in locale.

Ogni comando e la schermata lavorano **solo sui file del progetto in corso**.

## File dei progetti

Nella cartella `Progetti`, dentro la cartella del programma (variabile `CARTELLA_PROGETTI`):

| File | Contenuto |
|---|---|
| `elenco-progetti.json` | **file generale**: per ogni progetto `numero`, `nome`, `cartella`, `stato` (nuovo / in trascrizione / trascritto), `audio_originale` e la lista `file` (audio, trascrizione, trascrizione_corretta, controllo, dati, clip) |
| `progetto-in-corso.json` | **temporaneo**: il progetto su cui si lavora. Scritto quando si apre o si crea un progetto, cancellato all'uscita del comando |
| `NNN_Nome/` | la cartella del progetto, con tutti i suoi file (`NNN_Nome_audio.ext`, `_trascrizione.txt`, `_trascrizione_corretta.txt`, `_controllo.txt`, `_dati.json`, `_clip/`) |

## File del programma

| File | Ruolo |
|---|---|
| `Trascrivi-Audio.command` | comando principale: installazione di Python e Whisper, progetti, trascrizione; con `--installa` fa solo l'installazione (usato dall'installatore) |
| `Controlla-Parole.command` | apre la schermata di controllo: con `--progetto-in-corso` usa il progetto in corso, altrimenti chiede il progetto |
| `Applica-Correzioni.command` | per chi corregge a mano il file di controllo: chiede il progetto e applica le correzioni |
| `comune.sh` | funzioni condivise dai comandi: finestre di dialogo, scelta del progetto |
| `progetti.py` | gestione dei progetti: file generale, file temporaneo, cartelle |
| `schermata_controllo.py` | schermata di controllo: server su 127.0.0.1 con token, 10 parole per pagina, **Salva** e **Annulla** |
| `applica_correzioni.py` | applica le correzioni: trascrizione corretta, dizionario, esempi |

## Dati comuni a tutti i progetti

In `~/Library/Application Support/TrascriviAudio`:

- `venv/` e `modelli/`: Whisper e i modelli;
- `dizionario.txt`: dizionario personale, con le righe `sbagliata → giusta` e `parola → parola` (confermata);
- `esempi/`: ritagli corretti, con il testo giusto.

## Impostazioni (facoltative, da Terminale)

| Variabile | Predefinito | Significato |
|---|---|---|
| `MODELLO_A` | `large-v3` | modello principale |
| `MODELLO_B` | `medium` | modello di confronto |
| `MODELLO_C` | `medium` | modello del 4° ascolto |
| `RIASCOLTO` | `1` | `0` = non riascoltare le frasi dubbie |
| `SOGLIA` | `0.6` | sotto questo valore la parola è dubbia |
| `LINGUA` | `it` | lingua dell'audio (vuoto = rilevamento automatico) |
| `CARTELLA_PROGETTI` | `<programma>/Progetti` | dove stanno i progetti |

## Prove automatiche (Linux o Mac, senza clic)

`test/finto-mac.sh` simula le finestre del Mac: le risposte dell'utente vengono lette da una coda.

| Prova | Cosa verifica |
|---|---|
| `test/prova-progetti.sh file_audio` | 9 scenari: prima esecuzione senza progetti; nuovo progetto con nome duplicato e poi con caratteri speciali; apertura → analisi; Applica-Correzioni su un solo progetto; rielaborazione (confermata e annullata); Annulla nei vari punti; Controlla-Parole da solo; progetto senza audio ripreso |
| `test/prova-installatore.sh` | installazione, collegamenti, avvio automatico, aggiornamento |
| `test/prova-schermata.js` | la schermata in un vero browser (Playwright): token, paginazione, audio con Range, conferma e blocco, Annulla, Salva e ricaricamento |
