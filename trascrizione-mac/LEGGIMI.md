# Trascrivi Audio (Mac, offline)

> **Per installarlo:** scarica [`dist/TrascriviAudio.zip`](dist/TrascriviAudio.zip) e segui la
> [Guida](guida/GUIDA-RAPIDA.md) (dentro lo ZIP c'è anche in PDF, con le immagini).
> Doppio clic sullo ZIP → cartella «Trascrivi Audio» → doppio clic sull'app: si copia in
> Applicazioni, installa da sola Python (se manca), Whisper e i modelli, mette l'icona sulla
> Scrivania e apre il menu principale. Per aggiornare si fa lo stesso con lo ZIP nuovo.

L'audio non lascia mai il computer. Da internet si scaricano solo Python (se manca), Whisper
(circa 300 MB) e i modelli (circa 4,5 GB), una volta sola. Durante la trascrizione il programma
non si collega a internet (`HF_HUB_OFFLINE=1`) e non invia statistiche (`HF_HUB_DISABLE_TELEMETRY=1`).

## Come funziona

1. **Doppio clic sullo ZIP:** il Mac estrae la cartella `Trascrivi Audio` con `Trascrivi Audio.app`
   e `Guida rapida.pdf`. Nessun archivio può avviare programmi da solo, quindi serve il passo 2.
2. **Doppio clic sull'app:** la prima volta macOS la blocca, perché non è firmata da Apple. La si
   sblocca in Impostazioni di Sistema → Privacy e sicurezza → **Apri comunque**: da macOS 15 il
   «clic destro → Apri» non basta più. La guida mostra i passi con le immagini.
3. **Il lanciatore** (`Contents/MacOS/TrascriviAudio`):
   - se l'app non è in `/Applications`, vi si copia (`ditto --noqtn`), sostituendo un'eventuale
     versione precedente (non se è identica, es. doppio clic ripetuto). Se Applicazioni non è
     scrivibile, macOS chiede la password;
   - toglie sempre il blocco «scaricato da internet» dalla copia in Applicazioni (anche se l'app
     ci è stata trascinata a mano), così macOS non chiede una seconda conferma per il programma;
   - poi apre nel **Terminale** il programma della copia in Applicazioni. La finestra del Terminale
     mostra l'avanzamento.
4. **Il programma** (`Contents/Resources/programma/Trascrivi-Audio.command`):
   - si apre **una volta sola**: se è già aperto in un'altra finestra del Terminale (blocco
     `in-uso` in `Application Support`, con il numero del processo) la seconda finestra si chiude;
   - prepara tutto **senza domande**, solo se manca qualcosa:
     - **Python:** quello del Mac, se è tra la 3.10 e la 3.13 (per le versioni più nuove alcuni
       componenti di Whisper non sono ancora disponibili) ed è nativo per il processore del Mac
       (un Python per Intel copiato su un Mac con chip Apple richiederebbe Rosetta), oppure il
       **Python portatile** 3.12.15
       (python-build-standalone 20261013), scaricato in `Application Support` senza password e
       verificato con SHA-256. Se con il Python del Mac l'installazione di Whisper non riesce, il
       programma passa da solo al Python portatile;
     - **Whisper** in un ambiente virtuale;
     - i **modelli** large-v3 e medium;
   - alla prima installazione o dopo un aggiornamento:
     - crea l'icona sulla Scrivania (collegamento all'app);
     - toglie i file delle versioni precedenti e ne sposta i progetti in Documenti;
   - mostra il **menu principale** (si torna lì dopo ogni operazione):
     - **Nuovo progetto:** nome → `Documenti/Trascrivi Audio/Progetti/NNN_Nome` → audio,
       controllato (un file rovinato o senza audio viene rifiutato) e copiato nel progetto →
       trascrizione → schermata di controllo;
     - **Apri un progetto:** lista → **Analisi delle parole** oppure **Rielabora la trascrizione**
       (se la cartella del progetto è stata cancellata si può **togliere dall'elenco**);
     - **Guida rapida**;
     - **Disinstalla Trascrivi Audio:** chiede conferma e se conservare i progetti;
     - **Esci**.
5. **Trascrizione:**
   - 1° e 2° ascolto con large-v3 e medium sull'intero audio;
   - 3° ascolto: large-v3 riascolta le sole frasi dubbie; se coincide con medium, il dubbio è risolto;
   - 4° ascolto: dove ancora non coincidono, medium riascolta e conferma oppure no;
   - ritagli di ±3 s per le parole rimaste dubbie.
6. **Schermata di controllo** nel browser, servita solo su `127.0.0.1` con un token:
   - 10 parole per pagina, ognuna con audio, campo e casella «Confermata»;
   - **Salva** applica le correzioni e le impara nel dizionario personale;
   - **Annulla** scarta le modifiche;
   - **Chiudi** torna al menu.

## Struttura del repository

| Percorso | Contenuto |
|---|---|
| `app/TrascriviAudio` | lanciatore dell'app (diventa `Contents/MacOS/TrascriviAudio`) |
| `app/Info.plist` | dati dell'app (`@VERSIONE@` viene sostituito alla creazione; `LSArchitecturePriority` arm64) |
| `app/nativo.c`, `app/TrascriviAudio-nativo` | programma vuoto per chip Apple e Intel, messo in `Contents/MacOS`: con un lanciatore che è uno script, macOS potrebbe considerare l'app «per Intel» e chiedere di installare Rosetta. Creato con Zig 0.14.1: `zig cc -target aarch64-macos.11.0 -Os` e `-target x86_64-macos.11.0`, poi `llvm-lipo -create` |
| `app/icona.svg`, `app/icona.png`, `app/AppIcon.icns` | icona: disegno, immagine 1024×1024 (`node app/crea-icona.js`), formato Mac |
| `programma/Trascrivi-Audio.command` | il programma: preparazione, menu, progetti, trascrizione, disinstallazione |
| `programma/comune.sh` | finestre di dialogo, menu, scelta del progetto, percorsi |
| `../trascrizione-comune/progetti.py` | progetti: `elenco-progetti.json` (file generale), `progetto-in-corso.json` (temporaneo), cartelle, spostamento dalle versioni precedenti |
| `../trascrizione-comune/trascrivi_dubbi.py` | trascrizione con i 4 ascolti, segni, ritagli, dizionario |
| `../trascrizione-comune/schermata_controllo.py` | schermata di controllo (server locale + pagina) |
| `../trascrizione-comune/applica_correzioni.py` | applica le correzioni: trascrizione corretta, dizionario, esempi |
| `guida/GUIDA-RAPIDA.md` | la guida (diventa `Guida rapida.pdf`) |
| `guida/illustrazioni.html` | le illustrazioni delle finestre di macOS (stile Sequoia) |
| `guida/crea-immagini.sh` + `.js` | crea `guida/immagini/*.png`: illustrazioni e immagini reali della schermata di controllo su un progetto dimostrativo |
| `crea-installatore.sh` | crea `Guida rapida.pdf` e `dist/TrascriviAudio.zip` |
| `test/` | prove automatiche (vedi sotto) |

I file Python sono nella cartella `trascrizione-comune`, in comune con la versione per Windows
(`../trascrizione-windows`): `crea-installatore.sh` li copia dentro l'app.

**Per creare lo ZIP:**

1. `guida/crea-immagini.sh`, solo se sono cambiate guida o illustrazioni (servono Node con
   Playwright, Chromium e Python con Pillow);
2. `./crea-installatore.sh` (servono pandoc e Chrome o Chromium per il PDF; senza, usa il PDF
   già presente).

## Dove stanno i dati sul Mac

| Percorso | Contenuto |
|---|---|
| `/Applications/Trascrivi Audio.app` | l'app |
| `~/Desktop/Trascrivi Audio` | icona sulla Scrivania (collegamento all'app) |
| `~/Documents/Trascrivi Audio/Progetti` | `elenco-progetti.json`, `progetto-in-corso.json` (temporaneo) e una cartella per progetto: `NNN_Nome_audio.ext`, `_trascrizione.txt`, `_trascrizione_corretta.txt`, `_controllo.txt`, `_dati.json`, `_clip/` |
| `~/Documents/Trascrivi Audio/Guida rapida.pdf` | copia della guida |
| `~/Library/Application Support/TrascriviAudio` | `python/` (portatile), `venv/` (Whisper), `modelli/`, `dizionario.txt`, `esempi/` |

## Impostazioni (facoltative, da Terminale)

| Variabile | Predefinito | Significato |
|---|---|---|
| `MODELLO_A` | `large-v3` | modello principale |
| `MODELLO_B` | `medium` | modello di confronto |
| `MODELLO_C` | `medium` | modello del 4° ascolto |
| `RIASCOLTO` | `1` | `0` = non riascoltare le frasi dubbie |
| `SOGLIA` | `0.6` | sotto questo valore la parola è dubbia |
| `LINGUA` | `it` | lingua dell'audio (vuoto = rilevamento automatico) |
| `CARTELLA_DOCUMENTI` | `~/Documents/Trascrivi Audio` | dove stanno progetti e guida |

## Prove automatiche (Linux o Mac, senza clic)

`test/finto-mac.sh` simula i comandi del Mac (`osascript` con una coda di risposte, `open`, `ditto`,
`xattr`).

| Prova | Cosa verifica |
|---|---|
| `test/prova-app.sh file_audio` | 11 scenari, dallo ZIP alla disinstallazione, su un «Mac» senza Python adatto e con una versione precedente installata: installazione senza domande (Python del Mac troppo nuovo ignorato, Python portatile, Whisper, modelli, icona, pulizia e spostamento dei vecchi progetti), nuovo progetto, avvio dall'icona, analisi e rielaborazione, guida, nome duplicato e Annulla, audio rovinato o senza audio, cartella di un progetto cancellata, programma già aperto in un'altra finestra, aggiornamento, disinstallazione conservando o cancellando i progetti, Python del Mac che non installa Whisper, Python scaricato corrotto |
| `test/prova-schermata.js` | la schermata di controllo in un vero browser (Playwright): token, paginazione, audio con Range (Safari), conferma e blocco, Annulla, Salva e ricaricamento |

## Da verificare su un Mac vero

Le prove girano su Linux con le finestre simulate. Su un Mac vanno verificati:

- lo sblocco di Gatekeeper;
- su un Mac con chip Apple senza Rosetta: che non compaia la richiesta di installare Rosetta;
- le richieste di permesso per Documenti, Scrivania e Download;
- il download del Python portatile da GitHub;
- l'aggiornamento e la disinstallazione dell'app in Applicazioni.
