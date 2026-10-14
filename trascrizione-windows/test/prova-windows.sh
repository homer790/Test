#!/bin/bash
# Prova completa della versione Windows, dallo ZIP alla disinstallazione, su Linux con PowerShell 7
# (pwsh) e le finestre simulate (TRASCRIVI_FINTO=1: risposte lette da una coda, finestre registrate).
# uso: test/prova-windows.sh file_audio     (prima crea lo ZIP con ./crea-pacchetto.sh)
#
# Simula un PC con Windows 11 senza Python (il Python «portatile» è un file locale al posto di
# quello di GitHub), con le cartelle dell'utente in una cartella temporanea. Collegamenti e voce
# in «App installate» sono simulati con file. Usa modelli piccoli (base, tiny).
# Alla fine stampa «TUTTE LE VERIFICHE SUPERATE» o le verifiche fallite.

set -u
QUI=$(cd "$(dirname "$0")/.." && pwd)
AUDIO=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
ZIP="$QUI/dist/TrascriviAudio-Windows.zip"
[ -f "$ZIP" ] || { echo "Manca $ZIP: esegui prima ./crea-pacchetto.sh"; exit 1; }
command -v pwsh >/dev/null || { echo "Serve PowerShell (pwsh)"; exit 1; }
PROVA=$(mktemp -d)
FALLITE=0

prepara_utente() {  # prepara_utente CARTELLA: cartelle di un utente Windows simulato
  export USERPROFILE="$1" LOCALAPPDATA="$1/AppData/Local"
  export TRASCRIVI_DOCUMENTI="$1/Documents" TRASCRIVI_SCRIVANIA="$1/Desktop"
  export TRASCRIVI_START="$1/AppData/Roaming/Microsoft/Windows/Start Menu/Programs"
  export TRASCRIVI_REGISTRO="$1/registro-app-installate.json"
  mkdir -p "$USERPROFILE/Downloads" "$TRASCRIVI_DOCUMENTI" "$TRASCRIVI_SCRIVANIA" "$TRASCRIVI_START" "$LOCALAPPDATA"
  DEST="$LOCALAPPDATA/Programs/Trascrivi Audio"
  SUPPORTO="$LOCALAPPDATA/TrascriviAudio"
}
export TRASCRIVI_FINTO=1 RISPOSTE="$PROVA/risposte.txt" LOG="$PROVA/finestre.log" SALTA_SCHERMATA=1
export MODELLO_A="${MODELLO_A:-base}" MODELLO_B="${MODELLO_B:-tiny}" MODELLO_C="${MODELLO_C:-tiny}"
export PIP_CACHE_DIR="${PIP_CACHE_DIR:-/tmp/cache-pip-prove}"
: > "$LOG"
risposte() { printf '%s\n' "$@" > "$RISPOSTE"; }

# Python «portatile» finto: un archivio con la cartella python/ (qui un ambiente Python di Linux)
python3 -m venv "$PROVA/py/python"
tar -czf "$PROVA/python.tar.gz" -C "$PROVA/py" python
export PYTHON_PORTATILE_URL="file://$PROVA/python.tar.gz"
export PYTHON_PORTATILE_SHA256=$(shasum -a 256 "$PROVA/python.tar.gz" | cut -d' ' -f1)

esegui() {  # esegui "descrizione" script.ps1 [opzioni]; output in $PROVA/ultimo.log
  echo; echo "################ $1 ################" | tee -a "$LOG"
  shift
  pwsh -NoProfile -NonInteractive -File "$@" > "$PROVA/ultimo.log" 2>&1; ESITO=$?
  echo "esito: $ESITO"
  grep -E "^Progetto:|SCHERMATA|ERRORE|Parole da riverificare|Scarico|Installo|installato\.|Copio Trascrivi|Arrivederci|Disinstall" \
    "$PROVA/ultimo.log" | sed 's/^/   /'
}
verifica() { local d="$1"; shift; if "$@"; then echo "   OK  $d"; else echo "   NO  $d"; FALLITE=$((FALLITE + 1)); fi; }
contiene() { grep -q -- "$2" "$1"; }
non_contiene() { ! grep -q -- "$2" "$1"; }
non_esiste() { [ ! -e "$1" ]; }
log_giro() { sed -n "/################ $1/,\$p" "$LOG"; }
prima_domanda() { log_giro "$1" | grep -m1 -E "^== (finestra|prompt)"; }
json() { python3 -c "import json,sys; d=json.load(open(sys.argv[2], encoding='utf-8-sig')); print(eval(sys.argv[1]))" "$1" "$2"; }

# ---------------------------------------------------------------------------------------------
# 0. Controlli sul pacchetto
mkdir -p "$PROVA/zip" && (cd "$PROVA/zip" && unzip -q "$ZIP")
P0="$PROVA/zip/Trascrivi Audio"
verifica "lo ZIP contiene la cartella «Trascrivi Audio» con avvio, guida e programma" \
  [ -f "$P0/Installa Trascrivi Audio.cmd" -a -f "$P0/Guida rapida.pdf" -a -f "$P0/programma/TrascriviAudio.ps1" ]
verifica "Installa Trascrivi Audio.cmd avvia il programma con -Installa" \
  contiene "$P0/Installa Trascrivi Audio.cmd" 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0programma\\TrascriviAudio.ps1" -Installa'
verifica "il .cmd ha le righe in formato Windows (CRLF)" eval '[ "$(grep -c $'"'"'\r$'"'"' "$P0/Installa Trascrivi Audio.cmd")" -ge 3 ]'
verifica "TrascriviAudio.ps1 con marcatore UTF-8 (BOM) per Windows PowerShell 5.1" \
  eval '[ "$(head -c 3 "$P0/programma/TrascriviAudio.ps1" | od -An -tx1 | tr -d " ")" = "efbbbf" ]'
verifica "Finestre.cs solo con caratteri ASCII" eval '! LC_ALL=C grep -qP "[^\x00-\x7F]" "$P0/programma/Finestre.cs"'

# ---------------------------------------------------------------------------------------------
# 1. «Estrai tutto», poi doppio clic su «Installa Trascrivi Audio» (il .cmd esegue -Installa)
prepara_utente "$PROVA/Mario"
(cd "$USERPROFILE/Downloads" && unzip -q "$ZIP")
ESTRATTA="$USERPROFILE/Downloads/Trascrivi Audio"
PROGETTI="$TRASCRIVI_DOCUMENTI/Trascrivi Audio/Progetti"
risposte "Nuovo progetto" "Intervista Rossi" "$AUDIO" "ANNULLA"
esegui "1. Installazione dalla cartella estratta" "$ESTRATTA/programma/TrascriviAudio.ps1" -Installa
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "programma copiato in AppData\\Local\\Programs\\Trascrivi Audio" [ -f "$DEST/TrascriviAudio.ps1" -a -f "$DEST/Finestre.cs" -a -f "$DEST/Guida rapida.pdf" ]
verifica "Python portatile installato senza chiedere" [ -x "$SUPPORTO/python/bin/python3" ]
verifica "Whisper installato" "$SUPPORTO/python/bin/python3" -c "import faster_whisper"
verifica "modelli scaricati durante l'installazione" contiene "$PROVA/ultimo.log" "Scarico il modello base"
verifica "nessuna domanda prima del menu" eval 'prima_domanda "1. Install" | grep -q "Cosa vuoi fare?"'
verifica "avviso «Installazione completata»" contiene "$LOG" "Installazione completata"
verifica "icona sulla Scrivania" [ -f "$TRASCRIVI_SCRIVANIA/Trascrivi Audio.lnk" ]
verifica "voce nel menu Start" [ -f "$TRASCRIVI_START/Trascrivi Audio.lnk" ]
verifica "voce in «App installate» con la disinstallazione" \
  eval '[ "$(json "d[\"DisplayName\"]" "$TRASCRIVI_REGISTRO")" = "Trascrivi Audio" ] && json "d[\"UninstallString\"]" "$TRASCRIVI_REGISTRO" | grep -q -- "-Disinstalla"'
verifica "guida copiata in Documenti\\Trascrivi Audio" [ -f "$TRASCRIVI_DOCUMENTI/Trascrivi Audio/Guida rapida.pdf" ]
verifica "posizione dei progetti memorizzata" contiene "$SUPPORTO/cartella-progetti.txt" "$TRASCRIVI_DOCUMENTI/Trascrivi Audio"
P1="$PROGETTI/000_IntervistaRossi"
verifica "nuovo progetto 000 in Documenti" [ -f "$P1/000_IntervistaRossi_controllo.txt" -a -f "$P1/000_IntervistaRossi_audio.mp3" ]
verifica "schermata aperta sul nuovo progetto" contiene "$PROVA/ultimo.log" "SCHERMATA (test): $P1/000_IntervistaRossi_controllo.txt"
verifica "ritorno al menu e uscita con «Esci»" contiene "$PROVA/ultimo.log" "Arrivederci"
verifica "file temporaneo cancellato" non_esiste "$PROGETTI/progetto-in-corso.json"
verifica "marcatore di installazione tolto" non_esiste "$SUPPORTO/installazione-da-completare"

# ---------------------------------------------------------------------------------------------
# 2. Avvio dall'icona (programma installato): analisi, poi rielaborazione; nessuna reinstallazione
risposte "Apri un progetto" "Intervista Rossi" "Analisi delle parole" \
         "Apri un progetto" "Intervista Rossi" "Rielabora la trascrizione" "Rielabora" "ANNULLA"
esegui "2. Icona: analisi e rielaborazione" "$DEST/TrascriviAudio.ps1"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "nessuna reinstallazione né avvisi di installazione" \
  eval '! grep -qE "Installo Whisper|Scarico" "$PROVA/ultimo.log" && ! log_giro "2. Icona" | grep -q "Installazione completata"'
verifica "la lista mostra i nomi dei progetti" eval 'log_giro "2. Icona" | grep -q "Scegli il progetto da aprire: | Intervista Rossi | Annulla | Avanti"'
verifica "analisi sul progetto 000" contiene "$PROVA/ultimo.log" "SCHERMATA (test): $P1/000_IntervistaRossi_controllo.txt"
verifica "rielaborazione eseguita" [ "$(grep -c "Parole da riverificare" "$PROVA/ultimo.log")" -ge 1 ]

# ---------------------------------------------------------------------------------------------
# 3. Guida, nome vuoto, nome duplicato, Annulla nei vari punti
risposte "Guida rapida" "Nuovo progetto" "   " "intervista rossi" "ANNULLA" "Apri un progetto" "ANNULLA" "ANNULLA"
esegui "3. Guida, nomi non validi, Annulla" "$DEST/TrascriviAudio.ps1"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "guida aperta" contiene "$LOG" "aperto: $DEST/Guida rapida.pdf"
verifica "nome vuoto rifiutato" contiene "$LOG" "non può essere vuoto"
verifica "nome duplicato rifiutato" contiene "$LOG" "Esiste già un progetto chiamato «intervista rossi»"
verifica "sempre un solo progetto" [ "$(json "len(d['progetti'])" "$PROGETTI/elenco-progetti.json")" = 1 ]
verifica "file temporaneo cancellato" non_esiste "$PROGETTI/progetto-in-corso.json"

# ---------------------------------------------------------------------------------------------
# 4. Aggiornamento: nuovo ZIP estratto altrove, doppio clic su «Installa Trascrivi Audio»
mkdir -p "$USERPROFILE/Downloads/nuova" && (cd "$USERPROFILE/Downloads/nuova" && unzip -q "$ZIP")
risposte "ANNULLA"
esegui "4. Aggiornamento" "$USERPROFILE/Downloads/nuova/Trascrivi Audio/programma/TrascriviAudio.ps1" -Installa
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "avviso «Aggiornamento completato»" eval 'log_giro "4. Agg" | grep -q "Aggiornamento completato"'
verifica "nessuna reinstallazione di Whisper" non_contiene "$PROVA/ultimo.log" "Installo Whisper"
verifica "progetti conservati" [ -d "$P1" ]

# ---------------------------------------------------------------------------------------------
# 5. Disinstalla dal menu, conservando i progetti
risposte "Disinstalla Trascrivi Audio" "Conserva i progetti"
esegui "5. Disinstalla (conserva i progetti)" "$DEST/TrascriviAudio.ps1"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "programma tolto" non_esiste "$DEST"
verifica "icone tolte da Scrivania e menu Start" eval 'non_esiste "$TRASCRIVI_SCRIVANIA/Trascrivi Audio.lnk" && non_esiste "$TRASCRIVI_START/Trascrivi Audio.lnk"'
verifica "voce tolta da «App installate»" non_esiste "$TRASCRIVI_REGISTRO"
verifica "Python, Whisper, modelli e dati del programma tolti" non_esiste "$SUPPORTO"
verifica "progetti conservati" [ -f "$P1/000_IntervistaRossi_audio.mp3" ]
verifica "avviso di disinstallazione" eval 'log_giro "5. Dis" | grep -q "è stato disinstallato"'

# ---------------------------------------------------------------------------------------------
# 6. Reinstallazione (ritrova i progetti), poi disinstalla da «App installate» cancellando tutto
risposte "Apri un progetto" "ANNULLA" "ANNULLA"
esegui "6a. Reinstallazione" "$ESTRATTA/programma/TrascriviAudio.ps1" -Installa
verifica "progetti ritrovati dopo la reinstallazione" eval 'log_giro "6a. Rein" | grep -q "Scegli il progetto da aprire: | Intervista Rossi"'
risposte "Cancella anche i progetti" "Cancella tutto"
esegui "6b. Disinstalla da App installate (cancella tutto)" "$DEST/TrascriviAudio.ps1" -Disinstalla
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "programma tolto" non_esiste "$DEST"
verifica "progetti cancellati" non_esiste "$TRASCRIVI_DOCUMENTI/Trascrivi Audio"
verifica "dati del programma tolti" non_esiste "$SUPPORTO"

# ---------------------------------------------------------------------------------------------
# 7. Documenti sincronizzata con OneDrive: i progetti vanno in una cartella che OneDrive non sincronizza
prepara_utente "$PROVA/Anna"
export OneDrive="$USERPROFILE/OneDrive" TRASCRIVI_DOCUMENTI="$USERPROFILE/OneDrive/Documenti"
mkdir -p "$TRASCRIVI_DOCUMENTI"
risposte "ANNULLA"
esegui "7. Documenti in OneDrive" "$ESTRATTA/programma/TrascriviAudio.ps1" -Installa
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "progetti fuori da OneDrive (cartella dell'utente)" [ -d "$USERPROFILE/Trascrivi Audio/Progetti" ]
verifica "niente nella cartella sincronizzata" non_esiste "$TRASCRIVI_DOCUMENTI/Trascrivi Audio"
verifica "avviso che spiega OneDrive" eval 'log_giro "7. Doc" | grep -q "sincronizzata con OneDrive"'
unset OneDrive

# ---------------------------------------------------------------------------------------------
# 8. Download di Python corrotto: installazione interrotta con un messaggio
prepara_utente "$PROVA/Luca"
risposte "ANNULLA"
PYTHON_PORTATILE_SHA256=0000 esegui "8. Python scaricato corrotto" "$ESTRATTA/programma/TrascriviAudio.ps1" -Installa
verifica "messaggio «non è integro»" contiene "$LOG" "non è integro"
verifica "nessun Python installato" non_esiste "$SUPPORTO/python/bin/python3"

echo; echo "======== Finestre mostrate ========"; cat "$LOG"
echo
if [ "$FALLITE" = 0 ]; then echo "TUTTE LE VERIFICHE SUPERATE"; else echo "VERIFICHE FALLITE: $FALLITE"; fi
echo "(file di prova in $PROVA)"
[ "$FALLITE" = 0 ]
