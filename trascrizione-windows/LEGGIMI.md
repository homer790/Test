# Trascrivi Audio (Windows 11, offline)

> **Per installarlo:** scarica [`dist/TrascriviAudio-Windows.zip`](dist/TrascriviAudio-Windows.zip)
> e segui la [Guida](guida/GUIDA-RAPIDA.md) (dentro lo ZIP c'è anche in PDF, con le immagini).
> Tasto destro sullo ZIP → **Estrai tutto…** → nella cartella «Trascrivi Audio» doppio clic su
> **Installa Trascrivi Audio**: si installa per il tuo utente (senza richieste di amministratore),
> installa da solo Python, Whisper e i modelli, mette l'icona sulla Scrivania e nel menu Start e
> apre il menu principale. Per aggiornare si fa lo stesso con lo ZIP nuovo.

L'audio non lascia mai il computer. Da internet si scaricano solo Python, Whisper (circa 300 MB) e
i modelli (circa 4,5 GB), una volta sola. Durante la trascrizione il programma non si collega a
internet (`HF_HUB_OFFLINE=1`) e non invia statistiche (`HF_HUB_DISABLE_TELEMETRY=1`).

## Come funziona

1. **Estrai tutto:** con il doppio clic Windows apre lo ZIP come una cartella ma non lo estrae, e
   da lì i programmi non partono. Estratto, si ottiene la cartella `Trascrivi Audio` con
   `Installa Trascrivi Audio.cmd`, `Guida rapida.pdf` e `programma\`.
2. **Doppio clic su «Installa Trascrivi Audio»:** il file non è firmato, quindi Windows può
   mostrare «Windows ha protetto il PC» (→ **Ulteriori informazioni** → **Esegui comunque**) oppure
   «Avviso di sicurezza» (→ **Esegui**). La guida mostra i passi con le immagini. Il `.cmd` esegue
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File programma\TrascriviAudio.ps1 -Installa`:
   `Bypass` vale solo per questo avvio, le impostazioni di Windows non cambiano.
3. **Installazione** (`-Installa`):
   - copia il programma in `%LOCALAPPDATA%\Programs\Trascrivi Audio`, sostituendo un'eventuale
     versione precedente;
   - toglie il blocco «scaricato da internet» (`Unblock-File`);
   - avvia la copia installata. La finestra di PowerShell mostra l'avanzamento.
4. **Il programma** (`TrascriviAudio.ps1`, per Windows PowerShell 5.1 incluso in Windows):
   - prepara tutto **senza domande**, solo se manca qualcosa:
     - **Python portatile** 3.12.15 (python-build-standalone 20261013, x86_64), privato del
       programma: scaricato con `curl.exe`, verificato con SHA-256 ed estratto con `tar.exe`
       (inclusi in Windows 11). Non tocca altri Python né il `PATH`;
     - **Whisper** (`faster-whisper`, `av<19`) e **msvc-runtime**: le librerie Visual C++
       (MSVCP140) che servono a Whisper, copiate accanto al `python.exe` privato, quindi senza
       installarle in Windows e senza conferme da amministratore;
     - i **modelli** large-v3 e medium (`modelli.py`);
   - alla prima installazione o dopo un aggiornamento:
     - crea i collegamenti `Trascrivi Audio.lnk` sulla Scrivania e nel menu Start, con l'icona;
     - aggiunge la voce in Impostazioni → App → **App installate** (chiave `HKCU`, da cui si
       disinstalla con `-Disinstalla`);
     - copia la guida in `Documenti\Trascrivi Audio`, accanto alla cartella dei progetti;
   - mostra il **menu principale** (si torna lì dopo ogni operazione):
     - **Nuovo progetto:** nome → `Documenti\Trascrivi Audio\Progetti\NNN_Nome` → audio,
       copiato nel progetto → trascrizione → schermata di controllo;
     - **Apri un progetto:** lista → **Analisi delle parole** oppure **Rielabora la trascrizione**;
     - **Guida rapida**;
     - **Disinstalla Trascrivi Audio:** chiede conferma e se conservare i progetti;
     - **Esci**.
5. **Finestre:** sono finestre Windows Forms (`Finestre.cs`, compilato da PowerShell all'avvio con
   `Add-Type`): pulsanti di opzione fino a 10 voci, elenco con barra di scorrimento oltre, campo di
   testo, scelta del file audio a partire da Download.
6. **Trascrizione e schermata di controllo:** come sul Mac, con gli stessi file Python
   (4 ascolti, ritagli di ±3 s, dizionario personale; schermata nel browser predefinito, servita
   solo su `127.0.0.1` con un token).

**OneDrive:** su Windows 11 la cartella Documenti è spesso sincronizzata con OneDrive. In quel
caso i progetti vanno in `%USERPROFILE%\Trascrivi Audio`, che OneDrive non sincronizza, così
l'audio non finisce online. La cartella scelta alla prima installazione viene salvata in
`cartella-progetti.txt` e resta quella anche negli aggiornamenti.

## Struttura del repository

| Percorso | Contenuto |
|---|---|
| `avvio/Installa Trascrivi Audio.cmd` | il file da aprire con un doppio clic (righe con CRLF) |
| `programma/TrascriviAudio.ps1` | il programma: installazione, preparazione, menu, progetti, trascrizione, disinstallazione. Va salvato in UTF-8 **con BOM**, altrimenti Windows PowerShell 5.1 legge male le lettere accentate |
| `programma/Finestre.cs` | le finestre di dialogo (C# 5, solo caratteri ASCII) |
| `programma/TrascriviAudio.ico` | icona (16–256 px, dalla stessa immagine dell'icona del Mac) |
| `../trascrizione-comune/*.py` | in comune con il Mac: progetti, trascrizione, schermata di controllo, correzioni, modelli |
| `guida/GUIDA-RAPIDA.md` | la guida (diventa `Guida rapida (Windows).pdf`) |
| `guida/illustrazioni.html` | le illustrazioni delle finestre di Windows 11 |
| `guida/crea-immagini.sh` + `.js` | crea `guida/immagini/*.png` (le due immagini della schermata di controllo vengono dalla guida del Mac) |
| `crea-pacchetto.sh` | crea `Guida rapida (Windows).pdf` e `dist/TrascriviAudio-Windows.zip` |
| `test/` | prove automatiche (vedi sotto) |

**Per creare lo ZIP:**

1. `guida/crea-immagini.sh`, solo se sono cambiate guida o illustrazioni (servono Node con
   Playwright, Chromium e Python con Pillow);
2. `./crea-pacchetto.sh` (servono pandoc e Chrome o Chromium per il PDF; senza, usa il PDF già
   presente).

## Dove stanno i dati su Windows

| Percorso | Contenuto |
|---|---|
| `%LOCALAPPDATA%\Programs\Trascrivi Audio` | il programma |
| Scrivania e menu Start | `Trascrivi Audio.lnk` |
| `Documenti\Trascrivi Audio\Progetti` (con OneDrive: `%USERPROFILE%\Trascrivi Audio\Progetti`) | `elenco-progetti.json`, `progetto-in-corso.json` (temporaneo) e una cartella per progetto: `NNN_Nome_audio.ext`, `_trascrizione.txt`, `_trascrizione_corretta.txt`, `_controllo.txt`, `_dati.json`, `_clip\` |
| `Documenti\Trascrivi Audio\Guida rapida.pdf` | copia della guida |
| `%LOCALAPPDATA%\TrascriviAudio` | `python\` (portatile, con Whisper), `modelli\`, `dizionario.txt`, `esempi\`, `cartella-progetti.txt` |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\TrascriviAudio` | voce in «App installate» |

## Impostazioni (facoltative, variabili d'ambiente)

| Variabile | Predefinito | Significato |
|---|---|---|
| `MODELLO_A` | `large-v3` | modello principale |
| `MODELLO_B` | `medium` | modello di confronto |
| `MODELLO_C` | `medium` | modello del 4° ascolto |
| `RIASCOLTO` | `1` | `0` = non riascoltare le frasi dubbie |
| `SOGLIA` | `0.6` | sotto questo valore la parola è dubbia |
| `LINGUA` | `it` | lingua dell'audio (vuoto = rilevamento automatico) |
| `CARTELLA_DOCUMENTI` | vedi sopra | dove stanno progetti e guida |

## Prove automatiche (su Linux, senza Windows)

| Prova | Cosa verifica |
|---|---|
| `test/prova-windows.sh file_audio` | con PowerShell 7 (`pwsh`) e le finestre simulate (`TRASCRIVI_FINTO=1`): controlli sul pacchetto (CRLF, BOM, ASCII), poi 8 scenari dallo ZIP alla disinstallazione su un «PC» senza Python: installazione senza domande (Python portatile, Whisper, modelli, collegamenti, voce in App installate), nuovo progetto con trascrizione vera, avvio dall'icona, analisi e rielaborazione, guida, nome vuoto o duplicato e Annulla, aggiornamento, disinstallazione dal menu e da App installate conservando o cancellando i progetti, Documenti su OneDrive, Python scaricato corrotto |
| `test/prova-finestre.sh` | compila `Finestre.cs` come Windows PowerShell 5.1 (C# 5) e prova ogni tipo di finestra con Mono su uno schermo virtuale, simulando i clic |
| `../trascrizione-mac/test/prova-schermata.js` | la schermata di controllo in un vero browser (è la stessa del Mac) |

Lo script è stato controllato anche con PSScriptAnalyzer contro le regole di compatibilità di
Windows PowerShell 5.1.

## Da verificare su un PC Windows vero

Le prove girano su Linux con PowerShell 7 e le finestre simulate. Su Windows 11 vanno verificati:

- gli avvisi di SmartScreen e dell'antivirus;
- il caricamento delle librerie di msvc-runtime da parte di Whisper;
- l'aspetto delle finestre con Windows PowerShell 5.1;
- collegamenti, voce in «App installate» e disinstallazione.
